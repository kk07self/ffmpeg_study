//
//  Decodec.m
//  ffmpeg
//
//  Created by K K on 2019/9/6.
//  Copyright © 2019 K K. All rights reserved.
//

#import "Decodec.h"
#import "DemuxMedia.h"
#import "VideoDecodec.h"
#import "AudioDecodec.h"

#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"
#include "libavutil/avutil.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
#include "libavutil/opt.h"

@interface Decodec()

/** demux */
@property (nonatomic, strong) DemuxMedia *demux;

/** videoDecodec */
@property (nonatomic, strong) VideoDecodec *videoDecodec;

/** audioDecodec */
@property (nonatomic, strong) AudioDecodec *audioDecodec;


/** filePath */
@property (nonatomic, strong) NSString *filePath;

/** 缓存的帧数据 */
@property (nonatomic, strong) NSMutableArray *frames;

/** 是否播放完成 */
@property (nonatomic, assign) BOOL isFinished;

/** 信号量锁 */
@property (strong, nonatomic) dispatch_semaphore_t semaphore;

@end

@implementation Decodec

- (instancetype)initWithFilePath:(NSString *)filePath options:(DecodeOptions *)options; {
    if (self = [super init]) {
        _options = options;
        _filePath = filePath;
    }
    return self;
}


- (CVPixelBufferRef)getPixelBuffer {
    if (self.frames.count > 0) {
        if (self.frames.count < 5) {
            [self cachecPixelBuffer];
        }
        return [self pual];
    } else {
        [self cachecPixelBuffer];
        while (self.frames.count < 1 && !_isFinished) {
            // 睡眠等待缓存
            [NSThread sleepForTimeInterval:0.01];
        }
        return [self pual];
    }
}

#pragma mark - buffers manager
- (CVPixelBufferRef)pual {
    // 需要枷锁
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    CVPixelBufferRef pixbuffer = (__bridge CVPixelBufferRef)(self.frames.firstObject);
    [self.frames removeObject:(__bridge id _Nonnull)(pixbuffer)];
    // 解锁
    dispatch_semaphore_signal(self.semaphore);
    return pixbuffer;
}

- (void)cachecPixelBuffer {
    
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (self.frames.count < 5) {
            // 获取packect
            AVPacketResult *result = [self.demux getMediaoPacket];
            if (result.isNull) {
                self.isFinished = YES;
                return;
            }
            
            // 暂时只解码视频帧
            if (result.mediaType != AVMEDIA_TYPE_VIDEO) {
                return;
            }
            
            // 解码
            CVPixelBufferRef pixbuffer = [self.videoDecodec decodecPacket:result.packet];
            if (pixbuffer == NULL) {
                continue;
            }
            // 放到缓存中
            // 需要枷锁
            dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
            [self.frames addObject:(__bridge id _Nonnull)(pixbuffer)];
            // 解锁
            dispatch_semaphore_signal(self.semaphore);
        }
//    });
}


#pragma mark setter getter
- (DemuxMedia *)demux {
    if (!_demux) {
        _demux = [[DemuxMedia alloc] initWithFilePath:_filePath];
    }
    return _demux;
}

- (VideoDecodec *)videoDecodec {
    if (!_videoDecodec) {
        _videoDecodec = [[VideoDecodec alloc] initWithFormatContext:_demux.formatContext videoStreamIndex:[_demux getVideoStreamIndex]];
    }
    return _videoDecodec;
}


- (NSMutableArray *)frames {
    if (!_frames) {
        _frames = [NSMutableArray arrayWithCapacity:5];
    }
    return _frames;
}

- (dispatch_semaphore_t)semaphore {
    if (!_semaphore) {
        _semaphore = dispatch_semaphore_create(1);
    }
    return _semaphore;
}

@end
