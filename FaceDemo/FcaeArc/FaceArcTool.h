//
//  FaceArcTool.h
//  FaceDemo
//
//  Created by PC on 2020/12/22.
//  Copyright © 2020 芮淼一线. All rights reserved.
//

/**
 人脸识别：使用原生AVFoundation检测人脸，OpenCV2的RGB灰度处理进行活体检测
 导入框架：
        OpenCV2：CoreMedia, CoreVideo, AssetsLibrary,
        CIDetector：CoreImage
        其它：GLKit ,AVFoundation
 PS:本代码使用OpenCV版本3.4.0
 
 警告⚠️：只能做到人脸识别，清晰度检测，并不能做到活体检测(有些图片可以被检测出来)
*/

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN




@interface FaceArcTool : NSObject
@property (nonatomic,retain) CIDetector*faceDetector;//脸部识别器
@property (nonatomic,strong) NSDictionary *features;//添加检测笑脸，闭眼属性
@property (nonatomic,strong) CIContext *featuresContext;//脸部识别器上下文

+ (instancetype)shared;

/**
 解析人脸数据，并转换成UIImage
 */
- (nullable UIImage *)filterFaceDataWithPixelBuffer:(CMSampleBufferRef)sampleBuffer;

/**
 CMSampleBufferRef -> UIImage
 PS:性能不是太好
 */
- (UIImage*)imageFromPixelBuffer:(CMSampleBufferRef)p;

@end

NS_ASSUME_NONNULL_END
