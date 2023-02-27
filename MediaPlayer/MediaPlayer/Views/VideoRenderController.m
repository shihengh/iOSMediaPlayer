//
//  VideoRenderController.m
//  MediaPlayer
//
//  Created by shimo-imac on 2023/1/19.
//

#import "VideoRenderController.h"
#import "CameraSource.h"
#import "MultiCameraSource.h"

@interface VideoRenderController ()

@property(nonatomic, strong) CameraSource* source;

@property(nonatomic, strong) MultiCameraSource* multiSource;

@property (nonatomic, strong) UISwitch *captureSwitch;
@property (nonatomic, strong) UISwitch *positionSwitch;

@end

@implementation VideoRenderController


-(instancetype)init{
    if(self == [super init]){
        _source = [[CameraSource  alloc] init];
//        _multiSource = [[MultiCameraSource alloc] init];
        
        /// 相机摆放位置通知
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(deviceOrientationDidChangeForController)
//                                                     name:UIDeviceOrientationDidChangeNotification
//                                                   object:nil];
    }
    return self;
}

//- (void)statusBarWillChange{
//    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
//    NSLog(@"[%s:%d] orientation=[%d]", __FUNCTION__, __LINE__, (int)orientation);
//
//}

- (void)dealloc{
    NSLog(@"[%s:%d]", __FUNCTION__, __LINE__);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    [self.view addSubview:_source.previewView];
    
    [self.view addSubview:self.captureSwitch];
    [self.view addSubview:self.positionSwitch];
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

- (void)captureSwitchChanged:(UISwitch *)switchControl{
    if(switchControl.on){
        [_source startCaptureVideo];
    }else{
        [_source stopCaptureVideo];
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

- (void)positionSwitchChanged:(UISwitch *)positionSwitch{
    if(positionSwitch.on){
        [_source changeCapturePosition:AVCaptureDevicePositionFront];
    }else{
        [_source changeCapturePosition:AVCaptureDevicePositionBack];
    }
    UILabel *beautyLabel = [self.view viewWithTag:101];
    beautyLabel.text = positionSwitch.on ? @"后置":@"前置";
}
@end
