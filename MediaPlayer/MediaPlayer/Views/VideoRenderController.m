//
//  VideoRenderController.m
//  MediaPlayer
//
//  Created by shimo-imac on 2023/1/19.
//

#import "VideoRenderController.h"

@interface VideoRenderController ()

@property (nonatomic, strong) UIButton *videoSizeChangeBtn;
@property (nonatomic, readonly) NSMutableArray* preSize;   /// 清晰度预览大小

@end

@implementation VideoRenderController

-(instancetype)init{
    if(self == [super init]){
        /// 预览清晰度size
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

    [self.view addSubview:self.videoSizeChangeBtn];     ///  分辨率
}

/// @remark 设置分辨率按钮
-(UIButton*)videoSizeChangeBtn{
    if(!_videoSizeChangeBtn){
        _videoSizeChangeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_videoSizeChangeBtn setTitle:@"1280*720" forState:UIControlStateNormal];
        [_videoSizeChangeBtn setFrame:CGRectMake(40, 260, 100, 40)];
        [_videoSizeChangeBtn addTarget:self action:@selector(videoSizeChange) forControlEvents:UIControlEventTouchUpInside];
    }
    return _videoSizeChangeBtn;
}

/// @remark 设置分辨率按钮 aciton
-(void)videoSizeChange{
    static NSInteger index = 1;
    [self.source changeCameraVideoSize:CGSizeMake([_preSize[index][0] floatValue], [_preSize[index][1] floatValue])];
    [_videoSizeChangeBtn setTitle: _preSize[index][2] forState:UIControlStateNormal];
    index = (index + 1) % 4;
    NSLog(@"[%s:%d] %@", __FUNCTION__, __LINE__, _preSize[index][2]);
}
@end
