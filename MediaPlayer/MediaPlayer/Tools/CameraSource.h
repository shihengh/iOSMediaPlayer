//
//  CameraSource.h
//  MediaPlayer
//
//  Created by shimo-imac on 2023/1/20.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "BaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface CameraSource : NSObject

-(instancetype)initWithDelegate:(BOOL)isFront renderView:(BaseViewController*)renderView;

-(void)startCaptureVideo;

-(void )stopCaptureVideo;

@end

NS_ASSUME_NONNULL_END
