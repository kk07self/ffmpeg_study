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

/* 缓存队列 */
@property (nonatomic, strong) dispatch_queue_t cacheQueue;

/* 缓存的帧数据 */
@property (nonatomic, strong) NSMutableArray *cacheVideoFrames;

@end

@implementation Decodec

- (instancetype)initWithFilePath:(NSString *)filePath options:(DecodeOptions *)options; {
    if (self = [super init]) {
        _options = options;
        _filePath = filePath;
        _cacheQueue = dispatch_queue_create("_cacheQueue", DISPATCH_QUEUE_SERIAL);
        [self demux];
//        self.videoDecodec.delegate = self;
        [self videoDecodec];
    }
    return self;
}


//- (void)startDecode {
//    // 获取packect
//    [self.demux readPacket:^(BOOL isVideoPacket, BOOL isReadFinished, AVPacket packet) {
//        if (isReadFinished) {
//            return ;
//        }
//        if (isVideoPacket) {
//            // 解码
//            VideoFrame *frame = [self.videoDecodec decodecPacket:packet];
//            [self appendVideoFrame:frame];
//        }
//    }];
//}
//
//- (void)videoDecodec:(VideoDecodec *)videoDecodec getVideoSampleBuffer:(CMSampleBufferRef)samplebuffer {
//    if (self.delegate && [self.delegate respondsToSelector:@selector(decodecVide:samplebuffer:)]) {
//        [self.delegate decodecVide:self samplebuffer:samplebuffer];
//    }
//}
//
//- (void)videoDecodec:(VideoDecodec *)videoDecodec getVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer {
//    if (self.delegate && [self.delegate respondsToSelector:@selector(decodecVide:pixelbuffer:)]) {
//        [self.delegate decodecVide:self pixelbuffer:pixelBuffer];
//    }
//}

- (VideoFrame *)peekVideoFrame {
    AVPacket *packet = [self.demux readerPacket];
    // 没有数据了
    if (!packet) {
       self.isFinished = YES;
       return nil;
    }
    // 非视频帧
    if (packet->stream_index != [self.demux getVideoStreamIndex]) {
        return [self peekVideoFrame];
    }
    // 解码
    VideoFrame *frame = [self.videoDecodec decodecPacket:*packet];
    av_packet_unref(packet);
    if (!frame) {
        return [self peekVideoFrame];
    }
    return frame;
    
    VideoFrame *videoFrame;
    if (self.cacheVideoFrames.count > 0) {
        videoFrame = [self getVideoFrame];
        if (self.cacheVideoFrames.count < 5) {
            // 异步缓存
            [self asyncCacheVideoFrames];
        }
    } else {
        // 同步缓存
        if (self.isFinished) {
            return nil;
        }
        [self syncCacheVideoFrames];
        return [self peekVideoFrame];
//        while (1) {
//            [NSThread sleepForTimeInterval:0.01];
//            continue;
//        }
    }
    return videoFrame;
}


#pragma mark - video frames manager
- (void)appendVideoFrame:(VideoFrame *)videoFrame {
    if (videoFrame == nil) {
        return;
    }
    // 需要枷锁
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    [self.cacheVideoFrames addObject:videoFrame];
    NSLog(@"cacheVideoFrames count: %ld", self.cacheVideoFrames.count);
    // 解锁
    dispatch_semaphore_signal(self.semaphore);
}


- (VideoFrame *)getVideoFrame {
    // 需要枷锁
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    VideoFrame *frame = self.cacheVideoFrames.firstObject;
    if (frame) {
        [self.cacheVideoFrames removeObject:frame];
    }
    // 解锁
    dispatch_semaphore_signal(self.semaphore);
    return frame;
}

// 异步缓存
- (void)asyncCacheVideoFrames {
    dispatch_async(_cacheQueue, ^{
        [self currentQueueCacheVideoFrames];
    });
}

// 同步缓存
- (void)syncCacheVideoFrames {
    dispatch_sync(_cacheQueue, ^{
        [self currentQueueCacheVideoFrames];
    });
}

// 当前队列线程缓存
- (void)currentQueueCacheVideoFrames {
    __block NSInteger videoFramesCount = self.frames.count;
    while (videoFramesCount < 5) {
        // 获取packect
        __weak typeof(self) weakSelf = self;
        AVPacket *packet = [self.demux readerPacket];
        // 没有数据了
        if (!packet) {
            self.isFinished = YES;
            break;
        }
        // 非视频帧
        if (packet->stream_index != [self.demux getVideoStreamIndex]) {
            continue;
        }
        // 解码
        VideoFrame *frame = [weakSelf.videoDecodec decodecPacket:*packet];
        [weakSelf appendVideoFrame:frame];
        av_packet_unref(packet);
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        videoFramesCount = weakSelf.cacheVideoFrames.count;
        // 解锁
        dispatch_semaphore_signal(self.semaphore);
    }
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

- (NSMutableArray *)cacheVideoFrames {
    if (!_cacheVideoFrames) {
        _cacheVideoFrames = [NSMutableArray array];
    }
    return _cacheVideoFrames;
}

@end
