//
//  MultiCameraSource.m
//  MediaPlayer
//
//  Created by shimo-imac on 2023/1/28.
//

#import "MultiCameraSource.h"
#import <AVFoundation/AVFoundation.h>

@interface MultiCameraSource () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>{
    dispatch_queue_t _sessionQueue;
}
@property(assign, nonatomic) BOOL isMulti;

@property(strong, nonatomic) AVCaptureMultiCamSession* multiSession;

@property(strong, nonatomic) AVCaptureDeviceInput* frontCameraDeviceInput;
@property(strong, nonatomic) AVCaptureDeviceInput* backCameraDeviceInput;
@property(strong, nonatomic) AVCaptureDeviceInput* microphoneDeviceInput;

@property(strong, nonatomic) AVCaptureVideoDataOutput* backCameraVideoDataOutput;
@property(strong, nonatomic) AVCaptureVideoDataOutput* frontCameraVideoDataOutput;
@property(strong, nonatomic) AVCaptureAudioDataOutput* backMicrophoneAudioDataOutput;
@property(strong, nonatomic) AVCaptureAudioDataOutput* frontMicrophoneAudioDataOutput;

@property(strong, nonatomic) AVCaptureVideoPreviewLayer* backCameraVideoPreviewLayer;
@property(strong, nonatomic) AVCaptureVideoPreviewLayer* frontCameraVideoPreviewLayer;

@end

@implementation MultiCameraSource

- (instancetype)init{
    if(self = [super init]){
        _isMulti = true;
        
        _sessionQueue = dispatch_queue_create("_sessionQueue", DISPATCH_QUEUE_SERIAL);
        
        dispatch_async(_sessionQueue, ^{
            [self configureSession];
            [self->_multiSession startRunning];
            NSLog(@"[%s:%d] isMulti=[%p]", __FUNCTION__, __LINE__,  self->_multiSession);
        });
        
    }
    return self;
}

-(void)configureSession{
    _multiSession = [[AVCaptureMultiCamSession alloc] init];
    
    _backCameraVideoDataOutput  = [[AVCaptureVideoDataOutput alloc] init];
    _frontCameraVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    _backMicrophoneAudioDataOutput  = [[AVCaptureAudioDataOutput alloc] init];
    _frontMicrophoneAudioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    
    if(![AVCaptureMultiCamSession isMultiCamSupported]){
        self.isMulti = false;
        return;
    }else{
        self.isMulti = true;
        
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
    }
    [_multiSession commitConfiguration];
    NSLog(@"[%s:%d] isMulti=[%d]", __FUNCTION__, __LINE__,  self.isMulti);
}

