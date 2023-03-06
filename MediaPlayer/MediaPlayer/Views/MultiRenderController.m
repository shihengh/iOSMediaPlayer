//
//  MultiRenderControllerViewController.m
//  MediaPlayer
//
//  Created by shimo-imac on 2023/3/3.
//

#import "MultiRenderController.h"
#import "MultiCameraSource.h"
#import "MultiCameraRender.h"

@interface MultiRenderController ()

@end

@implementation MultiRenderController

-(instancetype)init{
    if(self == [super init]){
        
        /// @remark 设置相机视频帧回吐
        self.render = [[MultiCameraRender alloc] init];
        self.multiSource = [[MultiCameraSource alloc] init];
        self.multiSource.delegate = self.render;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}


@end
