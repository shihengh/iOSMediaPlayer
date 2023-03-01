//
//  CameraRender.m
//  MediaPlayer
//
//  Created by shimo-imac on 2023/2/28.
//

#import "CameraRender.h"
#import "GLDefines.h"

#import "GPUImageView.h"
#import "GPUImageFilter.h"
#import "GPUImageContext.h"
#import "GPUImageColorConversion.h"

static const GLfloat IntegrationSquareVertices[] = {
    -1.0f,  -1.0f,
     1.0f,  -1.0f,
    -1.0f,   1.0f,
     1.0f,   1.0f,
};

@interface CameraRender (){
    
    @protected
    GPUImageFilter *_beautyInFilter;
}

@property (nonatomic, assign) int imageBufferWidth;                           /// 上屏width
@property (nonatomic, assign) int imageBufferHeight;                          /// 上屏height
@property (nonatomic, assign) GLuint luminanceTexture;                        /// 亮度纹理
@property (nonatomic, assign) GLuint chrominanceTexture;                      /// 颜色纹理
@property (nonatomic, assign) GLint yuvConversionPositionAttribute;           /// 定点坐标
@property (nonatomic, assign) GLint yuvConversionTextureCoordinateAttribute;  /// 纹理坐标
@property (nonatomic, assign) GLint yuvConversionLuminanceTextureUniform;     /// 亮度纹理texture
@property (nonatomic, assign) GLint yuvConversionChrominanceTextureUniform;   /// 颜色纹理texture
@property (nonatomic, assign) GLint yuvConversionMatrixUniform;               /// 颜色转换矩阵

@property (nonatomic, strong) GLProgram *offscreenYuv2RgbConversionProgram;   /// 着色器程序
@property (nonatomic, strong) GPUImageFramebuffer *rgbOffscreenBuffer;        /// 离屏渲染FBO
@property (nonatomic, assign) GPUTextureOptions outputTextureOptions;         /// 创建纹理参数

@property (nonatomic) dispatch_semaphore_t frameRenderingSemaphore;           /// 信号量
@end

@implementation CameraRender

