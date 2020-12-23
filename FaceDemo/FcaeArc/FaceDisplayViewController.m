//
//  FaceDisplayViewController.m
//  FaceDemo
//
//  Created by PC on 2020/12/22.
//  Copyright © 2020 芮淼一线. All rights reserved.
//

#import "FaceDisplayViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <GLKit/GLKit.h>
#import "FaceArcTool.h"


NSString *kFaceDisplayCameraAuthTips  = @"请允许访问照相机";
NSString *kFaceDisplayDeviceErrorTips = @"前置摄像头不可用";
NSString *kFaceDisplayInputErrorTips  = @"无法获取视频设备输入";

@interface FaceDisplayViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate>
@property (nonatomic,strong) AVCaptureSession *session;
@property (nonatomic,strong) dispatch_queue_t sample;
@property (nonatomic,strong) dispatch_queue_t faceQueue;
@property (nonatomic,copy  ) NSArray *currentMetadata; //?< 如果检测到了人脸系统会返回一个数组 我们将这个数组存起来

@property (nonatomic, strong) GLKView *previewView;
@property (nonatomic, strong) CIContext *ciContext;
@property (nonatomic, strong) EAGLContext *eaglContext;
@property (nonatomic, assign) CGRect previewViewBounds;

@property (nonatomic, assign) BOOL isFace;

@end

@implementation FaceDisplayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setupGLKView];
    [self initCamera];
}

