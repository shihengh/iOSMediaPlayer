//
//  MultiCameraRender.m
//  MediaPlayer
//
//  Created by shimo-imac on 2023/3/1.
//

#import "MultiCameraRender.h"

#import <OpenGLES/ES3/gl.h>
#import "GPUImageOutput.h"
#import "GPUImageFilter.h"
#import "GLDefines.h"

#import "PixelBufferQueue.h"

static GLfloat IntegrationSquareVertices[] = {
    -1.0f,  -1.0f,
     1.0f,  -1.0f,
    -1.0f,   1.0f,
     1.0f,   1.0f,
};

///  right-button
static GLfloat MinIntegrationSquareVertices[] = {
     0.5f,   0.5f,
     1.0f,   0.5f,
     0.5f,   1.0f,
     1.0f,   1.0f,
};

/// 顶点着色器程序
NSString *const kDYGPUImageMediaFilterForVertexShaderString = SHADER_STRING
(
     attribute vec4 position;
     attribute vec4 inputTextureCoordinate;
     
     /// 纹理着色器程序
     varying vec2 textureCoordinate;
     void main()
     {
         gl_Position = position;
         textureCoordinate = inputTextureCoordinate.xy;
     }
 );

/// 片元着色器
NSString *const KDYGPUImageMediaFilterForFragmentShaderString = SHADER_STRING
(
     precision highp float;
     varying highp vec2 textureCoordinate;
     uniform sampler2D inputImageTexture;
     
     void main()
     {
         vec4 centralColor = texture2D(inputImageTexture, textureCoordinate);
         gl_FragColor = centralColor;
     }
 );

@interface MultiCameraRender() {
    dispatch_queue_t readQueue;
}

@property(nonatomic, strong) PixelBufferQueue* pixelBufferQueue;

/*----------------------------------------------------------------------------------*/

@property (nonatomic, strong) GPUImageFramebuffer *mixFrameBuffer; /// 混和textureId
@property (nonatomic, assign) int imageBufferWidth;                /// 上屏width
@property (nonatomic, assign) int imageBufferHeight;               /// 上屏height

@property (nonatomic, assign) GLfloat* firstVertics;               /// 第一个textureID的顶点坐标
@property (nonatomic, assign) GLfloat* secondVertics;              /// 第二个textureID的顶点坐标
@property (nonatomic, assign) const GLfloat* firstCoordinates;     /// 第一个textureID的纹理坐标
@property (nonatomic, assign) const GLfloat* secondCoordinates;    /// 第二个textureID的纹理坐标
///
@property (nonatomic, strong) GLProgram *mixProgram;               /// 混合着色器程序
@property (nonatomic, assign) GLint positionAttribute;             /// 定点坐标location
@property (nonatomic, assign) GLint textureCoordinateAttribute;    /// 纹理坐标location
@property (nonatomic, assign) GLint filterInputTextureUniform;     /// 纹理location

@property (nonatomic, assign) bool finishBack;                     /// 后置是否渲染完成
@property (nonatomic, assign) bool finishFront;                    /// 前置是否渲染完成


@end

@implementation MultiCameraRender

