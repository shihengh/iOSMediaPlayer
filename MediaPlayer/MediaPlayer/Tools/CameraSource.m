//
//  CameraSource.m
//  MediaPlayer
//
//  Created by shimo-imac on 2023/1/20.
//

#import "CameraSource.h"
#import "VideoRenderController.h"
#import "BaseViewController.h"
#import <AVFoundation/AVFoundation.h>

#define Loggerinfo(msg) NSLog(@"[%s:%d] %@", __FUNCTION__, __LINE__, msg);

@interface CameraSource() <AVCaptureVideoDataOutputSampleBufferDelegate>{
    dispatch_queue_t _cameraProcessingQueue, _sessionQueue;
    AVCaptureDeviceInput     *videoInput;
    AVCaptureVideoDataOutput *videoOutput;
}

@property(strong, nonatomic) AVCaptureSession* session;
@property(strong, nonatomic) BaseViewController* renderView;

@property (nonatomic, assign) BOOL captureFullRange;
@property (readwrite, nonatomic, copy) NSString *captureSessionPreset;     ///  清晰度
@property (nonatomic, readwrite) AVCaptureDevicePosition cameraPosition;   ///  摄像头
@property (nonatomic, readwrite) CGSize cameraVideoSize;

@property (nonatomic, weak) AVCaptureDevice *frontCamera;
@property (nonatomic, weak) AVCaptureDevice *backCamera;

@end

@implementation CameraSource

-(instancetype)initWithDelegate:(BOOL)isFront renderView:(BaseViewController*)renderView{
    if(self == [super init]){
        
        /// 串型队列
        _sessionQueue = dispatch_queue_create("_sessionQueue", DISPATCH_QUEUE_SERIAL);

        self.renderView = renderView;
        self.cameraPosition  = AVCaptureDevicePositionFront;
        self.cameraVideoSize = CGSizeMake(1280, 720);
        
        [self setupVideoSession];
    }
    return self;
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
        
        ///  create capture session
        self->_session = [[AVCaptureSession alloc] init];
        [self->_session beginConfiguration];
        
        /// video input
        NSError *error = nil;
        self->videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self currentDevice] error:&error];
        if(error != noErr){
            Loggerinfo(@"videoInput set failed!");
        }else{
            if([self.session canAddInput:self->videoInput]){
                [self->_session addInput: self->videoInput];
            }
        }
        
        ///  video output
        self->videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        if([self.session canAddOutput:self->videoOutput]){
            self.captureFullRange = YES;
            /// output  buffeType  YUV420 FullRange
            [self->videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
            [self->videoOutput setSampleBufferDelegate:self queue:self->_cameraProcessingQueue];
            [self.session addOutput:self->videoOutput];
        }
        

        [self changeCameraVideoSize:self->_cameraVideoSize];
         
        [self.session commitConfiguration];
    });
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    NSLog(@"--");
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if(pixelBuffer){
        NSLog(@"smapleBuffer");
    }else{
        NSLog(@"nil smapleBuffer");
    }
//    if( self.session.isRunning){
//        CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
//
//        NSLog(@"[funcion = [%p] line = [%d] Pause SampleBuffer OutPut]", __FUNCTION__, __LINE__);
//        if(_renderView && [_renderView isKindOfClass:[BaseViewController class]] && _renderView){
//
//        }
//        return;
//    }else{
//        NSLog(@"[%p %d SampleBuffer OutPut]", __func__, __LINE__);
//    }
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

@end
