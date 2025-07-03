//
//  OpenCVWrapper.h
//  rallie
//
//  Created by Xiexiao_Luo on 3/29/25.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenCVWrapper : NSObject

+ (nullable NSArray<NSNumber *> *)computeHomographyFrom:(NSArray<NSValue *> *)imagePoints
                                                           to:(NSArray<NSValue *> *)courtPoints;

+ (nullable NSValue *)projectPoint:(CGPoint)point usingMatrix:(NSArray<NSNumber *> *)matrix;

@end

NS_ASSUME_NONNULL_END

