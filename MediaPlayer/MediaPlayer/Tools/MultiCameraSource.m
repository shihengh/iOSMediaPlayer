//
//  MultiCameraSource.m
//  MediaPlayer
//
//  Created by shimo-imac on 2023/1/28.
//

#import <Foundation/Foundation.h>
#import "MultiCameraSource.h"
#import <AVFoundation/AVFoundation.h>
#import "GPUImageView.h"
#import "GLDefines.h"

API_AVAILABLE(ios(13.0))

@interface MultiCameraSource () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>{
    dispatch_queue_t _sessionQueue, _cameraProcessingQueue;
}

@property(strong, nonatomic) AVCaptureMultiCamSession* multiSession;        /// 多摄session

@property (nonatomic, strong, nullable) id<RenderDelegate> delegate;        /// 渲染代理类

@property(strong, nonatomic) AVCaptureDeviceInput* frontCameraDeviceInput;  /// 前置相机输入
@property(strong, nonatomic) AVCaptureDeviceInput* backCameraDeviceInput;   /// 后置相机输入
@property(strong, nonatomic) AVCaptureDeviceInput* microphoneDeviceInput;   /// 麦克风

@property(strong, nonatomic) AVCaptureVideoDataOutput* backCameraVideoDataOutput;      /// 后置相机输出
@property(strong, nonatomic) AVCaptureVideoDataOutput* frontCameraVideoDataOutput;     /// 前置相机输出
@property(strong, nonatomic) AVCaptureAudioDataOutput* backMicrophoneAudioDataOutput;  ///
@property(strong, nonatomic) AVCaptureAudioDataOutput* frontMicrophoneAudioDataOutput; ///

@property(strong, nonatomic) AVCaptureVideoPreviewLayer* backCameraVideoPreviewLayer;  /// 后置预览视图
@property(strong, nonatomic) AVCaptureVideoPreviewLayer* frontCameraVideoPreviewLayer; /// 前置预览视图

@property(strong, nonatomic) GPUImageView* frontPreView;
@property(strong, nonatomic) GPUImageView* backPreView;

@end

@implementation MultiCameraSource

- (instancetype)init{
    if(self = [super init]){        
        _sessionQueue = dispatch_queue_create("_sessionQueue", DISPATCH_QUEUE_SERIAL);
        
        dispatch_async(_sessionQueue, ^{
            /// 开始异步处理setupSession
            [self setupVideoSession];
        });
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(sessionStartError:)
                                                     name:AVCaptureSessionRuntimeErrorNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_multiSession stopRunning];
    
    _backCameraDeviceInput  = nil;
    _frontCameraDeviceInput = nil;
    
    [[_multiSession inputs] enumerateObjectsUsingBlock:^(__kindof AVCaptureInput * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [_multiSession removeInput:obj];
    }];
    
    [[_multiSession outputs] enumerateObjectsUsingBlock:^(__kindof AVCaptureOutput * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [_multiSession removeOutput:obj];
    }];
    
    if (@available(iOS 13.0, *)) {
        [[_multiSession connections] enumerateObjectsUsingBlock:^(AVCaptureConnection * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [_multiSession removeConnection:obj];
        }];
    } else {
        /// ...
    }
    
    self.delegate = nil;
    _multiSession = nil;
    _sessionQueue = nil;
    
    NSLog(@"dealloc=[%@][%p]", NSStringFromClass([self class]), self);
}

-(void)sessionStartError:(NSNotification *)notification{
    NSLog(@"[%s:%d] notification:%@", __FUNCTION__, __LINE__, notification);
}

- (void)setDelegate:(id<RenderDelegate>)delegate{
    if(delegate && [delegate respondsToSelector:@selector(willOutputSampleBuffer:isFront:)]){
        _delegate = delegate;
        dispatch_async(_sessionQueue, ^{
            if(![self->_multiSession isRunning]){
                [self->_multiSession startRunning];
                if([self->_multiSession isRunning]){
                    Loggerinfo(@"_multiSession start Successed!");
                }else{
                    Loggerinfo(@"_multiSession start Failed!");
                }
            }
        });
    }
}