-(bool)configureBackCamera{
    
    [_multiSession beginConfiguration];
    
    /// Find the back camera
    AVCaptureDevice* backCamera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    
    /// Add the back camera input to the session
    if(backCamera){
        _backCameraDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:backCamera error:nil];
        if([_multiSession canAddInput:_backCameraDeviceInput]){
            [_multiSession addInputWithNoConnections:_backCameraDeviceInput];
        }else{
            NSLog(@"[_backCameraDeviceInput add Failed!]");
            
            [_multiSession commitConfiguration];
            return false;
        }
    }else{
        NSLog(@"[Back Camera Create Failed!]");
        
        [_multiSession commitConfiguration];
        return false;
    }
    
    /// Find the back camera device input's video port
    id backCameraVideoPort = [[_backCameraDeviceInput portsWithMediaType:AVMediaTypeVideo sourceDeviceType:backCamera.deviceType sourceDevicePosition:backCamera.position] firstObject];
    
    /// Add the back camera video data output
    if([_multiSession canAddOutput:_backCameraVideoDataOutput]){
        [_multiSession addOutputWithNoConnections:_backCameraVideoDataOutput];
    }else{
        NSLog(@"[_backCameraVideoDataOutput add Failed!]");
        
        [_multiSession commitConfiguration];
        return false;
    }
    
    /// Check if CVPixelFormat Lossy or Lossless Compression is supported
    if([[_backCameraVideoDataOutput availableVideoCVPixelFormatTypes] containsObject:@(kCVPixelFormatType_Lossy_32BGRA)]){
        [_backCameraVideoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:
[NSNumber numberWithInt:kCVPixelFormatType_Lossy_32BGRA]
             forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    }else if([[_backCameraVideoDataOutput availableVideoCVPixelFormatTypes] containsObject:@(kCVPixelFormatType_Lossless_32BGRA)]){
        [_backCameraVideoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:
[NSNumber numberWithInt:kCVPixelFormatType_Lossless_32BGRA]
             forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    }else{
        [_backCameraVideoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:
[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
             forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    }
    
    [_backCameraVideoDataOutput setSampleBufferDelegate:self queue:_sessionQueue];
    
    /// Connect the back camera device input to the back camera video data output
    id backCameraVideoDataOutputConnection = [[AVCaptureConnection alloc] initWithInputPorts:[NSArray arrayWithObjects:backCameraVideoPort, nil] output:_backCameraVideoDataOutput];
    
    if([_multiSession canAddConnection:backCameraVideoDataOutputConnection]){
        [_multiSession addConnection:backCameraVideoDataOutputConnection];
        [backCameraVideoDataOutputConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    }else{
        NSLog(@"[backCameraVideoDataOutputConnection add Failed!]");
       
        [_multiSession commitConfiguration];
        return false;
    }
    
//    /// Connect the back camera device input to the back camera video preview layer
//    id backCameraVideoPreviewLayerConnection = [[AVCaptureConnection alloc] initWithInputPort:backCameraVideoPort videoPreviewLayer:_backCameraVideoPreviewLayer];
//
//    if([_multiSession canAddConnection:backCameraVideoPreviewLayerConnection]){
//        [_multiSession addConnection:backCameraVideoPreviewLayerConnection];
//    }else{
//        NSLog(@"[backCameraVideoPreviewLayerConnection add Failed!]");
//        return false;
//    }

    [_multiSession commitConfiguration];
    return true;
}

-(bool)configureFrontCamera{
    
    [_multiSession beginConfiguration];
    
    /// Find the back camera
    AVCaptureDevice* frontCamera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
    
    /// Add the back camera input to the session
    if(frontCamera){
        _frontCameraDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:frontCamera error:nil];
        if([_multiSession canAddInput:_frontCameraDeviceInput]){
            [_multiSession addInputWithNoConnections:_frontCameraDeviceInput];
        }else{
            NSLog(@"[_frontCameraDeviceInput add Failed!]");
            
            [_multiSession commitConfiguration];
            return false;
        }
    }else{
        NSLog(@"[front Camera Create Failed!]");
        
        [_multiSession commitConfiguration];
        return false;
    }
    
    /// Find the front camera device input's video port
    id frontCameraVideoPort = [[_frontCameraDeviceInput portsWithMediaType:AVMediaTypeVideo sourceDeviceType:frontCamera.deviceType sourceDevicePosition:frontCamera.position] firstObject];
    
    /// Add the front camera video data output
    if([_multiSession canAddOutput:_frontCameraVideoDataOutput]){
        [_multiSession addOutputWithNoConnections:_frontCameraVideoDataOutput];
    }else{
        NSLog(@"[_frontCameraVideoDataOutput add Failed!]");
        
        [_multiSession commitConfiguration];
        return false;
    }
    
    /// Check if CVPixelFormat Lossy or Lossless Compression is supported
    if([[_frontCameraVideoDataOutput availableVideoCVPixelFormatTypes] containsObject:@(kCVPixelFormatType_Lossy_32BGRA)]){
        [_frontCameraVideoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:
[NSNumber numberWithInt:kCVPixelFormatType_Lossy_32BGRA]
             forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    }else if([[_frontCameraVideoDataOutput availableVideoCVPixelFormatTypes] containsObject:@(kCVPixelFormatType_Lossless_32BGRA)]){
        [_frontCameraVideoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:
[NSNumber numberWithInt:kCVPixelFormatType_Lossless_32BGRA]
             forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    }else{
        [_frontCameraVideoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:
[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
             forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    }
    
    [_frontCameraVideoDataOutput setSampleBufferDelegate:self queue:_sessionQueue];
    
    /// Connect the back camera device input to the back camera video data output
    id frontCameraVideoDataOutputConnection = [[AVCaptureConnection alloc] initWithInputPorts:[NSArray arrayWithObjects:frontCameraVideoPort, nil] output:_frontCameraVideoDataOutput];
    
    if([_multiSession canAddConnection:frontCameraVideoDataOutputConnection]){
        [_multiSession addConnection:frontCameraVideoDataOutputConnection];
        [frontCameraVideoDataOutputConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    }else{
        NSLog(@"[frontCameraVideoDataOutputConnection add Failed!]");
        
        [_multiSession commitConfiguration];
        return false;
    }
    
//    /// Connect the back camera device input to the back camera video preview layer
//    id frontCameraVideoPreviewLayerConnection = [[AVCaptureConnection alloc] initWithInputPort:frontCameraVideoPort videoPreviewLayer:_frontCameraVideoPreviewLayer];
//
//    if([_multiSession canAddConnection:frontCameraVideoPreviewLayerConnection]){
//        [_multiSession addConnection:frontCameraVideoPreviewLayerConnection];
//    }else{
//        NSLog(@"[frontCameraVideoPreviewLayerConnection add Failed!]");
//        return false;
//    }
    [_multiSession commitConfiguration];
    return true;
}

-(bool)configureMicroPhone{
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
        [_backMicrophoneAudioDataOutput setSampleBufferDelegate:self queue:_sessionQueue];
    }else{
        NSLog(@"add _backMicrophoneAudioDataOutput failed");
        
        [_multiSession commitConfiguration];
        return false;
    }
    
    /// Add the front microphone audio data output
    if([_multiSession canAddOutput:_frontMicrophoneAudioDataOutput]){
        [_multiSession addOutputWithNoConnections:_frontMicrophoneAudioDataOutput];
        [_frontMicrophoneAudioDataOutput setSampleBufferDelegate:self queue:_sessionQueue] ;
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
    return true;
}

#pragma delegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
//    AVCaptureVideoDataOutput
   
    if([output isKindOfClass:[AVCaptureVideoDataOutput class]]){
        if(output == _frontCameraVideoDataOutput){
            CVImageBufferRef cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer);
            [self print:@"_frontCameraVideoDataOutput"];
        }else if(output == _backCameraVideoDataOutput){
            CVImageBufferRef cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer);
            [self print:@"_backCameraVideoDataOutput"];
        }else{
            [self print:@"no"];
        }
    }else{
        {
            static uint64_t count = 0;
            NSLog(@"odd=[%llu]", count++);
            NSLog(@"output=[%@]", [output class]);
        }
    }
}

-(void)print:(NSString* )str{
    static uint64_t count = 0;
    NSLog(@"[%@]+[%llu]", str, count++);
}

@end
