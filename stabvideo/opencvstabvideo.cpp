//
//  opencvstabvideo.cpp
//  stabvideo
//
//  Created by Dinh Le on 1/18/19.
//  Copyright © 2019 Dinh Le. All rights reserved.
//

#include "opencvstabvideo.hpp"
#include <cassert>
#include <fstream>
#include <cmath>


// This video stablisation smooths the global trajectory using a sliding average window

const int SMOOTHING_RADIUS = 30; // In frames. The larger the more stable the video, but less reactive to sudden panning
const int BORDER_CROP = 64; // In pixels. Crops the border to reduce the black borders from stabilisation being too noticeable.

// 1. Get previous to current frame transformation (dx, dy, da) for all frames
// 2. Accumulate the transformations to get the image trajectory
// 3. Smooth out the trajectory using an averaging window
// 4. Generate new set of previous to current transform, such that the trajectory ends up being the same as the smoothed trajectory
// 5. Apply the new transformation to the video

struct TransformParam
{
    TransformParam() {}
    TransformParam(double _dx, double _dy, double _da) {
        dx = _dx;
        dy = _dy;
        da = _da;
    }
    
    double dx;
    double dy;
    double da; // angle
};

struct Trajectory
{
    Trajectory() {}
    Trajectory(double _x, double _y, double _a) {
        x = _x;
        y = _y;
        a = _a;
    }
    
    double x;
    double y;
    double a; // angle
};

