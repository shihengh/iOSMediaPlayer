//
//  VideoRenderController.m
//  MediaPlayer
//
//  Created by shimo-imac on 2023/1/19.
//

#import "VideoRenderController.h"
#import "CameraSource.h"
#import "MultiCameraSource.h"
#import "GLDefines.h"

@interface VideoRenderController ()

@property(nonatomic, strong) CameraSource* source;
@property(nonatomic, strong) MultiCameraSource* multiSource;

@property (nonatomic, strong) UISwitch *captureSwitch;
@property (nonatomic, strong) UISwitch *positionSwitch;
@property (nonatomic, strong) UIButton *videoSizeChangeBtn;

@property (nonatomic, readonly) NSMutableArray* preSize;
@end

@implementation VideoRenderController

-(instancetype)init{
    if(self == [super init]){
        _source = [[CameraSource  alloc] init];
//        _multiSource = [[MultiCameraSource alloc] init];
        
        _preSize = [NSMutableArray arrayWithObjects:
                    @[@1280, @720, @"1280*720"],
                    @[@960,  @540, @"960*540"],
                    @[@360,  @640, @"360*640"],
                    @[@320,  @240, @"320*240"],
                    nil];
    }
    return self;
}

- (void)dealloc{
    NSLog(@"[%s:%d]", __FUNCTION__, __LINE__);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    [self.view addSubview:_source.previewView];
    
    UIButton* button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:@"sadad" forState:UIControlStateNormal];
    [button setFrame:CGRectMake(40, 260, 100, 40)];
    
    [self.view addSubview:self.captureSwitch];      ///  相机开启开关
    [self.view addSubview:self.positionSwitch];     ///  前置/后置开关
    [self.view addSubview:self.videoSizeChangeBtn];                   ///  分辨率
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

/// @remark 前后置摄像头切换 action
- (void)positionSwitchChanged:(UISwitch *)positionSwitch{
    if(positionSwitch.on){
        [_source changeCapturePosition:AVCaptureDevicePositionFront];
    }else{
        [_source changeCapturePosition:AVCaptureDevicePositionBack];
    }
    UILabel *beautyLabel = [self.view viewWithTag:101];
    beautyLabel.text = positionSwitch.on ? @"后置":@"前置";
}

-(UIButton*)videoSizeChangeBtn{
    if(!_videoSizeChangeBtn){
        _videoSizeChangeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_videoSizeChangeBtn setTitle:@"1280*720" forState:UIControlStateNormal];
        [_videoSizeChangeBtn setFrame:CGRectMake(40, 260, 100, 40)];
        [_videoSizeChangeBtn addTarget:self action:@selector(videoSizeChange) forControlEvents:UIControlEventTouchUpInside];
    }
    return _videoSizeChangeBtn;
}

-(void)videoSizeChange{
    static NSInteger index = 1;
    [_source changeCameraVideoSize:CGSizeMake([_preSize[index][0] floatValue], [_preSize[index][1] floatValue])];
    [_videoSizeChangeBtn setTitle: _preSize[index][2] forState:UIControlStateNormal];
    index = (index + 1) % 4;
    NSLog(@"[%s:%d] %@", __FUNCTION__, __LINE__, _preSize[index][2]);
}
@end
