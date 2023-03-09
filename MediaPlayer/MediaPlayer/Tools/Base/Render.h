//
//  Render.h
//  MediaPlayer
//
//  Created by shimo-imac on 2023/3/3.
//

#import <Foundation/Foundation.h>
#import "GPUImageView.h"

NS_ASSUME_NONNULL_BEGIN

/*---------------------------------RenderDelegate---------------------------------------*/

@protocol RenderDelegate <NSObject>

@optional

- (void)willOutputSampleBuffer:(CMSampleBufferRef _Nullable )sampleBuffer;

- (void)willOutputSampleBuffer:(CMSampleBufferRef _Nullable )sampleBuffer isFront:(BOOL)isFront;

@end

/*-------------------------------------Render------------------------------------------*/

@protocol Render<NSObject>

@optional

@property (nonatomic, strong, readonly) GPUImageView* previewView;             /// 预览视图

@property (nonatomic, assign) GPUTextureOptions outputTextureOptions;          /// 创建纹理参数

@property (nonatomic, strong) GPUImageFramebuffer *rgbOffscreenBuffer;         /// 离屏渲染FBO

@end

/*------------------------------------RenderImp------------------------------------------*/

/// @brief 初始化渲染类
@interface RenderImp : NSObject<Render, RenderDelegate>

@end

NS_ASSUME_NONNULL_END
