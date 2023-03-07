//
//  Source.h
//  MediaPlayer
//
//  Created by shimo-imac on 2023/3/6.
//

#import <Foundation/Foundation.h>
#import "Render.h"

NS_ASSUME_NONNULL_BEGIN

@protocol Source<NSObject>

@optional
/// @brief 设置视频源渲染代理
- (void)setDelegate:(id<Render>)delegate;

/// @brief 开启摄像头
-(void)startCaptureVideo;

/// @brief 关闭摄像头
-(void)stopCaptureVideo;

@end

NS_ASSUME_NONNULL_END

