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
#include "libswscale/swscale.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - VideoFrame 格式化帧数据
typedef enum {
        
    VideoFrameFormatRGB,
    VideoFrameFormatYUV,
    
} VideoFrameFormat;


/// 帧数据基类
@interface VideoFrame : NSObject

@property (readonly, nonatomic) VideoFrameFormat format;
@property (readonly, nonatomic) NSUInteger width;
@property (readonly, nonatomic) NSUInteger height;

@end


/// 帧数据RGB格式
@interface VideoFrameRGB : VideoFrame
@property (readonly, nonatomic) NSUInteger linesize;
@property (readonly, nonatomic, strong) NSData *rgb;
@end


/// 帧数据YUV格式
@interface VideoFrameYUV : VideoFrame
@property (readonly, nonatomic, strong) NSData *luma;
@property (readonly, nonatomic, strong) NSData *chromaB;
@property (readonly, nonatomic, strong) NSData *chromaR;
@end


#pragma mark - VideoDecodec 视频解码器
@class VideoDecodec;
@protocol VideoDecodecDelegate <NSObject>

- (void)videoDecodec:(VideoDecodec *)videoDecodec getVideoSampleBuffer:(CMSampleBufferRef)samplebuffer;

- (void)videoDecodec:(VideoDecodec *)videoDecodec getVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end


@interface VideoDecodec : NSObject

/* delegate */
@property (nonatomic, weak) id<VideoDecodecDelegate> delegate;

- (instancetype)initWithFormatContext:(AVFormatContext *)formatContext videoStreamIndex:(int)videoStreamIndex;

- (VideoFrame *)decodecPacket:(AVPacket)packet;

@end

NS_ASSUME_NONNULL_END