- (instancetype)init{
    if(self == [super init]){
        /// 初始化chain head
        _beautyInFilter = [[GPUImageFilter alloc] init];
        
        /// 本地预览图层
        _previewView = [[GPUImageView alloc] initWithFrame: [UIScreen mainScreen].bounds];
        [_previewView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        
        /// 初始化创建texture options
        _outputTextureOptions.minFilter = GL_LINEAR;
        _outputTextureOptions.magFilter = GL_LINEAR;
        _outputTextureOptions.wrapS = GL_CLAMP_TO_EDGE;
        _outputTextureOptions.wrapT = GL_CLAMP_TO_EDGE;
        _outputTextureOptions.internalFormat = GL_RGBA;
        _outputTextureOptions.format = GL_BGRA;
        _outputTextureOptions.type = GL_UNSIGNED_BYTE;
        
        /// 信号量 几个变量可以访问
        self.frameRenderingSemaphore = dispatch_semaphore_create(1);
        
        /// 将输出加到_beautyInFilter
        [self setupWithMetaData:nil];
        
        NSLog(@"construct=[%@][%p]", NSStringFromClass([self class]), self);
    }
    return self;
}

-(void)setupWithMetaData:(NSDictionary*)params{
    /// 将视频渲染结果放入preview
    [_beautyInFilter addTarget:self.previewView];
}

#pragma mark - CameraRenderDelegate Delegate
- (void)willOutputSampleBuffer:(CMSampleBufferRef _Nullable)sampleBuffer {
    if(!CMSampleBufferIsValid(sampleBuffer))
        return;
    
    /// 原理：调用dispatch_semaphore_wait之后信号量-1，信号量大于等于0继续执行，否则锁住临界区；
    if (dispatch_semaphore_wait(_frameRenderingSemaphore, DISPATCH_TIME_NOW) != 0){
        Loggerinfo(@"render cost too long, maybe more than 1/fps, drop this frame");
        return;
    }
    
    CFRetain(sampleBuffer);
    runAsynchronouslyOnVideoProcessingQueue(^{
        //尽量异步到后台线程，避免阻塞摄像头回调线程
        CVImageBufferRef pixelBuffer  = CMSampleBufferGetImageBuffer(sampleBuffer);
        CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        int pixelWidth  = (int)CVPixelBufferGetWidth(pixelBuffer);
        int pixelHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
        
        if(self.imageBufferWidth != pixelWidth || self.imageBufferHeight != pixelHeight){
            Loggerinfo(@"pixel size changed!");
            self.imageBufferWidth  = pixelWidth;
            self.imageBufferHeight = pixelHeight;
            self.rgbOffscreenBuffer = nil;
        }
        
        [self switch2DyGLContext];
        
        /// 提前将YUV转换成RGB纹理
        GLuint rgbTextureId = [self converYUV2RGBTextureID:pixelBuffer pixelWidth:pixelWidth pixelHeight:pixelHeight];
        
        [self renderWithoutEffects:currentTime];
        
        CFRelease(sampleBuffer);
        
        /// 是进行加1操作。如果dispatch_semaphore_wait减1前如果小于1，则一直等待。
        dispatch_semaphore_signal(self->_frameRenderingSemaphore);
    });
}

/// 直接上屏
- (void)renderWithoutEffects:(CMTime)currentTime{
    id<GPUImageInput> currentTarget = self.previewView;
    [currentTarget setInputRotation:kGPUImageNoRotation atIndex:0];
    [currentTarget setInputSize:CGSizeMake(self.imageBufferWidth, self.imageBufferHeight) atIndex:0];
    [currentTarget setInputFramebuffer:self.rgbOffscreenBuffer atIndex:0];
    [currentTarget newFrameReadyAtTime:currentTime atIndex:0];
}

-(GLuint)converYUV2RGBTextureID:(CVPixelBufferRef)cameraFrame
                   pixelWidth:(int)bufferWidth
                  pixelHeight:(int)bufferHeight{
    BOOL yuvFullRange = YES;
    const GLfloat *preferredConversion = NULL;
    
    /// @remark 获取颜色转换矩阵转换点
    CFTypeRef colorAttachments = CVBufferCopyAttachment(cameraFrame, kCVImageBufferYCbCrMatrixKey, NULL);
    if (colorAttachments != NULL){
        if(CFStringCompare(colorAttachments, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo){
            if (yuvFullRange){
                preferredConversion = kColorConversion601FullRange;
            }else{
                preferredConversion = kColorConversion601;
            }
        }else{
            preferredConversion = kColorConversion709;
        }
    }else{
        if (yuvFullRange){
            preferredConversion = kColorConversion601FullRange;
        }else{
            preferredConversion = kColorConversion601;
        }
    }
    
    [self loadYuv2RgbShaderIfNeed];
    
    [self uploadYUVData2TexutreId:cameraFrame pixelWidth:bufferWidth pixelHeight:bufferHeight];
    
    return [self offScreenRender2TextureId:self.luminanceTexture chrominanceTexture:self.chrominanceTexture preferredConversion:preferredConversion];
}

- (GLuint)offScreenRender2TextureId:(GLuint)luminanceTexture
               chrominanceTexture:(GLuint)chrominanceTexture
                preferredConversion:(const GLfloat *)preferredConversion{
    [GPUImageContext setActiveShaderProgram:_offscreenYuv2RgbConversionProgram];
    glEnableVertexAttribArray(_yuvConversionPositionAttribute);
    glEnableVertexAttribArray(_yuvConversionTextureCoordinateAttribute);
    
    int rotatedImageBufferWidth = self.imageBufferWidth, rotatedImageBufferHeight = self.imageBufferHeight;

    /// 创建空的 FBO
    if (_rgbOffscreenBuffer == nil) {
        _rgbOffscreenBuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(rotatedImageBufferWidth, rotatedImageBufferHeight) textureOptions:self.outputTextureOptions onlyTexture:NO];
        [_rgbOffscreenBuffer lock];
    }
    
    [_rgbOffscreenBuffer activateFramebuffer];
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, luminanceTexture);
    glUniform1i(_yuvConversionLuminanceTextureUniform, 0);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
    glUniform1i(_yuvConversionChrominanceTextureUniform, 1);

    glUniformMatrix3fv(_yuvConversionMatrixUniform, 1, GL_FALSE, preferredConversion);

    glVertexAttribPointer(_yuvConversionPositionAttribute, 2, GL_FLOAT, 0, 0, IntegrationSquareVertices);
    glVertexAttribPointer(_yuvConversionTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, [GPUImageFilter textureCoordinatesForRotation:kGPUImageNoRotation]);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glFlush();//立即清空OpenGL指令，避免_rgbOffscreenBuffer的textureId落后pixelbuffer
    
    return self.rgbOffscreenBuffer.texture;
}

