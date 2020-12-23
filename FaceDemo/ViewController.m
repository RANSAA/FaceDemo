//
//  ViewController.m
//  FaceDemo
//
//  Created by PC on 2020/12/22.
//  Copyright © 2020 芮淼一线. All rights reserved.
//

#import "ViewController.h"
#import "FaceDisplayViewController.h"


@interface ViewController ()<FaceDisplayDelegate>
@property (strong, nonatomic) IBOutlet UIView *displayView;
@property (strong, nonatomic) IBOutlet UIImageView *preImageView;
@property (strong, nonatomic) IBOutlet UIButton *btnAction;
@property (strong, nonatomic) FaceDisplayViewController *faceVC;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.faceVC = [[FaceDisplayViewController alloc] init];
        self.faceVC.delegate = self;
//        self.faceVC.alwaysShow = YES;
        [self addChildViewController:self.faceVC];
        [self.displayView addSubview:self.faceVC.view];
        [self.faceVC.view mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.displayView);
        }];
//    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"bouds:%@",NSStringFromCGRect(self.faceVC.view.bounds));

    });

}


- (IBAction)btnAction:(id)sender {
    NSLog(@"开始识别。。。");
    [self.faceVC startRunning];
}

- (void)faceDisplayViewController:(FaceDisplayViewController *)controller output:(UIImage *)image
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.preImageView.image = image;
        NSLog(@"IMG...");
        NSLog(@"image:%@",image);
    });
}

@end
