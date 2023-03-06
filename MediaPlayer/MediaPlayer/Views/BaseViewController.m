//
//  BaseViewController.m
//  MediaPlayer
//
//  Created by shimo-imac on 2023/1/19.
//

#import <UIKit/UIKit.h>
#import "BaseViewController.h"

#import "Render.h"
#import "CameraRender.h"
#import "MultiCameraRender.h"

@interface BaseViewController ()

@property(nonatomic, strong) GPUImageView* previewView;          /// 预览视图

@end

@implementation BaseViewController

- (instancetype)init{
    if(self == [super init]){
        NSLog(@"construct=[%@][%p]", NSStringFromClass([self class]), self);
    }
    return self;
}

/// @remark 设置当前渲染的视图view
- (void)setRender:(id<Render>)render{
    if(render){
        _render = render;
    }else{
        Loggerinfo(@"Render Set Failed!");
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    /// 时序问题 首先把视图view加进去
    if(_render){
        [self.view addSubview:_render.previewView];
    }
}

@end
