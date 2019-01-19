//
//  OpenCVWrapper.h
//  stabvideo
//
//  Created by Dinh Le on 1/17/19.
//  Copyright © 2019 Dinh Le. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
NS_ASSUME_NONNULL_BEGIN

@interface OpenCVWrapper : NSObject
- (void) stabilizationVideo:(PHAsset *) sourceVideo;
@end

NS_ASSUME_NONNULL_END
