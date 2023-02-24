//
//  CameraSource.m
//  MediaPlayer
//
//  Created by shimo-imac on 2023/1/20.
//

#import "CameraSource.h"
#import "VideoRenderController.h"
#import "BaseViewController.h"

#import "GLDefines.h"

#import "GPUImageView.h"
#import "GPUImageFilter.h"
#import "GPUImageContext.h"
#import "GPUImageColorConversion.h"

#import <AVFoundation/AVFoundation.h>

static const GLfloat IntegrationSquareVertices[] = {
    -1.0f, -1.0f,
    1.0f, -1.0f,
    -1.0f,  1.0f,
    1.0f,  1.0f,
};

@interface CameraSource() <AVCaptureVideoDataOutputSampleBufferDelegate>{
    dispatch_queue_t _cameraProcessingQueue, _sessionQueue;
    AVCaptureDeviceInput     *_videoInput;
    AVCaptureVideoDataOutput *_videoOutput;
    
    @protected
    GPUImageFilter *_beautyInFilter;
}

@property(strong, nonatomic) AVCaptureSession* session;
@property(strong, nonatomic) BaseViewController* renderView;

@property (nonatomic, assign) BOOL captureFullRange;
@property (readwrite, nonatomic, copy) NSString *captureSessionPreset;     ///  清晰度
@property (nonatomic, readwrite) AVCaptureDevicePosition cameraPosition;   ///  摄像头
@property (nonatomic, readwrite) CGSize cameraVideoSize;                   ///  清晰度矩阵

@property (nonatomic, weak) AVCaptureDevice *frontCamera;
@property (nonatomic, weak) AVCaptureDevice *backCamera;
@property (nonatomic, assign) NSUInteger frameNumber;                      /// 帧的数目 3帧内抛弃

@property (nonatomic, assign) int imageBufferWidth;
@property (nonatomic, assign) int imageBufferHeight;
@property (nonatomic, assign) GLuint luminanceTexture;
@property (nonatomic, assign) GLuint chrominanceTexture;
@property (nonatomic, assign) GLint yuvConversionPositionAttribute;
@property (nonatomic, assign) GLint yuvConversionTextureCoordinateAttribute;
@property (nonatomic, assign) GLint yuvConversionLuminanceTextureUniform;
@property (nonatomic, assign) GLint yuvConversionChrominanceTextureUniform;
@property (nonatomic, assign) GLint yuvConversionMatrixUniform;

@property (nonatomic, strong) GLProgram *offscreenYuv2RgbConversionProgram;  /// 着色器程序
@property (nonatomic, strong) GPUImageFramebuffer *rgbOffscreenBuffer;       /// 离屏渲染FBO
@property (nonatomic, assign) GPUTextureOptions outputTextureOptions;        /// 创建纹理参数

@property (nonatomic) dispatch_semaphore_t frameRenderingSemaphore;

@end

@implementation CameraSource

-(instancetype)initWithDelegate:(BOOL)isFront renderView:(BaseViewController*)renderView{
    if(self == [super init]){
        
        /// 串型队列
        _sessionQueue = dispatch_queue_create("_sessionQueue", DISPATCH_QUEUE_SERIAL);
        
        /// 初始化chain head
        _beautyInFilter = [[GPUImageFilter alloc] init];
        _previewView = [[GPUImageView alloc] initWithFrame: [UIScreen mainScreen].bounds];
        // camera position are front
        [_previewView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        
        /// 信号量 几个变量可以访问
        self.frameRenderingSemaphore = dispatch_semaphore_create(1);
        
        /// 初始化创建texture options
        _outputTextureOptions.minFilter = GL_LINEAR;
        _outputTextureOptions.magFilter = GL_LINEAR;
        _outputTextureOptions.wrapS = GL_CLAMP_TO_EDGE;
        _outputTextureOptions.wrapT = GL_CLAMP_TO_EDGE;
        _outputTextureOptions.internalFormat = GL_RGBA;
        _outputTextureOptions.format = GL_BGRA;
        _outputTextureOptions.type = GL_UNSIGNED_BYTE;
        
        /// @remark 开始相机捕捉
        self.renderView = renderView;
        self.cameraPosition  = AVCaptureDevicePositionBack;
        self.cameraVideoSize = CGSizeMake(1280, 720);
        
        /// 初始化设备采集
        [self setupVideoSession];
        
        [self startCaptureVideo];
    }
    return self;
}

-(void)setupWithMetaData:(NSDictionary*)params{
    /// 将视频渲染结果放入preview
    [_beautyInFilter addTarget:self.previewView];
}

-(void)setupVideoSession{
    dispatch_async(_sessionQueue, ^{
        ///  pixebuffer queue
        
        self->_cameraProcessingQueue = dispatch_queue_create("videoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
        
        /// get videos
        NSArray<AVCaptureDeviceType> *deviceType = @[AVCaptureDeviceTypeBuiltInWideAngleCamera];
        NSArray *positions = @[@(AVCaptureDevicePositionFront), @(AVCaptureDevicePositionBack)];
        
        [positions enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            AVCaptureDevicePosition position = [obj integerValue];
            AVCaptureDeviceDiscoverySession *discoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceType mediaType:AVMediaTypeVideo position:position];
            
            for(AVCaptureDevice *device in discoverySession.devices){
                if(position == AVCaptureDevicePositionFront){
                    self->_frontCamera = device;
                }else if(position == AVCaptureDevicePositionBack){
                    self->_backCamera = device;
                }
            }
        }];
        Loggerinfo(@"device create success!");
        
        /// create capture session
        self->_session = [[AVCaptureSession alloc] init];
        [self->_session beginConfiguration];
        
        /// video input
        NSError *error = nil;
        self->_videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self currentDevice] error:&error];
        if(error != noErr){
            Loggerinfo(@"videoInput set failed!");
        }else{
            if([self.session canAddInput:self->_videoInput]){
                [self->_session addInput: self->_videoInput];
            }
        }
        
        ///  video output
        self->_videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        if([self.session canAddOutput:self->_videoOutput]){
            self.captureFullRange = YES;
            /// output  buffeType  YUV420 FullRange
            [self->_videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
            [self->_videoOutput setSampleBufferDelegate:self queue:self->_cameraProcessingQueue];
            [self.session addOutput:self->_videoOutput];
        }else{
            Loggerinfo(@"videoOutput set failed!");
        }
        
        [self changeCameraVideoSize:self->_cameraVideoSize];
        
        [self.session commitConfiguration];
    });
}