- (instancetype)init{
    if(self == [super init]){
        _finishBack  = 0;
        _finishFront = 0;

        /// 初始化着色器参数
        _firstVertics  = IntegrationSquareVertices;
        _secondVertics = MinIntegrationSquareVertices;
        _firstCoordinates  = [GPUImageFilter textureCoordinatesForRotation:kGPUImageNoRotation];
        _secondCoordinates = [GPUImageFilter textureCoordinatesForRotation:kGPUImageNoRotation];
        
        readQueue = dispatch_queue_create("readPixelQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

-(void)dealloc{
    _finishBack  = 0;
    _finishFront = 0;
    
    _firstVertics = nil;
    _secondVertics = nil;
    _firstCoordinates = nil;
    _secondCoordinates = nil;
    
    readQueue = nil;
    _mixProgram  = nil;
    _mixFrameBuffer = nil;
    
    NSLog(@"dealloc=[%@][%p] multiRender", NSStringFromClass([self class]), self);
}

/// @brief 编译着色器程序
-(void)compileMixGLProgram{
    if(_mixProgram == nil){
        /// 创建着色器
        _mixProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kDYGPUImageMediaFilterForVertexShaderString fragmentShaderString:KDYGPUImageMediaFilterForFragmentShaderString];
        
        /// 着色器没有初始化
        if(!_mixProgram.initialized){
            
            /// 绑定glprogram顶点坐标、纹理和相对索引
            [_mixProgram addAttribute:@"position"];
            [_mixProgram addAttribute:@"inputTextureCoordinate"];
            
            /// 所有attribute需要在link之后才可以访问到
            if(![_mixProgram link]){
                NSString *progLog = [_mixProgram programLog];
                NSString *fragLog = [_mixProgram fragmentShaderLog];
                NSString *vertLog = [_mixProgram vertexShaderLog];
                NSLog(@"Program link log=[%@] \n"
                      "Fragment shader compile log=[%@] \n"
                      "Vertex shader compile log=[%@]   \n", progLog, fragLog, vertLog);
                _mixProgram = nil;
                NSAssert(NO, @"Filter shader link failed");
            }else{
                NSLog(@"program link success!");
            }
        }
        _positionAttribute = [_mixProgram attributeIndex:@"position"];
        _textureCoordinateAttribute = [_mixProgram attributeIndex:@"inputTextureCoordinate"];
        _filterInputTextureUniform = [_mixProgram uniformIndex:@"inputImageTexture"];
    }
}

#pragma mark - CameraRenderDelegate Delegate
- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer isFront:(BOOL)isFront{
    if(!CMSampleBufferGetImageBuffer(sampleBuffer))
        return;
    
    CFRetain(sampleBuffer); 
    runAsynchronouslyOnVideoProcessingQueue(^{
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        int pixelWidth  = (int)CVPixelBufferGetWidth(pixelBuffer);
        int pixelHeight = (int)CVPixelBufferGetHeight(pixelBuffer);

        if(self.imageBufferWidth != pixelWidth || self.imageBufferHeight != pixelHeight){
            Loggerinfo(@"pixel size changed!");
            self.imageBufferWidth  = pixelWidth;
            self.imageBufferHeight = pixelHeight;
            self.mixFrameBuffer = nil;
        }
        
        /// 切换上下文
        [self switch2DyGLContext];
        
        /// yuv 转 rgb texture
        GLuint textureId = [self converYUV2RGBTextureID:pixelBuffer
                                             pixelWidth:pixelWidth
                                            pixelHeight:pixelHeight];
        
        [self generateMixTextureId:textureId isFront:isFront currentTime:currentTime];
    
        CFRelease(sampleBuffer);
    });
}

-(void)generateMixTextureId:(GLuint)textureId isFront:(bool)isFront currentTime:(CMTime)currentTime{
    /**
     *  1. 切换GPUImage上下文
     *  2. 编译GLProgram，链接各个属性
     *  3. 初始化 FBO
     *  4. 设置激活 GLProgram
     *  5. 设置激活 GPUFrameBuffer
     */
    [self compileMixGLProgram];
    [GPUImageContext setActiveShaderProgram:self.mixProgram];
    
    [self setupMixFrameBuffer];
    [self.mixFrameBuffer activateFramebuffer];
    
    if(isFront && textureId != 0){
        if(_finishBack == 1 && _finishFront == 0){
            glActiveTexture(GL_TEXTURE2);
            glBindTexture(GL_TEXTURE_2D, textureId);
            glUniform1i(_filterInputTextureUniform, 2);
            glVertexAttribPointer(_positionAttribute, 2, GL_FLOAT, 0, 0, _secondVertics);
            glVertexAttribPointer(_textureCoordinateAttribute, 2, GL_FLOAT, 0, 0, _secondCoordinates);
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

            INTEGRATION_CHECK_GL_ERROR
            _finishFront= 1;
        }
    }else{
        /// 后置摄像头
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, textureId);
        glUniform1i(_filterInputTextureUniform, 2);
        glVertexAttribPointer(_positionAttribute, 2, GL_FLOAT, 0, 0, _firstVertics);
        glVertexAttribPointer(_textureCoordinateAttribute, 2, GL_FLOAT, 0, 0, _firstCoordinates);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        
        INTEGRATION_CHECK_GL_ERROR
        _finishBack  = 1;
        _finishFront = 0;
    }

    if(_finishBack && _finishFront){
        _finishBack  = 0;
        _finishFront = 0;
        
        [self renderWithoutEffects:currentTime];
    }
}

-(void)setupMixFrameBuffer{
    if(self.mixFrameBuffer == nil){
        self->_mixFrameBuffer = [[GPUImageContext sharedFramebufferCache]
                                 fetchFramebufferForSize:CGSizeMake(self.imageBufferWidth, self.imageBufferHeight)
                                 textureOptions:self.outputTextureOptions
                                 onlyTexture:NO];
        [self->_mixFrameBuffer lock];
        Loggerinfo(@"setup MixFrameBuffer init success");
    }
}

/// 直接上屏
- (void)renderWithoutEffects:(CMTime)currentTime{
    id<GPUImageInput> currentTarget = self.previewView;
    [currentTarget setInputRotation:kGPUImageNoRotation atIndex:0];
    [currentTarget setInputSize:CGSizeMake(self.imageBufferWidth, self.imageBufferHeight) atIndex:0];
    [currentTarget setInputFramebuffer:self.mixFrameBuffer atIndex:0];
//    [currentTarget setInputFramebuffer:self.rgbOffscreenBuffer atIndex:0];
    [currentTarget newFrameReadyAtTime:currentTime atIndex:0];
}

@end
