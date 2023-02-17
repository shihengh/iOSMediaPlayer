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

@interface CameraSource() <AVCaptureVideoDataOutputSampleBufferDelegate>{
    dispatch_queue_t _cameraProcessingQueue, _sessionQueue;
}

@property(assign, nonatomic) BOOL isFront;
@property(strong, nonatomic) AVCaptureSession* session;
@property(strong, nonatomic) AVCaptureInput* input;
@property(strong, nonatomic) AVCaptureVideoDataOutput* output;
@property(strong, nonatomic) BaseViewController* renderView;

@end

@implementation CameraSource

-(instancetype)initWithDelegate:(BOOL)isFront renderView:(BaseViewController*)renderView{
    if(self == [super init]){
        /// 串型队列
        _sessionQueue = dispatch_queue_create("_sessionQueue", DISPATCH_QUEUE_SERIAL);
        
        self.isFront = isFront;
        self.renderView = renderView;
        
        [self initVideoSession];
        [self startCaptureVideo];
    }
    return self;
}

-(void)initVideoSession{
    dispatch_async(_sessionQueue, ^{
        /// 串型队列
        self->_cameraProcessingQueue = dispatch_queue_create("videoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
        
        /// 创建sessiom
        self.session  = [[AVCaptureSession alloc] init];
        [self.session beginConfiguration];
        self->_session.sessionPreset = AVCaptureSessionPreset1280x720;
        
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        
        /// 添加输入
        for(AVCaptureDevice *device in devices){
            if(device.position == (self.isFront ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack)){
                AVCaptureDeviceInput* videoDataInput = [[AVCaptureDeviceInput alloc] initWithDevice:device error:nil];
                if([self.session canAddInput: videoDataInput]){
                    [self.session addInput:videoDataInput] ;
                    self.input = videoDataInput;
                }
            }
        }
        
        /// 输出属性
        NSMutableDictionary* videoOutputSetting = @{}.mutableCopy;
        videoOutputSetting[(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey] = @(kCVPixelFormatType_32BGRA);
        
        /// 添加输出
        AVCaptureVideoDataOutput* sessionVideoOutput = [[AVCaptureVideoDataOutput alloc] init];
        sessionVideoOutput.alwaysDiscardsLateVideoFrames = YES;
        [sessionVideoOutput setVideoSettings:videoOutputSetting];
        [sessionVideoOutput setSampleBufferDelegate:self queue:self->_cameraProcessingQueue];
        if([self.session canAddOutput:sessionVideoOutput]){
            [self.session addOutput:sessionVideoOutput];
            self.output = sessionVideoOutput;
        }
        [self.session commitConfiguration];
    });
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    if(!self.session.isRunning){
        CVImageBufferRef cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer);
        NSLog(@"[funcion = [%p] line = [%d] Pause SampleBuffer OutPut]", __func__, __LINE__);
        if(_renderView && [_renderView isKindOfClass:[BaseViewController class]] && _renderView){
            
        }
        return;
    }else{
        NSLog(@"[%p %d SampleBuffer OutPut]", __func__, __LINE__);
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
@end
