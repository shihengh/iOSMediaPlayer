//
//  CameraRender.h
//  MediaPlayer
//
//  Created by shimo-imac on 2023/2/28.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "CameraSource.h"

@class GPUImageView;

NS_ASSUME_NONNULL_BEGIN

/// 渲染实体类
@interface CameraRender : NSObject<CameraRenderDelegate>

@property (nonatomic, strong, readonly) GPUImageView* previewView;                      /// 预览视图

@end

NS_ASSUME_NONNULL_END
