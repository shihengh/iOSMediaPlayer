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
    -1.0f,  -1.0f,
     1.0f,  -1.0f,
    -1.0f,   1.0f,
     1.0f,   1.0f,
};

@interface CameraSource() <AVCaptureVideoDataOutputSampleBufferDelegate>{
    dispatch_queue_t _cameraProcessingQueue, _sessionQueue;
    AVCaptureDeviceInput     *_videoInput;
    AVCaptureVideoDataOutput *_videoOutput;
}

@property(strong, nonatomic) AVCaptureSession* session;                    /// session
@property (nonatomic, strong, nullable) id<RenderDelegate> delegate;       /// 渲染代理类
@property (nonatomic, weak) AVCaptureDevice *frontCamera;                  /// 前置设备
@property (nonatomic, weak) AVCaptureDevice *backCamera;                   /// 后置设备
@property (nonatomic, assign) NSUInteger frameNumber;                      /// 帧的数目 3帧内抛弃

@property (nonatomic, assign) BOOL captureFullRange;                       ///  全屏
@property (readwrite, nonatomic, copy) NSString *captureSessionPreset;     ///  清晰度
@property (nonatomic, readwrite) AVCaptureDevicePosition cameraPosition;   ///  摄像头
@property (nonatomic, readwrite) CGSize cameraVideoSize;                   ///  视频显示清晰度

@end

@implementation CameraSource

-(instancetype)init{
    if(self == [super init]){
        
        /// 串型队列
        _sessionQueue = dispatch_queue_create("_sessionQueue", DISPATCH_QUEUE_SERIAL);
        
        /// @remark 开始相机捕捉
        self.cameraPosition  = AVCaptureDevicePositionBack;
        self.cameraVideoSize = CGSizeMake(1280, 720);
        
        /// 初始化设备采集
        [self setupVideoSession];
    
        /// 设备摆放位置通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(deviceOrientationDidChange:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
        
        NSLog(@"construct=[%@][%p]", NSStringFromClass([self class]), self);
    }
    return self;
}

- (void)dealloc{
    NSLog(@"[%s:%d]", __FUNCTION__, __LINE__);
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
        
        [self deviceOrientationDidChange:nil];
        
        [self autoSetCaptureMirrored];
        
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
    
    if(self.session.isRunning && sampleBuffer){
        if(_delegate && [_delegate respondsToSelector:@selector(willOutputSampleBuffer:)]){
            [_delegate willOutputSampleBuffer:sampleBuffer];
        }
    }else{
        NSLog(@"[%p:%d] session is stop capture!]", __func__, __LINE__);
    }
}

-(void)changeCapturePosition:(AVCaptureDevicePosition)position{
    self.cameraPosition = position;
    
    NSError *error;
    AVCaptureDeviceInput *newInput = [[AVCaptureDeviceInput alloc] initWithDevice: [self currentDevice] error:&error];
    if(newInput == nil || _session == nil){
        NSLog(@"[%s:%d] position=[%d] set falied!", __FUNCTION__, __LINE__, (int)position);
        return;
    }else{
        [_session beginConfiguration];
        /// @remark 注意这里摄像头Session是只能添加一个input的 先移除 再CanAddInput
        [_session removeInput:_videoInput];
        if([_session canAddInput:newInput]){
            [_session addInput:newInput];
            _videoInput = newInput;
        }else{
            [_session addInput:_videoInput];
        }
        
        [self deviceOrientationDidChange:nil];
        
        [self autoSetCaptureMirrored];
        
        [_session commitConfiguration];
    }
}

- (void)setDelegate:(id<RenderDelegate>)delegate{
    if(delegate && [delegate respondsToSelector:@selector(willOutputSampleBuffer:)]){
        _delegate = delegate;
    }
}

-(void)startCaptureVideo{
    /// 会阻塞当前线程，block添加到queue中后就会立即返回执行线程中后面的方法，
    __weak typeof (self) weakSelf = self;
    dispatch_barrier_async(_sessionQueue, ^{
        __strong typeof (weakSelf) strongSelf = weakSelf;
        if(![strongSelf.session isRunning]){
            [strongSelf.session startRunning];
            NSLog(@"function = [%p] line = [%d] startCaptureVideo", __func__, __LINE__);
        }
    });
}

-(void)stopCaptureVideo{

    __weak typeof (self) weakSelf = self;
    dispatch_barrier_async(_sessionQueue, ^{
        __strong typeof (weakSelf) strongSelf = weakSelf;
        if([strongSelf.session isRunning]){
            [strongSelf.session stopRunning];
            NSLog(@"function = [%p] line = [%d] stopCaptureVideo", __func__, __LINE__);
            /**
            {
                [self->_session.inputs enumerateObjectsUsingBlock:^(__kindof AVCaptureInput * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop){
                    [self->_session removeInput:obj];
                }];
    
                [self->_session.outputs enumerateObjectsUsingBlock:^(__kindof AVCaptureOutput * _Nonnull obj,
                                                                      NSUInteger idx, BOOL * _Nonnull stop) {
                    [self->_session removeOutput:obj];
                }];
    
                AVCaptureConnection *connection = [self->_videoOutput connectionWithMediaType:AVMediaTypeVideo];
                if (connection) {
                    [self->_session removeConnection:connection];
                }
            }
            */
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
        ///  暂时不用
        /// _captureSessionPreset = @"AVCaptureSessionPreset960x540";
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

-(void)autoSetCaptureMirrored{
    /// 前置镜像
    if([self currentDevice] == _frontCamera){
        [_session beginConfiguration];
        AVCaptureConnection *connect = [_videoOutput connectionWithMediaType:AVMediaTypeVideo];
        connect.videoMirrored = true;
        [_session commitConfiguration];
    }
}

-(void)deviceOrientationDidChange:(NSNotification *)not{
    /// 设备当前方向
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    
    AVCaptureConnection *connect = [_videoOutput connectionWithMediaType:AVMediaTypeVideo];
    
    switch(orientation){
        case UIDeviceOrientationPortrait:
            connect.videoOrientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            connect.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIDeviceOrientationLandscapeLeft:  /// home to the right
            connect.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case UIDeviceOrientationLandscapeRight: /// home to the left
            connect.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        default:
            connect.videoOrientation = AVCaptureVideoOrientationPortrait;
            break;
    }
    NSLog(@"[%s:%d] current UIDeviceOrientationPortrait=[%d]", __FUNCTION__, __LINE__, (int)orientation);
}
@end
