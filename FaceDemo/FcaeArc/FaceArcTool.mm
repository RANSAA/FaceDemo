//
//  FaceArcTool.m
//  FaceDemo
//
//  Created by PC on 2020/12/22.
//  Copyright © 2020 芮淼一线. All rights reserved.
//

//导入OpenCV头文件，必须放在最前面。
//放在pch文件中最好
#ifdef __cplusplus 
#import <opencv2/opencv.hpp>
#import <opencv2/imgproc/types_c.h>
#import <opencv2/imgproc/imgproc_c.h>
#import <opencv2/imgcodecs/ios.h>
#endif

#import "FaceArcTool.h"



@implementation FaceArcTool

+ (instancetype)shared
{
    static dispatch_once_t onceToken;
    static FaceArcTool *obj = nil;
    dispatch_once(&onceToken, ^{
        obj = [FaceArcTool new];
        [obj initDetector];
    });
    return obj;
}

- (void)initDetector
{
    //CIDetectorAccuracyLow：识别精度低，但识别速度快、性能高
    //CIDetectorAccuracyHigh：识别精度高、但识别速度比较慢
    NSDictionary *detectorOptions = @{CIDetectorAccuracy:CIDetectorAccuracyHigh};
    self.faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
    self.features = @{CIDetectorEyeBlink:@(YES),
                      CIDetectorTracking:@(YES)
                      };//检测闭眼属性
    self.featuresContext = [CIContext contextWithOptions:nil];

    NSLog(@"featuresContext INFO:%@",self.featuresContext);
}

/**
 解析人脸数据，并转换成UIImage
 */
- (nullable UIImage *)filterFaceDataWithPixelBuffer:(CMSampleBufferRef)sampleBuffer
{
    //CIImage -> CGImageRef -> UIImage
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);  //拿到缓冲区帧数据
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:imageBuffer];            //创建CIImage对象
    //识别脸部 -> UIImage
    CIDetector *detector = self.faceDetector;
    NSArray *faceArray = [detector featuresInImage:ciImage options:self.features];
    //图片中只能有一个人脸
    if (faceArray.count != 1) {
        return nil;
    }
        
    #define _ScreenHeight  UIScreen.mainScreen.bounds.size.height
    //筛选符合条件的数据，具体项目具体修改!!
    for (CIFaceFeature * faceFeature in faceArray){
        if (faceFeature.hasLeftEyePosition    && faceFeature.hasRightEyePosition  && faceFeature.hasMouthPosition && faceFeature.bounds.size.width>120 && faceFeature.mouthPosition.y>147  && fabsf(faceFeature.faceAngle)< 4.0 && faceFeature.leftEyePosition.x>80 && faceFeature.rightEyePosition.x < 400 && faceFeature.leftEyePosition.y < _ScreenHeight*0.7 && faceFeature.leftEyeClosed == NO && faceFeature.rightEyeClosed == NO){
            //提取面部uiimage
            CGImageRef cgImageRef = [self.featuresContext createCGImage:ciImage fromRect:faceFeature.bounds];
            UIImage *faceImage = [UIImage imageWithCGImage:cgImageRef];

//            NSLog(@"faceAngle = %f",faceFeature.faceAngle);
//            NSLog(@"hasFaceAngle = %d",faceFeature.hasFaceAngle);
//            NSLog(@"trackingFrameCount = %d",faceFeature.trackingFrameCount);
//            NSLog(@"leftEyeClosed = %d  rightEyeClosed= %d",faceFeature.leftEyeClosed,faceFeature.rightEyeClosed);
//            NSLog(@"eye left:%f right:%f",faceFeature.leftEyePosition.x,faceFeature.rightEyePosition.x);
//            NSLog(@"hasTrackingID = %d",faceFeature.hasTrackingID);
//            NSLog(@"trackingID = %d",faceFeature.trackingID);
//            NSLog(@"eye y:%f",faceFeature.leftEyePosition.y);

            //面部检测
            if ([self definitionDetectionWith:faceImage]) {
                //整张图片
                NSLog(@"检测成功。。");
                UIImage *resultImage = [self imageFromPixelBuffer:sampleBuffer];
                return resultImage;
            }else{
                NSLog(@"不是活体");
            }
        }
    }
    return nil;
}



#pragma mark OpenVC2处理区域

/**
 CMSampleBufferRef -> UIImage
 PS:性能不是太好
 */
- (UIImage*)imageFromPixelBuffer:(CMSampleBufferRef)p
{
    CVImageBufferRef buffer;
    buffer = CMSampleBufferGetImageBuffer(p);

    CVPixelBufferLockBaseAddress(buffer, 0);
    uint8_t *base;
    size_t width, height, bytesPerRow;
    base = (uint8_t *)CVPixelBufferGetBaseAddress(buffer);
    width = CVPixelBufferGetWidth(buffer);
    height = CVPixelBufferGetHeight(buffer);
    bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);

    CGColorSpaceRef colorSpace;
    CGContextRef cgContext;
    colorSpace = CGColorSpaceCreateDeviceRGB();
    cgContext = CGBitmapContextCreate(base, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);

    CGImageRef cgImage;
    UIImage *image;
    cgImage = CGBitmapContextCreateImage(cgContext);
    image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGContextRelease(cgContext);

    CVPixelBufferUnlockBaseAddress(buffer, 0);

    return image;
}


/**
 清晰度度检测，不能做到真正的活体检测
 */
- (BOOL)definitionDetectionWith:(UIImage *)image
{
    cv::Mat mat;
    //将UIImage转化成cv::Mat
    UIImageToMat(image, mat);
    return [self rgbGrayLevelDetectionWith:mat];
}

/**
 RGB灰度处理，清晰度验证方法
 */
- (BOOL)rgbGrayLevelDetectionWith:(cv::Mat)mat
{
    unsigned char *data;
    int height,width,step;
    int Iij;
    double Iave = 0, Idelta = 0;
    if(!mat.empty()){
       cv::Mat gray;
       cv::Mat outGray;
       // 将图像转换为灰度显示
       cv::cvtColor(mat,gray,CV_RGB2GRAY);
       cv::Laplacian(gray, outGray, gray.depth());
       //
//       cv::convertScaleAbs( outGray, outGray );

       //3.4.0构造方法
       IplImage ipl_image(outGray);
       
       // >=3.4.4构造方法
//        IplImage ipl_image = cvIplImage(outGray);

        
       data   = (uchar*)ipl_image.imageData;
       height = ipl_image.height;
       width  = ipl_image.width;
       step   = ipl_image.widthStep;
       for(int i=0;i<height;i++)
       {
           for(int j=0;j<width;j++)
           {
               Iij    = (int) data
               [i*width+j];
               Idelta    = Idelta + (Iij-Iave)*(Iij-Iave);
           }
       }
       Idelta = Idelta/(width*height);
       std::cout<<"矩阵方差为："<<Idelta<<std::endl;
    }
    return (Idelta > 15) ? YES : NO;//15 17 区间
}



@end
