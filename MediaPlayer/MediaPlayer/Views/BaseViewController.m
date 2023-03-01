//
//  BaseViewController.m
//  MediaPlayer
//
//  Created by shimo-imac on 2023/1/19.
//

#import <UIKit/UIKit.h>
#import "BaseViewController.h"
#import "CameraRender.h"

@interface BaseViewController ()

@property(nonatomic, strong) GPUImageView* previewView;   /// 预览视图

@property (nonatomic, strong) UISwitch *captureSwitch;    /// 开启相机捕捉
@property (nonatomic, strong) UISwitch *positionSwitch;   /// 切换相机位置

@property (nonatomic, strong) CameraRender* cameraRender; /// 视频帧处理类

@end

@implementation BaseViewController

- (instancetype)init{
    if(self == [super init]){
        /// cameraRender -> cameraSource 包含关系
        
        /// cameraRender
        _cameraRender = [[CameraRender alloc] init];
        
        /// cameraSource
        _source = [[CameraSource alloc] init];
        _source.delegate = _cameraRender;
        
        NSLog(@"construct=[%@][%p]", NSStringFromClass([self class]), self);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    ///@remark Do any additional setup after loading the view.
    [self.view addSubview:self.cameraRender.previewView]; /// 添加视图
    
    [self.view addSubview:self.captureSwitch];      ///  相机开启开关
    [self.view addSubview:self.positionSwitch];     ///  前置/后置开关
}

///  @remark 开始捕捉视频帧 Switch
- (UISwitch *)captureSwitch{
    if (!_captureSwitch) {
        _captureSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(40, 100, 100, 40)];
        _captureSwitch.on = NO;
        [_captureSwitch addTarget:self action:@selector(captureSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        
        UILabel *beautyLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, CGRectGetHeight(_captureSwitch.bounds) + 100, CGRectGetWidth(_captureSwitch.bounds), 40)];
        beautyLabel.text = @"开";
        beautyLabel.textAlignment = NSTextAlignmentCenter;
        beautyLabel.textColor = [UIColor redColor];
        beautyLabel.tag = 100;
        [self.view addSubview:beautyLabel];
    }
    return _captureSwitch;
}

///  @remark 开始捕捉视频帧 action
- (void)captureSwitchChanged:(UISwitch *)switchControl{
    if(switchControl.on && self.source){
        [self.source startCaptureVideo];
    }else{
        [self.source stopCaptureVideo];
    }
    UILabel *beautyLabel = [self.view viewWithTag:100];
    beautyLabel.text = switchControl.on ? @"开":@"关";
}

///  @remark 前后置摄像头切换
- (UISwitch *)positionSwitch{
    if (!_positionSwitch) {
        _positionSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(40, 180, 100, 40)];
        _positionSwitch.on = NO;
        [_positionSwitch addTarget:self action:@selector(positionSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        
        UILabel *beautyLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, CGRectGetHeight(_positionSwitch.bounds) + 180, CGRectGetWidth(_positionSwitch.bounds), 40)];
        beautyLabel.text = @"前置";
        beautyLabel.textAlignment = NSTextAlignmentCenter;
        beautyLabel.textColor = [UIColor redColor];
        beautyLabel.tag = 101;
        [self.view addSubview:beautyLabel];
    }
    return _positionSwitch;
}

/// @remark 前后置摄像头切换 action
- (void)positionSwitchChanged:(UISwitch *)positionSwitch{
    if(positionSwitch.on && self.source){
        [self.source changeCapturePosition:AVCaptureDevicePositionFront];
    }else{
        [self.source changeCapturePosition:AVCaptureDevicePositionBack];
    }
    UILabel *beautyLabel = [self.view viewWithTag:101];
    beautyLabel.text = positionSwitch.on ? @"后置":@"前置";
}

@end
