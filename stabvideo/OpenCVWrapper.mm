//
//  OpenCVWrapper.m
//  stabvideo
//
//  Created by Dinh Le on 1/17/19.
//  Copyright © 2019 Dinh Le. All rights reserved.
//

#import "OpenCVWrapper.h"
#import <opencv2/opencv.hpp>
#import <Photos/Photos.h>
#import <AssetsLibrary/AssetsLibrary.h>
using namespace std;
#import "opencvstabvideo.hpp"

@implementation OpenCVWrapper
-(UIImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNoneSkipLast|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}
- (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image size:(CGSize)size
{
    
    int height = size.height;
    int width = size.width;
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    CVPixelBufferRef pxbuffer = NULL;
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, width,
                                          height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = CGBitmapContextCreate(pxdata, width,
                                                 height, 8, 4*width, rgbColorSpace,
                                                 kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}
-(void)writeImageAsMovie:(NSArray *)array toPath:(NSString*)path size:(CGSize)size withFPS:(CGFloat) fps
{
    
    NSError *error = nil;
    
    // FIRST, start up an AVAssetWriter instance to write your video
    // Give it a destination path (for us: tmp/temp.mov)
    AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:path]
                                                           fileType:AVFileTypeQuickTimeMovie
                                                              error:&error];
    
    
    NSParameterAssert(videoWriter);
    
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecTypeH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:size.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:size.height], AVVideoHeightKey,
                                   nil];
    
    AVAssetWriterInput* writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                         outputSettings:videoSettings];
    
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput
                                                                                                                     sourcePixelBufferAttributes:nil];
    NSParameterAssert(writerInput);
    NSParameterAssert([videoWriter canAddInput:writerInput]);
    [videoWriter addInput:writerInput];
    //Start a SESSION of writing.
    // After you start a session, you will keep adding image frames
    // until you are complete - then you will tell it you are done.
    [videoWriter startWriting];
    // This starts your video at time = 0
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    CVPixelBufferRef buffer = NULL;
    
    // This was just our utility class to get screen sizes etc.
//    ATHSingleton *singleton = [ATHSingleton singletons];
    
    int i = 0;
    while (true)
    {
        // Check if the writer is ready for more data, if not, just wait
        if(writerInput.readyForMoreMediaData){
            
            CMTime frameTime = CMTimeMake(150, 600);
            // CMTime = Value and Timescale.
            // Timescale = the number of tics per second you want
            // Value is the number of tics
            // For us - each frame we add will be 1/4th of a second
            // Apple recommend 600 tics per second for video because it is a
            // multiple of the standard video rates 24, 30, 60 fps etc.
            CMTime lastTime=CMTimeMake(i*150, 600);
            CMTime presentTime=CMTimeAdd(lastTime, frameTime);
            
            if (i == 0) {presentTime = CMTimeMake(0, 600);}
            // This ensures the first frame starts at 0.
            
            
            if (i >= [array count])
            {
                buffer = NULL;
            }
            else
            {
                // This command grabs the next UIImage and converts it to a CGImage
                buffer = [self pixelBufferFromCGImage:[[array objectAtIndex:i] CGImage] size:size];
            }
            
            
            if (buffer)
            {
                // Give the CGImage to the AVAssetWriter to add to your video
                [adaptor appendPixelBuffer:buffer withPresentationTime:presentTime];
                i++;
            }
            else
            {//Finish the session:
                // This is important to be done exactly in this order
                [writerInput markAsFinished];
                // WARNING: finishWriting in the solution above is deprecated.
                // You now need to give a completion handler.
                [videoWriter finishWritingWithCompletionHandler:^{
                    NSLog(@"Finished writing...checking completion status...");
                    if (videoWriter.status != AVAssetWriterStatusFailed && videoWriter.status == AVAssetWriterStatusCompleted)
                    {
                        NSLog(@"Video writing succeeded.");
                        
                        // Move video to camera roll
                        // NOTE: You cannot write directly to the camera roll.
                        // You must first write to an iOS directory then move it!
                        NSURL *videoTempURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@", path]];
//                        [self saveToCameraRoll:videoTempURL];
                        
                    } else
                    {
                        NSLog(@"Video writing failed: %@", videoWriter.error);
                    }
                    
                }]; // end videoWriter finishWriting Block
                
                CVPixelBufferPoolRelease(adaptor.pixelBufferPool);
                
                NSLog (@"Done");
                break;
            }
        }
    }
}
- (cv::Mat)cvMatFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}

- (void) stabilizationVideo:(PHAsset *) sourceVideo{
//    opencvstabvideo *ovstabvideo = new opencvstabvideo;
//    string url = ovstabvideo->stablelize([sourceVideoUrlString UTF8String]);
//    NSString * result = [[NSString alloc] initWithUTF8String:url.c_str()];
    PHVideoRequestOptions *option = [PHVideoRequestOptions new];
    [[PHImageManager defaultManager] requestAVAssetForVideo:sourceVideo options:option resultHandler:^(AVAsset * avasset, AVAudioMix * audioMix, NSDictionary * info) {
        //avasset
        AVAssetTrack * videoATrack = [[avasset tracksWithMediaType:AVMediaTypeVideo] lastObject];
        Float64 fps = 0.0f;
        if(videoATrack)
        {
            fps = videoATrack.nominalFrameRate;
        }
        Float64 durationSeconds = CMTimeGetSeconds(avasset.duration);
        Float64 timePerFrame = 1.0 / fps;
        Float64 totalFrames = durationSeconds * fps;
        AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:avasset];
        //Step through the frames
        vector<cv::Mat> videoMatArray = *new vector<cv::Mat>();
        for (int counter = 0; counter <= totalFrames; counter++){
            CMTime actualTime;
            Float64 secondsIn = counter*timePerFrame;
            CMTime imageTimeEstimate = CMTimeMakeWithSeconds(secondsIn, 600);
            NSError *error;
            CGImageRef imageframe = [imageGenerator copyCGImageAtTime:imageTimeEstimate actualTime:&actualTime error:&error];
            UIImage *image = [UIImage imageWithCGImage:imageframe];
            //...Do some processing on the image
            cv::Mat cvMat = [self cvMatFromUIImage:image];
            videoMatArray.push_back(cvMat);
            CGImageRelease(imageframe);
        }
        opencvstabvideo *ovstabvideo = new opencvstabvideo;
        vector<cv::Mat> outputArray = ovstabvideo->stablelize(videoMatArray);
        NSMutableArray *imageOutputArray = [[NSMutableArray alloc] init];
        for (int i = 0; i < outputArray.size(); i++){
            cv::Mat mat = outputArray.at(i);
            UIImage *matImage = [self UIImageFromCVMat:mat];
            [imageOutputArray addObject:matImage];
        }
    }];
}
@end
