//
//  FaceDisplayViewController.h
//  FaceDemo
//
//  Created by PC on 2020/12/22.
//  Copyright © 2020 芮淼一线. All rights reserved.
//
/**
 照相机拍摄页面
 */
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class FaceDisplayViewController;
@protocol FaceDisplayDelegate <NSObject>
@optional
/** 检测成功输出*/
- (void)faceDisplayViewController:(FaceDisplayViewController *)controller output:(UIImage *)image;
@end


@interface FaceDisplayViewController : UIViewController
@property(nonatomic, assign) BOOL alwaysShow;//是否一直显示拍摄画面
@property(nonatomic , weak) id<FaceDisplayDelegate> delegate;

//开始检测
- (void)startRunning;
//停止检测
- (void)stopRunning;

@end

NS_ASSUME_NONNULL_END
