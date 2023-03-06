//
//  PixelBufferQueue.m
//  MediaPlayer
//
//  Created by shimo-imac on 2023/3/2.
//

#import "PixelBufferQueue.h"

@interface PixelBufferQueue()

@property(nonatomic, assign) int backQueueSize;
@property(nonatomic, assign) int frontQueueSize;

@property(nonatomic, assign) int pixelBufferWidth;
@property(nonatomic, assign) int pixelBufferHeight;

@property(nonatomic, strong) NSMutableArray* backQueue;
@property(nonatomic, strong) NSMutableArray* frontQueue;

@end

@implementation PixelBufferQueue

-(instancetype)initWithWidthAndHeight:(int)pixelBufferWidth pixelBufferHeight:(int)pixelBufferHeight{
    if(self == [super init]){
        _backQueueSize  = 0;
        _frontQueueSize = 0;
        
        _pixelBufferWidth  = pixelBufferWidth;
        _pixelBufferHeight = pixelBufferHeight;
        
        _backQueue   = [[NSMutableArray alloc] init];
        _frontQueue  = [[NSMutableArray alloc] init];
    }
    return self;
}

/// @brief 插队尾
-(int)insertQueueHead:(CVImageBufferRef)pixelBuffer isFront:(BOOL)isFront{
    if(isFront){
        if(pixelBuffer && _frontQueue){
            [_frontQueue addObject:(__bridge id _Nonnull)(pixelBuffer)];
            _frontQueueSize++;
            return 1;
        }else{
            NSLog(@"[%s:%d] pixelBuffer is nil !", __FUNCTION__, __LINE__);
        }
    }else{
        if(pixelBuffer && _backQueue){
            [_backQueue addObject:(__bridge id _Nonnull)(pixelBuffer)];
            _backQueueSize++;
            return 1;
        }else{
            NSLog(@"[%s:%d] _backQueue is nil !", __FUNCTION__, __LINE__);
        }
    }
    return 0;
}

/// @brief 出队首
-(CVImageBufferRef)popQueueTail:(BOOL)isFront{
    CVImageBufferRef ret = nil;
    if(isFront){
        if(_frontQueueSize > 0){
            ret = (__bridge CVImageBufferRef)(_frontQueue[0]);
            if(_frontQueueSize > 1){
                [_frontQueue removeObjectAtIndex:0];
                _frontQueueSize--;
            }
            return ret;
        }else{
            NSLog(@"[%s:%d] _frontQueue is nil !", __FUNCTION__, __LINE__);
        }
    }else{
        if(_backQueueSize > 0){
            ret = (__bridge CVImageBufferRef)(_backQueue[0]);
            if(_backQueueSize > 1){
                [_backQueue removeObjectAtIndex:0];
                _backQueueSize--;
            }
            return ret;
        }else{
            NSLog(@"[%s:%d] _backQueue is nil !", __FUNCTION__, __LINE__);
        }
    }
    return nil;
}

/// @brief 获得指定队列长度
-(int)getQueueLength:(BOOL)isFront{
    if(isFront){
        return _frontQueueSize;
    }else{
        return _backQueueSize;
    }
}

/// @brief 重新设置像素宽高，重新初始化
-(void)setPixelBufferWidthAndHeight:(int)pixelBufferWidth pixelBufferHeight:(int)pixelBufferHeight{
    _backQueueSize  = 0;
    _frontQueueSize = 0;
    
    _pixelBufferWidth  = pixelBufferWidth;
    _pixelBufferHeight = pixelBufferHeight;
    
    if(_backQueue){
        [_backQueue removeAllObjects];
    }else{
        _backQueue   = [[NSMutableArray alloc] init];
    }
    if(_frontQueue){
        [_frontQueue removeAllObjects];
    }else{
        _frontQueue  = [[NSMutableArray alloc] init];
    }
}

@end
