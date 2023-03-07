//
//  BaseViewController.h
//  MediaPlayer
//
//  Created by shimo-imac on 2023/1/19.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "GLDefines.h"
#import "CameraSource.h"
#import "MultiCameraSource.h"
#import "Render.h"

NS_ASSUME_NONNULL_BEGIN

@interface BaseViewController : UIViewController

@property (nonatomic, strong) id<Render> __nullable render;                 /// 视频帧处理

@property (nonatomic, strong) CameraSource* _Nullable  source;              /// 视频数据源
@property (nonatomic, strong) MultiCameraSource* _Nullable  multiSource;    /// 多摄像机视频数据源
@end

NS_ASSUME_NONNULL_END