- (void)loadYuv2RgbShaderIfNeed{
    if(_offscreenYuv2RgbConversionProgram == nil){
//        /// fullRange
//        {
//            _offscreenYuv2RgbConversionProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImageYUVFullRangeConversionForLAFragmentShaderString];
//        }
        /// videoRange
        {
            _offscreenYuv2RgbConversionProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString
                                                                                                         fragmentShaderString:kGPUImageYUVVideoRangeConversionForLAFragmentShaderString];
        }
        if(!_offscreenYuv2RgbConversionProgram.initialized){
            [_offscreenYuv2RgbConversionProgram addAttribute:@"position"];
            [_offscreenYuv2RgbConversionProgram addAttribute:@"inputTextureCoordinate"];
            if(![_offscreenYuv2RgbConversionProgram link]){
                NSString *progLog = [_offscreenYuv2RgbConversionProgram programLog];
                NSString *fragLog = [_offscreenYuv2RgbConversionProgram fragmentShaderLog];
                NSString *vertLog = [_offscreenYuv2RgbConversionProgram vertexShaderLog];
                NSLog(@"Program link log=[%@] \n"
                      "Fragment shader compile log=[%@] \n"
                      "Vertex shader compile log=[%@]   \n", progLog, fragLog, vertLog);
                _offscreenYuv2RgbConversionProgram = nil;
                NSAssert(NO, @"Filter shader link failed");
            }
        }
        _yuvConversionPositionAttribute = [_offscreenYuv2RgbConversionProgram attributeIndex:@"position"];
        _yuvConversionTextureCoordinateAttribute = [_offscreenYuv2RgbConversionProgram attributeIndex:@"inputTextureCoordinate"];
        _yuvConversionLuminanceTextureUniform = [_offscreenYuv2RgbConversionProgram uniformIndex:@"luminanceTexture"];
        _yuvConversionChrominanceTextureUniform = [_offscreenYuv2RgbConversionProgram uniformIndex:@"chrominanceTexture"];
        _yuvConversionMatrixUniform = [_offscreenYuv2RgbConversionProgram uniformIndex:@"colorConversionMatrix"];
    }
}

- (void)uploadYUVData2TexutreId:(CVPixelBufferRef)cameraFrame pixelWidth:(int)bufferWidth pixelHeight:(int)bufferHeight{
    if([GPUImageContext supportsFastTextureUpload]){
        CVOpenGLESTextureRef luminanceTextureRef = NULL;
        CVOpenGLESTextureRef chrominanceTextureRef = NULL;
        
        if(CVPixelBufferGetPlaneCount(cameraFrame) > 0){
            CVPixelBufferLockBaseAddress(cameraFrame, 0);
            
            // Y plane
            CVReturn err;
            glActiveTexture(GL_TEXTURE0);
            err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                               [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache],
                                                               cameraFrame,
                                                               NULL,
                                                               GL_TEXTURE_2D,
                                                               GL_LUMINANCE,
                                                               bufferWidth,
                                                               bufferHeight,
                                                               GL_LUMINANCE,
                                                               GL_UNSIGNED_BYTE,
                                                               0,
                                                               &luminanceTextureRef);
            if(err){
                Loggerinfo(@"luminanceTextureRef create failed!");
            }
            self.luminanceTexture = CVOpenGLESTextureGetName(luminanceTextureRef);
            glBindBuffer(GL_TEXTURE_2D, self.luminanceTexture);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            
            // UV-plane
            glActiveTexture(GL_TEXTURE1);
            err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                               [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache],
                                                               cameraFrame,
                                                               NULL,
                                                               GL_TEXTURE_2D,
                                                               GL_LUMINANCE_ALPHA,
                                                               bufferWidth/2,
                                                               bufferHeight/2,
                                                               GL_LUMINANCE_ALPHA,
                                                               GL_UNSIGNED_BYTE,
                                                               1,
                                                               &chrominanceTextureRef);
            if(err){
                Loggerinfo(@"luminanceTextureRef create failed!");
            }
            self.chrominanceTexture = CVOpenGLESTextureGetName(chrominanceTextureRef);
            glBindTexture(GL_TEXTURE_2D, self.chrominanceTexture);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            
            CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
            CFRelease(luminanceTextureRef);
            CFRelease(chrominanceTextureRef);
        }
    }
}


/// @brief 切换到斗鱼上下文
- (void)switch2DyGLContext{
    EAGLContext *preContext = [EAGLContext currentContext];
    EAGLContext *dyContext = [GPUImageContext sharedImageProcessingContext].context;
    if (preContext != dyContext){
        [EAGLContext setCurrentContext:dyContext];
    }
}

@end
