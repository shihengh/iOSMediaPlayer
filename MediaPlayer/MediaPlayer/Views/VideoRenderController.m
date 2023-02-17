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

@property(nonatomic, strong) UIButton* play;
@property(nonatomic, strong) CameraSource* source;
@property(nonatomic, strong) MultiCameraSource* multiSource;

@end

@implementation VideoRenderController

-(instancetype)init{
    if(self == [super init]){
        _source = [[CameraSource  alloc] initWithDelegate: true renderView:self];
//        _multiSource = [[MultiCameraSource alloc] init];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self.view addSubview:self.play];
    
//    [_source startCaptureVideo];
}

- (void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];
}

- (UIButton *)play{
    if(!_play){
        _play = [[UIButton alloc] initWithFrame:CGRectMake(
                                                           (self.view.bounds.size.width - 100) / 2.0 ,
                                                           (self.view.bounds.size.height - 50) / 2.0,
                                                           100, 50)];
        [_play addTarget:self action:@selector(playButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_play setTitle:@"play" forState:UIControlStateNormal];
    }
    return _play;
}

-(void)playButtonPressed:(UIButton*)button{
    if([[button currentTitle] compare:@"play"] == NSOrderedSame){
//        [_source startCaptureVideo];
    }else {
        
    }
}

@end
