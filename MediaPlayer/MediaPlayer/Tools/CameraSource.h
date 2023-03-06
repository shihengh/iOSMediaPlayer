//
//  CameraSource.h
//  MediaPlayer
//
//  Created by shimo-imac on 2023/1/20.
//

#if 1

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#import "GPUImageView.h"
#import "Source.h"
#import "Render.h"

NS_ASSUME_NONNULL_BEGIN

/// @class 相机管理类
@interface CameraSource : NSObject<Source>

-(instancetype)init;

/// @brief 切换摄像头方向
-(void)changeCapturePosition:(AVCaptureDevicePosition)position;

/// @brief 预览设置摄像头像素
-(void)changeCameraVideoSize:(CGSize)cameraSize;

/// @brief 设置摄像头拍摄角度
//-(void)setupVideoCaptureOrientation;

@end

NS_ASSUME_NONNULL_END
#endif
