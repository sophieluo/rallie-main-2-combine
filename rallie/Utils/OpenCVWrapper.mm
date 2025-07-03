//
//  OpenCVWrapper.mm
//  rallie
//
//  Created by Xiexiao_Luo on 3/29/25.
//

#import "OpenCVWrapper.h"

#ifdef __OBJC__
#undef NO
#endif

#ifdef __cplusplus
#import <opencv2/opencv.hpp>
#endif

using namespace cv;

@implementation OpenCVWrapper

+ (nullable NSArray<NSNumber *> *)computeHomographyFrom:(NSArray<NSValue *> *)imagePoints
                                                     to:(NSArray<NSValue *> *)courtPoints {
    if (imagePoints.count != 8 || courtPoints.count != 8) return nil;

    std::vector<cv::Point2f> src, dst;
    for (int i = 0; i < 8; i++) {
        CGPoint sp = [imagePoints[i] CGPointValue];
        CGPoint dp = [courtPoints[i] CGPointValue];
        
        // Use raw image points (no normalization needed)
        src.push_back(cv::Point2f(sp.x, sp.y));
        
        // Court points in meters
        dst.push_back(cv::Point2f(dp.x, dp.y));
    }

    cv::Mat H = cv::findHomography(src, dst, cv::RANSAC);
    if (H.empty()) return nil;

    NSMutableArray<NSNumber *> *result = [NSMutableArray arrayWithCapacity:9];
    for (int i = 0; i < 3; ++i) {
        for (int j = 0; j < 3; ++j) {
            double value = H.at<double>(i, j);
            [result addObject:@(value)];
        }
    }

    return result;
}


+ (nullable NSValue *)projectPoint:(CGPoint)point usingMatrix:(NSArray<NSNumber *> *)matrix {
    if (matrix.count != 9) return nil;

    Mat H(3, 3, CV_64F);  // Changed to double precision
    for (int i = 0; i < 9; ++i) {
        double value = [matrix[i] doubleValue];
        H.at<double>(i / 3, i % 3) = value;
    }

    std::vector<Point2f> input = { Point2f(point.x, point.y) };
    std::vector<Point2f> output;

    perspectiveTransform(input, output, H);
    if (output.empty()) return nil;

    return [NSValue valueWithCGPoint:CGPointMake(output[0].x, output[0].y)];
}

@end
