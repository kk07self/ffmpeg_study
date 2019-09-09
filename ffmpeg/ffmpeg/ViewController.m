//
//  ViewController.m
//  ffmpeg
//
//  Created by K K on 2019/8/20.
//  Copyright © 2019 K K. All rights reserved.
//

#import "ViewController.h"
#include <libavutil/avassert.h>
#include <libavutil/channel_layout.h>
#include <libavutil/opt.h>
#include <libavutil/mathematics.h>
#include <libavutil/timestamp.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>

#import "GPUImage.h"

#import "Decodec.h"

#define Base_TB (AVRational){1, 30}


@interface ViewController ()

/** decodec */
@property (nonatomic, strong) Decodec *decodec;

/** 是否在播放 */
@property (nonatomic, assign) BOOL isplaying;

/** prelayer */
@property (nonatomic, strong) CALayer *previewLayer;

/** context */
@property (nonatomic, strong) CIContext *context;

/* desc */
@property (nonatomic, strong) dispatch_source_t timer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"MP4"];
    _decodec = [[Decodec alloc] initWithFilePath:filePath options:[[DecodeOptions alloc] init]];
    
    self.view.backgroundColor = [UIColor redColor];
    self.previewLayer.contentsGravity = kCAGravityResizeAspect;
    [self.view.layer insertSublayer:_previewLayer atIndex:0];
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    _isplaying = !_isplaying;
    if (_isplaying) {
        [self play];
    }
}

- (void)play {
    dispatch_source_set_event_handler(self.timer, ^{
        NSLog(@"----isplaying");
        CVPixelBufferRef pixelBuffer = [self.decodec getPixelBuffer];
        if (pixelBuffer) {
            CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
            dispatch_async(dispatch_get_main_queue(), ^{
                CGImageRef cgImage = [self.context createCGImage:ciImage fromRect:ciImage.extent];
                self.previewLayer.contents = (__bridge id _Nullable)cgImage;
                CFRelease(cgImage);
            });
        }
    });
    dispatch_resume(_timer);
}


- (CALayer *)previewLayer {
    if (_previewLayer == nil) {
        _previewLayer = [[CALayer alloc] init];
        _previewLayer.bounds = self.view.bounds;
        _previewLayer.anchorPoint = CGPointMake(0, 0);
    }
    return _previewLayer;
}

- (CIContext *)context {
    if (_context == nil) {
        EAGLContext *eagl = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        _context = [CIContext contextWithEAGLContext:eagl options:@{kCIContextWorkingColorSpace:[NSNull null]}];
    }
    return _context;
}

- (dispatch_source_t)timer {
    if (!_timer) {
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, 25*NSEC_PER_MSEC, 0);
    }
    return _timer;
}

@end
