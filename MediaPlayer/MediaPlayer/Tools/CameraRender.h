//
//  CameraRender.h
//  MediaPlayer
//
//  Created by shimo-imac on 2023/2/28.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "CameraSource.h"
#import "Render.h"

@class GPUImageView;

NS_ASSUME_NONNULL_BEGIN

/// 渲染实体类
@interface CameraRender : RenderImp

/// @remark 提供子类使用方法
- (void)switch2DyGLContext;

-(GLuint)converYUV2RGBTextureID:(CVPixelBufferRef)cameraFrame
                   pixelWidth:(int)bufferWidth
                    pixelHeight:(int)bufferHeight;
@end

NS_ASSUME_NONNULL_END
