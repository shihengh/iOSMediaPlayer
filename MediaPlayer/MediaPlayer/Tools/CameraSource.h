//
//  CameraSource.h
//  MediaPlayer
//
//  Created by shimo-imac on 2023/1/20.
//

#if 1

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "GPUImageView.h"

#import "BaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface CameraSource : NSObject

@property (nonatomic, strong) GPUImageView* previewView;

-(instancetype)init;

/// @brief 开启摄像头
-(void)startCaptureVideo;

/// @brief 关闭摄像头
-(void)stopCaptureVideo;

/// @brief 切换摄像头方向
-(void)changeCapturePosition:(AVCaptureDevicePosition)position;

/// @brief 设置摄像头拍摄角度
-(void)setupVideoCaptureOrientation;

@end

NS_ASSUME_NONNULL_END
#endif
