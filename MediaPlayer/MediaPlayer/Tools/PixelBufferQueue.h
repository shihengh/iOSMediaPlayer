//
//  PixelBufferQueue.h
//  MediaPlayer
//
//  Created by shimo-imac on 2023/3/2.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PixelBufferQueue : NSObject

/// @brief 初始化队列
-(instancetype)initWithWidthAndHeight:(int)pixelBufferWidth pixelBufferHeight:(int)pixelBufferHeight;

/// @brief 插入队列
-(int)insertQueueHead:(CVImageBufferRef)pixelBuffer isFront:(BOOL)isFront;

/// @brief 出队列
-(CVImageBufferRef)popQueueTail:(BOOL)isFront;

/// @brief 获得指定队列长度
-(int)getQueueLength:(BOOL)isFront;

/// @brief 重新设置像素宽高，重新初始化
-(void)setPixelBufferWidthAndHeight:(int)pixelBufferWidth pixelBufferHeight:(int)pixelBufferHeight;

@end

NS_ASSUME_NONNULL_END