#pragma mark 初始化相机，并打开
- (void)initCamera
{
    _sample = dispatch_queue_create("sample", NULL);
    _faceQueue = dispatch_queue_create("face", NULL);
    _currentMetadata = @[].mutableCopy;
    

    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        //获取摄像头
        AVCaptureDevicePosition position = AVCaptureDevicePositionFront;
        NSArray *devices = nil;
        if (@available(iOS 10.0, *)) {
            AVCaptureDeviceDiscoverySession *devicesIOS10 = [AVCaptureDeviceDiscoverySession  discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:position];
            devices = devicesIOS10.devices;
        } else {
            // Fallback on earlier versions
            devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        }

    #pragma clang diagnostic pop
        AVCaptureDevice *deviceF;
        for (AVCaptureDevice *device in devices )
        {
            if ( device.position == position )
            {
                deviceF = device;
                break;
            }
        }
        if (!deviceF) {
//            TKLog(@"前置摄像头不可用");
            [self blockErrorAction:kFaceDisplayDeviceErrorTips];
            return;
        }

        // 如果改变曝光设置，可以将其返回到默认配置
        if ([deviceF isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            NSError *error = nil;
            if ([deviceF lockForConfiguration:&error]) {
                CGPoint exposurePoint = CGPointMake(0.5f, 0.5f);
                [deviceF setExposurePointOfInterest:exposurePoint];
                [deviceF setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            }
        }
        if ([deviceF isFocusModeSupported:AVCaptureFocusModeLocked]) {
            NSError *error = nil;
            if ([deviceF lockForConfiguration:&error]) {
                deviceF.focusMode = AVCaptureFocusModeLocked;
                [deviceF unlockForConfiguration];
            }
            else {
            }
        }

        //输入设备
        AVCaptureDeviceInput*input = [[AVCaptureDeviceInput alloc] initWithDevice:deviceF error:nil];
        if (!input) {
            //无法获取视频设备输入
            [self blockErrorAction:kFaceDisplayInputErrorTips];
            return;
        }
        //输出
        AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
        [output setSampleBufferDelegate:self queue:_sample];
        output.alwaysDiscardsLateVideoFrames = YES;//


        AVCaptureMetadataOutput *metaout = [[AVCaptureMetadataOutput alloc] init];
        [metaout setMetadataObjectsDelegate:self queue:_faceQueue];
        self.session = [[AVCaptureSession alloc] init];
        [self.session beginConfiguration];
        if ([self.session canAddInput:input]) {
            [self.session addInput:input];
        }

        if ([self.session canSetSessionPreset:AVCaptureSessionPreset640x480]) {
            [self.session setSessionPreset:AVCaptureSessionPreset640x480];
        }
        if ([self.session canAddOutput:output]) {
            [self.session addOutput:output];
        }
        if ([self.session canAddOutput:metaout]) {
            [self.session addOutput:metaout];
        }
        [self.session commitConfiguration];

        NSString     *key           = (NSString *)kCVPixelBufferPixelFormatTypeKey;
        NSNumber     *value         = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
        NSDictionary *videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
        [output setVideoSettings:videoSettings];
        //这里 我们告诉要检测到人脸 就给我一些反应，里面还有QRCode 等 都可以放进去，就是 如果视频流检测到了你要的 就会出发下面第二个代理方法
        [metaout setMetadataObjectTypes:@[AVMetadataObjectTypeFace]];

        AVCaptureSession* session = (AVCaptureSession *)self.session;
        //前置摄像头一定要设置一下 要不然画面是镜像
        for (AVCaptureVideoDataOutput* output in session.outputs) {
            for (AVCaptureConnection * av in output.connections) {
                //判断是否是前置摄像头状态
                if (av.supportsVideoMirroring) {
                    //镜像设置
                    av.videoOrientation = AVCaptureVideoOrientationPortrait;
                    av.videoMirrored = YES;
                }
            }
        }
        [self startRunning];
}

//开始检测
- (void)startRunning
{
    _isFace = NO;
    [self.session startRunning];
}

//停止检测
- (void)stopRunning
{
    [self.session stopRunning];
}

- (void)blockErrorAction:(NSString *)msg
{
    NSLog(@"Face:%@",msg);
}


#pragma mark 图形渲染显示
- (void)setupGLKView
{
    CGRect bounds = [UIScreen mainScreen].bounds;
    bounds = self.view.bounds;
    _eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    _previewView = [[GLKView alloc] initWithFrame:bounds context:_eaglContext];
    _previewView.enableSetNeedsDisplay = NO;
    _previewView.frame = bounds;
//    _videoPreviewView.transform = CGAffineTransformMakeRotation(-M_PI_2);
    [self.view addSubview:_previewView];
    [_previewView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];

    [_previewView bindDrawable];
    _previewViewBounds = CGRectZero;
    _previewViewBounds.size.width = _previewView.drawableWidth;
    _previewViewBounds.size.height = _previewView.drawableHeight;

    _ciContext = [CIContext contextWithEAGLContext:_eaglContext options:@{kCIContextWorkingColorSpace : [NSNull null]} ];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];

#pragma mark 注意这儿，_videoPreviewViewBounds需要的时实际的像素点，而不是编程点
    CGFloat scale = [UIScreen mainScreen].scale;
    CGRect bounds = self.view.bounds;
    bounds.size = CGSizeMake(bounds.size.width*scale, bounds.size.height*scale);
    _previewViewBounds = bounds;
}

#pragma mark 将图像渲染到GLKView上--适用于全屏，或者后期修改一下
- (void)displayGLKViewWith:(CIImage *)sourceImage
{
    CGRect sourceExtent = sourceImage.extent;
    CGFloat sourceAspect = sourceExtent.size.width / sourceExtent.size.height;
    CGFloat previewAspect = _previewViewBounds.size.width  / _previewViewBounds.size.height;

    // we want to maintain the aspect radio of the screen size, so we clip the video image
    CGRect drawRect = sourceExtent;
    if (sourceAspect > previewAspect)
    {
        // use full height of the video image, and center crop the width
        drawRect.origin.x += (drawRect.size.width - drawRect.size.height * previewAspect) / 2.0;
        drawRect.size.width = drawRect.size.height * previewAspect;
    }
    else
    {
        // use full width of the video image, and center crop the height
        drawRect.origin.y += (drawRect.size.height - drawRect.size.width / previewAspect) / 2.0;
        drawRect.size.height = drawRect.size.width / previewAspect;
    }

    [_previewView bindDrawable];
    if (_eaglContext != [EAGLContext currentContext]){
        [EAGLContext setCurrentContext:_eaglContext];
    }

    // clear eagl view to grey
    glClearColor(0.5, 0.5, 0.5, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);

    // set the blend mode to "source over" so that CI will use that
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

    if (sourceImage){
        [_ciContext drawImage:sourceImage inRect:_previewViewBounds fromRect:drawRect];
    }
    [_previewView display];
}


#pragma mark delegate
//检查到人脸
- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    _currentMetadata = metadataObjects;
}

//捕获到视频帧
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CIImage *sourceImage = [CIImage imageWithCVPixelBuffer:(CVPixelBufferRef)imageBuffer options:nil];
    [self displayGLKViewWith:sourceImage];

    
    if (_alwaysShow) {
        if (!_isFace) {
            UIImage *image = [[FaceArcTool shared] filterFaceDataWithPixelBuffer:sampleBuffer];
            if (image) {
                _isFace = YES;
                if ([self.delegate respondsToSelector:@selector(faceDisplayViewController:output:)]) {
                    [self.delegate faceDisplayViewController:self output:image];
                }
            }
        }
    }else{
        UIImage *image = [[FaceArcTool shared] filterFaceDataWithPixelBuffer:sampleBuffer];
        if (image) {
            [self stopRunning];
            if ([self.delegate respondsToSelector:@selector(faceDisplayViewController:output:)]) {
                [self.delegate faceDisplayViewController:self output:image];
            }
        }
    }

}



/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
