//
//  opencvstabvideo.hpp
//  stabvideo
//
//  Created by Dinh Le on 1/18/19.
//  Copyright © 2019 Dinh Le. All rights reserved.
//

#ifndef opencvstabvideo_hpp
#define opencvstabvideo_hpp

#include <stdio.h>
#include <iostream>
#include <opencv2/opencv.hpp>
using namespace std;
using namespace cv;
class opencvstabvideo {
public:
    vector<Mat> stablelize(vector<Mat> videoArray);
};

#endif /* opencvstabvideo_hpp */
