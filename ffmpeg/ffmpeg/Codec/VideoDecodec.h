//
//  VideoDecodec.h
//  ffmpeg
//
//  Created by K K on 2019/9/6.
//  Copyright © 2019 K K. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#include "libavformat/avformat.h"

NS_ASSUME_NONNULL_BEGIN

@class VideoDecodec;
@protocol VideoDecodecDelegate <NSObject>

- (void)videoDecodec:(VideoDecodec *)videoDecodec getVideoSampleBuffer:(CMSampleBufferRef)samplebuffer;

- (void)videoDecodec:(VideoDecodec *)videoDecodec getVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end


@interface VideoDecodec : NSObject

/* delegate */
@property (nonatomic, weak) id<VideoDecodecDelegate> delegate;

- (instancetype)initWithFormatContext:(AVFormatContext *)formatContext videoStreamIndex:(int)videoStreamIndex;

- (CVPixelBufferRef)decodecPacket:(AVPacket)packet;

@end

NS_ASSUME_NONNULL_END