vector<Mat> opencvstabvideo::stablelize(vector<Mat> videoArray)
{
    // For further analysis
//    ofstream out_transform("prev_to_cur_transformation.txt");
//    ofstream out_trajectory("trajectory.txt");
//    ofstream out_smoothed_trajectory("smoothed_trajectory.txt");
//    ofstream out_new_transform("new_prev_to_cur_transformation.txt");
    
//    VideoCapture cap(fileUrl);
//    assert(cap.isOpened());
    
    Mat cur, cur_grey;
    Mat prev, prev_grey;
    prev = videoArray.at(0);
//    videoArray >> prev;
    cvtColor(prev, prev_grey, COLOR_BGR2GRAY);
    
    // Step 1 - Get previous to current frame transformation (dx, dy, da) for all frames
    vector <TransformParam> prev_to_cur_transform; // previous to current
    
//    int k=1;
    long max_frames = videoArray.size();
    Mat last_T;
    
    for(long i = 0; i < max_frames; i++) {
        cur = videoArray.at(i);
        if(cur.data == NULL) {
            break;
        }
        
        cvtColor(cur, cur_grey, COLOR_BGR2GRAY);
        
        // vector from prev to cur
        vector <Point2f> prev_corner, cur_corner;
        vector <Point2f> prev_corner2, cur_corner2;
        vector <uchar> status;
        vector <float> err;
        
        goodFeaturesToTrack(prev_grey, prev_corner, 200, 0.01, 30);
        calcOpticalFlowPyrLK(prev_grey, cur_grey, prev_corner, cur_corner, status, err);
        
        // weed out bad matches
        for(size_t i=0; i < status.size(); i++) {
            if(status[i]) {
                prev_corner2.push_back(prev_corner[i]);
                cur_corner2.push_back(cur_corner[i]);
            }
        }
        
        // translation + rotation only
//        Mat T = estimateRigidTransform(prev_corner2, cur_corner2, false); // false = rigid transform, no scaling/shearing
        Mat T = estimateAffine2D(prev_corner2, cur_corner2);
        //        Mat T = estimateAffinePartial2D(prev_corner2, cur_corner2);
        // in rare cases no transform is found. We'll just use the last known good transform.
        if(T.data == NULL) {
            last_T.copyTo(T);
        }
        
        T.copyTo(last_T);
        // decompose T
        double dx = T.at<double>(0,2);
        double dy = T.at<double>(1,2);
        double da = atan2(T.at<double>(1,0), T.at<double>(0,0));
        
        prev_to_cur_transform.push_back(TransformParam(dx, dy, da));
        
//        out_transform << k << " " << dx << " " << dy << " " << da << endl;
        
        cur.copyTo(prev);
        cur_grey.copyTo(prev_grey);
        
//        cout << "Frame: " << k << "/" << max_frames << " - good optical flow: " << prev_corner2.size() << endl;
    }
    
    // Step 2 - Accumulate the transformations to get the image trajectory
    
    // Accumulated frame to frame transform
    double a = 0;
    double x = 0;
    double y = 0;
    
    vector <Trajectory> trajectory; // trajectory at all frames
    
    for(size_t i=0; i < prev_to_cur_transform.size(); i++) {
        x += prev_to_cur_transform[i].dx;
        y += prev_to_cur_transform[i].dy;
        a += prev_to_cur_transform[i].da;
        
        trajectory.push_back(Trajectory(x,y,a));
        
//        out_trajectory << (i+1) << " " << x << " " << y << " " << a << endl;
    }
    
    // Step 3 - Smooth out the trajectory using an averaging window
    vector <Trajectory> smoothed_trajectory; // trajectory at all frames
    
    for(size_t i=0; i < trajectory.size(); i++) {
        double sum_x = 0;
        double sum_y = 0;
        double sum_a = 0;
        int count = 0;
        
        for(int j=-SMOOTHING_RADIUS; j <= SMOOTHING_RADIUS; j++) {
            if(i+j >= 0 && i+j < trajectory.size()) {
                sum_x += trajectory[i+j].x;
                sum_y += trajectory[i+j].y;
                sum_a += trajectory[i+j].a;
                
                count++;
            }
        }
        
        double avg_a = sum_a / count;
        double avg_x = sum_x / count;
        double avg_y = sum_y / count;
        
        smoothed_trajectory.push_back(Trajectory(avg_x, avg_y, avg_a));
        
//        out_smoothed_trajectory << (i+1) << " " << avg_x << " " << avg_y << " " << avg_a << endl;
    }
    
    // Step 4 - Generate new set of previous to current transform, such that the trajectory ends up being the same as the smoothed trajectory
    vector <TransformParam> new_prev_to_cur_transform;
    
    // Accumulated frame to frame transform
    a = 0;
    x = 0;
    y = 0;
    
    for(size_t i=0; i < prev_to_cur_transform.size(); i++) {
        x += prev_to_cur_transform[i].dx;
        y += prev_to_cur_transform[i].dy;
        a += prev_to_cur_transform[i].da;
        
        // target - current
        double diff_x = smoothed_trajectory[i].x - x;
        double diff_y = smoothed_trajectory[i].y - y;
        double diff_a = smoothed_trajectory[i].a - a;
        
        double dx = prev_to_cur_transform[i].dx + diff_x;
        double dy = prev_to_cur_transform[i].dy + diff_y;
        double da = prev_to_cur_transform[i].da + diff_a;
        
        new_prev_to_cur_transform.push_back(TransformParam(dx, dy, da));
        
//        out_new_transform << (i+1) << " " << dx << " " << dy << " " << da << endl;
    }
    
    // Step 5 - Apply the new transformation to the video
    Mat T(2,3,CV_64F);
    
    int vert_border = BORDER_CROP * prev.rows / prev.cols; // get the aspect ratio correct
    vector<Mat> outputVideo = *new vector<Mat>();
    for(long i = 0; i < max_frames - 1; i++) { // don't process the very last frame, no valid transform
        cur = videoArray.at(i);
        if(cur.data == NULL) {
            break;
        }
        T.at<double>(0,0) = cos(new_prev_to_cur_transform[i].da);
        T.at<double>(0,1) = -sin(new_prev_to_cur_transform[i].da);
        T.at<double>(1,0) = sin(new_prev_to_cur_transform[i].da);
        T.at<double>(1,1) = cos(new_prev_to_cur_transform[i].da);
        T.at<double>(0,2) = new_prev_to_cur_transform[i].dx;
        T.at<double>(1,2) = new_prev_to_cur_transform[i].dy;
        Mat cur2;
        warpAffine(cur, cur2, T, cur.size());
        cur2 = cur2(Range(vert_border, cur2.rows-vert_border), Range(BORDER_CROP, cur2.cols-BORDER_CROP));
        Mat finalMat;
        cur2.copyTo(finalMat);
        outputVideo.push_back(finalMat);
    }
    return outputVideo;
}