-(void)setupVideoSession{
    if (@available(iOS 13.0, *)) {
        _multiSession = [[AVCaptureMultiCamSession alloc] init];
        
        _backCameraVideoDataOutput      = [[AVCaptureVideoDataOutput alloc] init];
        _frontCameraVideoDataOutput     = [[AVCaptureVideoDataOutput alloc] init];
        _backMicrophoneAudioDataOutput  = [[AVCaptureAudioDataOutput alloc] init];
        _frontMicrophoneAudioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
        
        _cameraProcessingQueue = dispatch_queue_create("videoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
        
        if(![AVCaptureMultiCamSession isMultiCamSupported]){
            return;
        }else{
            [_multiSession beginConfiguration];
//            if(![self configureBackCameraWithSessionAsConnection]){
//                NSLog(@"configureBackCameraWithSessionAsConnection failed！");
//                return;
//            }
            if(![self configureBackCamera]){
                NSLog(@"configureBackCamera failed！");
                return;
            }
            
            if(![self configureFrontCamera]){
                NSLog(@"configureBackCamera failed！");
                return;
            }

            if(![self configureMicroPhone]){
                NSLog(@"configureBackCamera failed！");
                return;
            }
            
            
            [_multiSession commitConfiguration];
        }
    } else {
        NSLog(@"[%s:%d] @available iOS 13.0", __FUNCTION__, __LINE__);
    }
}

/// 设置分辨率
- (void)hardcodeForMultiCamera:(AVCaptureDevice *)device{
    [device lockForConfiguration:nil];
    
    for (AVCaptureDeviceFormat *format in device.formats) {
        if (@available(iOS 13.0, *)) {
            if (format.isMultiCamSupported){
                CMVideoDimensions dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
                NSLog(@"activeFormat width=[%d] height=[%d]", dims.width, dims.height);
                ///  默认 1280 * 720
                if(dims.width == 1280 && dims.height == 720){
                    NSLog(@"activeFormat format=[%@]", format);
                    device.activeFormat = format;
                    break;
                }
            }
        }
    }
    [device unlockForConfiguration];
}

/// 设置帧率
/// - Parameter captureDeviceInput: captureDeviceInput
-(void)frameRateForMultiCamera:(AVCaptureDeviceInput*)captureDeviceInput{
    if(!captureDeviceInput) return;
    CMTime activeMinFrameDuration = captureDeviceInput.device.activeVideoMinFrameDuration;
    NSLog(@"activeMinFrameDuration value=[%lld] flags=[%u] epoch=[%lld] timescale=[%u]", activeMinFrameDuration.value, activeMinFrameDuration.flags, activeMinFrameDuration.epoch, activeMinFrameDuration.timescale);
    double activeMaxFrameRate = (double)(activeMinFrameDuration.timescale) / (double)(activeMinFrameDuration.value);
    activeMaxFrameRate -= 10.0;
    
    // Cap the device frame rate to this new max, never allowing it to go below 15 fps
    if(activeMaxFrameRate >= 15){
        [captureDeviceInput.device lockForConfiguration:nil];
        if (@available(iOS 13.0, *)) {
            /// 设置最小最大帧率都是这样设置
            captureDeviceInput.videoMinFrameDurationOverride = CMTimeMake(1, (uint32_t)activeMaxFrameRate);
            NSLog(@"reduced activeMaxFrameRate=[%f]", activeMaxFrameRate);
        } else {
            NSLog(@"[%s:%d] activeMaxFrameRates set Failed!", __FUNCTION__, __LINE__);
        }
        [captureDeviceInput.device unlockForConfiguration];
    }
}

- (BOOL)configureBackCamera{
    
    if(@available(iOS 13.0, *)){
        [_multiSession beginConfiguration];
        
        /// 后置设备
        AVCaptureDevice* backCamera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
        
        /// 设置分辨率
        [self hardcodeForMultiCamera:backCamera];
        
        /// 后置输出
        if(backCamera){
            _backCameraDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:backCamera error:nil];
            if([_multiSession canAddInput:_backCameraDeviceInput]){
                [_multiSession addInputWithNoConnections:_backCameraDeviceInput];
                
                /// 设置码率
                [self frameRateForMultiCamera: _backCameraDeviceInput];
                Loggerinfo(@"_backCameraDeviceInput added!");
            }else{
                Loggerinfo(@"[_backCameraDeviceInput add Failed!]");
                goto failed;
            }
        }else{
            Loggerinfo(@"[Back Camera Create Failed!]");
            goto failed;
        }
        
        /// Find the back camera device input's video port
        AVCaptureInputPort *backCameraVideoPort = [[_backCameraDeviceInput portsWithMediaType:AVMediaTypeVideo sourceDeviceType:backCamera.deviceType sourceDevicePosition:backCamera.position] firstObject];
        
        /// 添加视频输入
        if([_multiSession canAddOutput:_backCameraVideoDataOutput]){
            /// 视频帧输出格式
            if([[_backCameraVideoDataOutput availableVideoCVPixelFormatTypes] containsObject:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]){
                [_backCameraVideoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
                [_multiSession addOutputWithNoConnections:_backCameraVideoDataOutput];
            }
            
            Loggerinfo(@"_backCameraVideoDataOutput added!");
        }else{
            Loggerinfo(@"[_backCameraVideoDataOutput add Failed!]");
            goto failed;
        }
        
        [_backCameraVideoDataOutput setSampleBufferDelegate:self queue:_cameraProcessingQueue];
        
        /// Connect the back camera device input to the back camera video data output
        AVCaptureConnection* backCameraVideoDataOutputConnection = [[AVCaptureConnection alloc] initWithInputPorts:[NSArray arrayWithObjects:backCameraVideoPort, nil] output:_backCameraVideoDataOutput];
        
        if([_multiSession canAddConnection:backCameraVideoDataOutputConnection]){
            [_multiSession addConnection:backCameraVideoDataOutputConnection];
            [backCameraVideoDataOutputConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
            Loggerinfo(@"backCameraVideoDataOutputConnection added!");
        }else{
            Loggerinfo(@"[backCameraVideoDataOutputConnection add Failed!]");
            goto failed;
        }
        [_multiSession commitConfiguration];
    //    /// Connect the back camera device input to the back camera video preview layer
    //    id backCameraVideoPreviewLayerConnection = [[AVCaptureConnection alloc] initWithInputPort:backCameraVideoPort videoPreviewLayer:_backCameraVideoPreviewLayer];
    //
    //    if([_multiSession canAddConnection:backCameraVideoPreviewLayerConnection]){
    //        [_multiSession addConnection:backCameraVideoPreviewLayerConnection];
    //    }else{
    //        NSLog(@"[backCameraVideoPreviewLayerConnection add Failed!]");
    //        return false;
    //    }
    }else{
        NSLog(@"[%s:%d] not available ios 13", __FUNCTION__, __LINE__);
        return false;
    }
    return true;
failed:
    [_multiSession commitConfiguration];
    return false;
}

-(bool)configureFrontCamera{
    if(@available(iOS 13.0, *)){
        [_multiSession beginConfiguration];
        
        /// 前置设备
        AVCaptureDevice* frontCamera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
        
        [self hardcodeForMultiCamera:frontCamera];
        
        /// 前置输入
        if(frontCamera){
            _frontCameraDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:frontCamera error:nil];
            if([_multiSession canAddInput:_frontCameraDeviceInput]){
                [_multiSession addInputWithNoConnections:_frontCameraDeviceInput];
                Loggerinfo(@"_frontCameraDeviceInput added!");
                
                /// 设置码率
                [self frameRateForMultiCamera: _frontCameraDeviceInput];
            }else{
                Loggerinfo(@"[_frontCameraDeviceInput add Failed!]");
                goto failed;
            }
        }else{
            Loggerinfo(@"[front Camera Create Failed!]");
            goto failed;
        }
        
        /// Find the front camera device input's video port
        id frontCameraVideoPort = [[_frontCameraDeviceInput portsWithMediaType:AVMediaTypeVideo sourceDeviceType:frontCamera.deviceType sourceDevicePosition:frontCamera.position] firstObject];
        
        /// 添加输出
        if([_multiSession canAddOutput:_frontCameraVideoDataOutput]){
            if([[_frontCameraVideoDataOutput availableVideoCVPixelFormatTypes] containsObject:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]){
                [_frontCameraVideoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
                
                [_multiSession addOutputWithNoConnections:_frontCameraVideoDataOutput];
                //            [_multiSession addOutput:_frontCameraVideoDataOutput];
                Loggerinfo(@"_frontCameraVideoDataOutput added!");
                
            }
        }else{
            Loggerinfo(@"[_frontCameraVideoDataOutput add Failed!]");
            goto failed;
        }
        
        [_frontCameraVideoDataOutput setSampleBufferDelegate:self queue:_cameraProcessingQueue];
        
        /// Connect the back camera device input to the back camera video data output
        AVCaptureConnection* frontCameraVideoDataOutputConnection = [[AVCaptureConnection alloc] initWithInputPorts:[NSArray arrayWithObjects:frontCameraVideoPort, nil] output:_frontCameraVideoDataOutput];
        
        /// @remark 前置设置了一个镜像反转
        frontCameraVideoDataOutputConnection.videoMirrored = true;

        if([_multiSession canAddConnection:frontCameraVideoDataOutputConnection]){
            [_multiSession addConnection:frontCameraVideoDataOutputConnection];
            [frontCameraVideoDataOutputConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
            Loggerinfo(@"frontCameraVideoDataOutputConnection added!");
        }else{
            Loggerinfo(@"[frontCameraVideoDataOutputConnection add Failed!]");
            goto failed;
        }
        [_multiSession commitConfiguration];
        //    /// Connect the back camera device input to the back camera video preview layer
        //    id frontCameraVideoPreviewLayerConnection = [[AVCaptureConnection alloc] initWithInputPort:frontCameraVideoPort videoPreviewLayer:_frontCameraVideoPreviewLayer];
        //
        //    if([_multiSession canAddConnection:frontCameraVideoPreviewLayerConnection]){
        //        [_multiSession addConnection:frontCameraVideoPreviewLayerConnection];
        //    }else{
        //        NSLog(@"[frontCameraVideoPreviewLayerConnection add Failed!]");
        //        return false;
        //    }
    }else{
        NSLog(@"[%s:%d] not available ios 13", __FUNCTION__, __LINE__);
        return false;
    }
    return true;
    
failed:
    [_multiSession commitConfiguration];
    return false;
}

-(bool)configureMicroPhone{
    if(@available(iOS 13.0, *)){
        [_multiSession beginConfiguration];
        
        /// Find the microphone
        AVCaptureDevice* microphone = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        if(!microphone){
            NSLog(@"Create microphone failed");
            
            [_multiSession commitConfiguration];
            return false;
        }
        
        // Add the microphone input to the session
        _microphoneDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:microphone error:nil];
        if(!_microphoneDeviceInput){           NSLog(@"Create microphoneInput failed");
            NSLog(@"create devicInput failed");
            
            [_multiSession commitConfiguration];
            return false;
        }
        
        if([_multiSession canAddInput:_microphoneDeviceInput]){
            [_multiSession addInputWithNoConnections:_microphoneDeviceInput];
        }else{
            NSLog(@"add _microphoneDeviceInput failed");
            
            [_multiSession commitConfiguration];
            return false;
        }
        
        /// Find the audio device input's back audio port
        id backMicrophonePort = [[_microphoneDeviceInput portsWithMediaType:AVMediaTypeAudio sourceDeviceType:microphone.deviceType sourceDevicePosition:AVCaptureDevicePositionBack] firstObject];
        
        /// Find the audio device input's front audio port
        id frontMicrophonePort = [[_microphoneDeviceInput portsWithMediaType:AVMediaTypeAudio sourceDeviceType:microphone.deviceType sourceDevicePosition:AVCaptureDevicePositionFront] firstObject];
        
        /// Add the back microphone audio data output
        if([_multiSession canAddOutput:_backMicrophoneAudioDataOutput]){
            [_multiSession addOutputWithNoConnections:_backMicrophoneAudioDataOutput];
            [_backMicrophoneAudioDataOutput setSampleBufferDelegate:self queue:_cameraProcessingQueue];
        }else{
            NSLog(@"add _backMicrophoneAudioDataOutput failed");
            
            [_multiSession commitConfiguration];
            return false;
        }
        
        /// Add the front microphone audio data output
        if([_multiSession canAddOutput:_frontMicrophoneAudioDataOutput]){
            [_multiSession addOutputWithNoConnections:_frontMicrophoneAudioDataOutput];
            [_frontMicrophoneAudioDataOutput setSampleBufferDelegate:self queue:_cameraProcessingQueue] ;
        }else{
            NSLog(@"add _frontMicrophoneAudioDataOutput failed");
            
            [_multiSession commitConfiguration];
            return false;
        }
        
        /// Connect the back microphone to the back audio data output
        id backMicrophoneAudioDataOutputConnection = [[AVCaptureConnection alloc] initWithInputPorts:[NSArray arrayWithObjects:backMicrophonePort, nil] output:_backMicrophoneAudioDataOutput];
        id frontMicrophoneAudioDataOutputConnection = [[AVCaptureConnection alloc] initWithInputPorts:[NSArray arrayWithObjects:frontMicrophonePort, nil] output:_frontMicrophoneAudioDataOutput];
        
        if([_multiSession canAddConnection:backMicrophoneAudioDataOutputConnection]){
            [_multiSession addConnection:backMicrophoneAudioDataOutputConnection];
        }else{
            NSLog(@"add backMicrophoneAudioDataOutputConnection failed");
            
            [_multiSession commitConfiguration];
            return false;
        }
        if([_multiSession canAddConnection:frontMicrophoneAudioDataOutputConnection]){
            [_multiSession addConnection:frontMicrophoneAudioDataOutputConnection];
        }else{
            NSLog(@"add frontMicrophoneAudioDataOutputConnection failed");
            
            [_multiSession commitConfiguration];
            return false;
        }
        
        [_multiSession commitConfiguration];
    }else{
        NSLog(@"[%s:%d] not available ios 13", __FUNCTION__, __LINE__);
        return false;
    }
    return true;
}

#pragma delegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    if([output isKindOfClass:[AVCaptureVideoDataOutput class]]){
        if(output == _frontCameraVideoDataOutput && sampleBuffer && _delegate && [_delegate respondsToSelector:@selector(willOutputSampleBuffer:isFront:)]){
            [_delegate willOutputSampleBuffer:sampleBuffer isFront:true];
        }else if(output == _backCameraVideoDataOutput && sampleBuffer && _delegate && [_delegate respondsToSelector:@selector(willOutputSampleBuffer:isFront:)]){
            [_delegate willOutputSampleBuffer:sampleBuffer isFront:false];
        }else{
            [self print:@"not define VideoDataOutput"];
        }
    }else{
//        {
//            static uint64_t count = 0;
//            NSLog(@"odd=[%llu]", count++);
//            NSLog(@"output=[%@]", [output class]);
//        }
    }
}

-(void)print:(NSString* )str{
    static uint64_t count = 0;
    NSLog(@"[%@]+[%llu]", str, count++);
}

@end