/// @note didOutputSampleBuffer didDropSampleBuffer 做一个区分
#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    
    if(self.session.isRunning && _frameNumber < 3){
        NSLog(@"[%s:%d] drop frame %lu", __FUNCTION__, __LINE__, ++_frameNumber);
        return;
    }
    
    if(self.session.isRunning){
        [self willOutputSampleBuffer:sampleBuffer];
        //        if(_renderView && [_renderView isKindOfClass:[BaseViewController class]] && _renderView){
        //
        //        }
    }else{
        NSLog(@"[%p:%d] session is stop capture!]", __func__, __LINE__);
    }
}

-(void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer{
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
        int pixelWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
        int pixelHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
        
        if(self.imageBufferWidth != pixelWidth || self.imageBufferHeight != pixelHeight){
            Loggerinfo(@"pixel size changed!");
            self.imageBufferWidth  = pixelWidth;
            self.imageBufferHeight = pixelHeight;
            self .rgbOffscreenBuffer = nil;
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

/// 直接上屏
- (void)renderWithoutEffects:(CMTime)currentTime{
    id<GPUImageInput> currentTarget = self.previewView;
    [currentTarget setInputRotation:kGPUImageNoRotation atIndex:0];
    [currentTarget setInputSize:CGSizeMake(self.imageBufferWidth, self.imageBufferHeight) atIndex:0];
    [currentTarget setInputFramebuffer:self.rgbOffscreenBuffer atIndex:0];
    [currentTarget newFrameReadyAtTime:currentTime atIndex:0];
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

-(void)startCaptureVideo{
    NSLog(@"function = [%p] line = [%d] startCaptureVideo", __func__, __LINE__);
    /// 会阻塞当前线程，block添加到queue中后就会立即返回执行线程中后面的方法，
    __weak typeof (self) weakSelf = self;
    dispatch_barrier_async(_sessionQueue, ^{
        __strong typeof (weakSelf) strongSelf = weakSelf;
        if(![strongSelf.session isRunning]){
            [strongSelf.session startRunning];
        }
    });
}

-(void )stopCaptureVideo{
    NSLog(@"function = [%p] line = [%d] stopCaptureVideo", __func__, __LINE__);
    __weak typeof (self) weakSelf = self;
    dispatch_barrier_async(_sessionQueue, ^{
        __strong typeof (weakSelf) strongSelf = weakSelf;
        if([strongSelf.session isRunning]){
            [strongSelf.session stopRunning];
        }
    });
}

///  @brief 修改camera分辨率
///  @param cameraSize 分辨率
-(void)changeCameraVideoSize:(CGSize)cameraSize{
    [self.session beginConfiguration];
    NSLog(@"[%s:%d] cameraSize=[%@]", __func__, __LINE__, NSStringFromCGSize(cameraSize));
    int resolition = cameraSize.width  * cameraSize.height;
    if(resolition > 1280*720){
        if([self.session canSetSessionPreset:AVCaptureSessionPreset1920x1080]){
            _captureSessionPreset = AVCaptureSessionPreset1920x1080;
        }else{
            Loggerinfo(@"session canSetSessionPreset failed!");
        }
    }else if(resolition == 1280*720){
        _captureSessionPreset = AVCaptureSessionPreset1280x720;
    }else if(resolition == 960*540){
        _captureSessionPreset = @"AVCaptureSessionPreset960x540";
    }else if(resolition == 360*640 || resolition == 368*640){
        _captureSessionPreset = AVCaptureSessionPreset640x480;
    }else if(resolition == 320*240){
        _captureSessionPreset = AVCaptureSessionPreset352x288;
    }else{
        _captureSessionPreset = AVCaptureSessionPreset640x480;
    }
    
    //动态设置
    self.session.sessionPreset = _captureSessionPreset;
    [self.session commitConfiguration];
}

///  @brief 获取当前相机捕捉设备实例（前置/后置）
///  @return 当前相机实例
- (AVCaptureDevice *) currentDevice{
    if (_cameraPosition == AVCaptureDevicePositionFront) {
        return _frontCamera;
    }else if(_cameraPosition == AVCaptureDevicePositionBack){
        return _backCamera;
    }else{
        Loggerinfo(@"currentDevice nil!");
        return nil;
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
