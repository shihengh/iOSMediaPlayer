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

NS_ASSUME_NONNULL_BEGIN

/// 渲染代理
@protocol CameraRenderDelegate <NSObject>

- (void)willOutputSampleBuffer:(CMSampleBufferRef _Nullable )sampleBuffer;

@end

/// 相机管理类
@interface CameraSource : NSObject

@property (nonatomic, strong, nullable) id<CameraRenderDelegate> delegate; /// 渲染代理类

-(instancetype)init;

/// @brief 开启摄像头
-(void)startCaptureVideo;

/// @brief 关闭摄像头
-(void)stopCaptureVideo;

/// @brief 切换摄像头方向
-(void)changeCapturePosition:(AVCaptureDevicePosition)position;

/// @brief 设置摄像头拍摄角度
//-(void)setupVideoCaptureOrientation;

/// @brief 预览设置摄像头像素
-(void)changeCameraVideoSize:(CGSize)cameraSize;

@end

NS_ASSUME_NONNULL_END
#endif
