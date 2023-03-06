//
//  GLDefines.h
//  MediaPlayer
//
//  Created by shimo-imac on 2023/2/23.
//

#ifndef GLDefines_h
#define GLDefines_h

//日志扫屏
#define INTEGRATION_CHECK_GL_ERROR  {\
        static NSTimeInterval lastCheck = 0; \
        NSTimeInterval currentCheck = NSDate.date.timeIntervalSince1970; \
        if (currentCheck - lastCheck >= 0){ \
            lastCheck = currentCheck; \
            GLenum errorCode; \
            while ((errorCode = glGetError()) != GL_NO_ERROR) { \
                NSString *errMsg; \
                switch (errorCode) { \
                    case GL_INVALID_ENUM:                  errMsg = @"INVALID_ENUM"; break; \
                    case GL_INVALID_VALUE:                 errMsg = @"INVALID_VALUE"; break; \
                    case GL_INVALID_OPERATION:             errMsg = @"INVALID_OPERATION"; break; \
                    case GL_OUT_OF_MEMORY:                 errMsg = @"OUT_OF_MEMORY"; break; \
                    case GL_INVALID_FRAMEBUFFER_OPERATION: errMsg = @"INVALID_FRAMEBUFFER_OPERATION"; break; \
                    default: errMsg = @"unknown error%d"; break; \
                } \
                NSLog(@"CameraSource GLError [%d] errorcode=[%u] errMsg=[%@]", __LINE__, errorCode, errMsg); \
            } \
        } \
}

#define Loggerinfo(msg) NSLog(@"[%s:%d] %@", __FUNCTION__, __LINE__, msg);

#endif /* GLDefines_h */
