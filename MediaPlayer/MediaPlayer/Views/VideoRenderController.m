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

@property (nonatomic, strong) UISwitch *beautySwitch;

@end

@implementation VideoRenderController

-(instancetype)init{
    if(self == [super init]){
        _source = [[CameraSource  alloc] init];
//        _multiSource = [[MultiCameraSource alloc] init];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self.view addSubview:_source.previewView];
    
    [self.view addSubview:self.beautySwitch];
}

- (void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];
}

-(void)playButtonPressed:(UIButton*)button{
    if([[button currentTitle] compare:@"play"] == NSOrderedSame){
        [_source startCaptureVideo];
        [button setTitle:@"stop" forState:UIControlStateNormal];
    }else {
        [_source stopCaptureVideo];
        [button setTitle:@"start" forState:UIControlStateNormal];
    }
}

- (UISwitch *)beautySwitch{
    if (!_beautySwitch) {
        _beautySwitch = [[UISwitch alloc] initWithFrame:CGRectMake(40, 100, 100, 40)];
        _beautySwitch.on = NO;
        [_beautySwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        
        UILabel *beautyLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, CGRectGetHeight(_beautySwitch.bounds) + 100, CGRectGetWidth(_beautySwitch.bounds), 40)];
        beautyLabel.text = @"开";
        beautyLabel.textAlignment = NSTextAlignmentCenter;
        beautyLabel.textColor = [UIColor redColor];
        beautyLabel.tag = 100;
        [self.view addSubview:beautyLabel];
    }
    return _beautySwitch;
}

- (void)switchChanged:(UISwitch *)switchControl{
    if(switchControl.on){
        [_source startCaptureVideo];
    }else{
        [_source stopCaptureVideo];
    }
    UILabel *beautyLabel = [self.view viewWithTag:100];
    beautyLabel.text = switchControl.on ? @"开":@"关";
}
@end
