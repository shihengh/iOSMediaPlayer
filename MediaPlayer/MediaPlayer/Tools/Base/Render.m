//
//  Render.m
//  MediaPlayer
//
//  Created by shimo-imac on 2023/3/6.
//

#import <Foundation/Foundation.h>
#import "Render.h"

@interface RenderImp () {
    
}

@end

@implementation RenderImp

@synthesize outputTextureOptions;
@synthesize previewView;

- (instancetype)init
{
    self = [super init];
    if (self) {
        /// 初始化创建texture options
        outputTextureOptions.minFilter = GL_LINEAR;
        outputTextureOptions.magFilter = GL_LINEAR;
        outputTextureOptions.wrapS = GL_CLAMP_TO_EDGE;
        outputTextureOptions.wrapT = GL_CLAMP_TO_EDGE;
        outputTextureOptions.internalFormat = GL_RGBA;
        outputTextureOptions.format = GL_BGRA;
        outputTextureOptions.type = GL_UNSIGNED_BYTE;
        
        /// 本地预览层
        previewView = [[GPUImageView alloc] initWithFrame: [UIScreen mainScreen].bounds];
        [previewView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        
        NSLog(@"construct=[%@][%p]", NSStringFromClass([self class]), self);
    }
    return self;
}

@end
