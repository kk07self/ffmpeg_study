//
//  DemuxMedia.m
//  ffmpeg
//
//  Created by K K on 2019/9/6.
//  Copyright © 2019 K K. All rights reserved.
//

#import "DemuxMedia.h"
#import "CodecErrorCode.h"

static const int kCodecSupportMaxFps     = 60;
static const int kCodecFpsOffSet         = 5;
static const int kCodecWidth1920         = 1920;
static const int kCodecHeight1080        = 1080;
static const int kCodecSupportMaxWidth   = 3840;
static const int kCodecSupportMaxHeight  = 2160;


@interface DemuxMedia()
{
    int _video_stream_index;
    int _audio_stream_index;
    
    // video
    int _video_width, _video_height, _video_fps;
    
    dispatch_queue_t _demuxQueue;
}

@end

@implementation DemuxMedia

//+ (void)initialize {
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        av_register_all();
//    });
//}

- (instancetype)initWithFilePath:(NSString *)filePath {
    if (self = [super init]) {
        [self preparFormatContext:filePath];
//        [self preparVideoStreams];
//        [self preparAudioStreams];
        _demuxQueue = dispatch_queue_create("parse_queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

// formatContext
- (void)preparFormatContext:(NSString *)filePath {
    if (filePath == NULL || filePath.length == 0) {
        NSLog(@" file is null --- code: %ld", CodecErrorCodeNullFilePath);
        return;
    }
    
    AVFormatContext  *formatContext = NULL;
    AVDictionary     *opts          = NULL;
    
    av_dict_set(&opts, "timeout", "3000000", 0);//设置超时1秒
    formatContext = avformat_alloc_context();
    const char *in_filename = [filePath cStringUsingEncoding:NSASCIIStringEncoding];
    BOOL isSuccess = avformat_open_input(&formatContext, in_filename, NULL, &opts) < 0 ? NO : YES;
    av_dict_free(&opts);
    if (!isSuccess) {
        if (formatContext) {
            avformat_free_context(formatContext);
        }
        NSLog(@" formatContext create error --- code: %ld", CodecErrorCodeFormatContextNotInit);
        return;
    }
    
    if (avformat_find_stream_info(formatContext, NULL) < 0) {
        avformat_close_input(&formatContext);
        NSLog(@" find stream null --- code: %ld", CodecErrorCodeStreamNotFind);
        return;
    }
    av_dump_format(formatContext, 0, in_filename, 0);
    _formatContext = formatContext;
    
    for (int i = 0; i < formatContext->nb_streams; i++) {
        AVStream *in_stream = formatContext->streams[i];
        AVCodecParameters *in_codecpar = in_stream->codecpar;
        if(in_codecpar->codec_type == AVMEDIA_TYPE_VIDEO){
            _video_stream_index = i;
        }
        if(in_codecpar->codec_type == AVMEDIA_TYPE_AUDIO){
            _audio_stream_index = i;
        }
    }
    
}


#pragma mark - streams
// 准备视频流
- (void)preparVideoStreams {
    _video_stream_index = [self getStreamIndexWithStreamType:YES];
    if (_video_stream_index < 0) {
        return;
    }
    
    AVStream *videoStream = _formatContext->streams[_video_stream_index];
    _video_width  = videoStream->codecpar->width;
    _video_height = videoStream->codecpar->height;
    _video_fps    = get_avstream_fps_timeBase(videoStream);
    
    BOOL issupportVideoStream = [self isSupportVideoStream:videoStream];
    if (!issupportVideoStream) {
        NSLog(@"not support video stream --- code: %ld", CodecErrorCodeVideoStreamNotSupport);
    }
}

// 是否支持videostream
- (BOOL)isSupportVideoStream:(AVStream *)stream{
    if (stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {   // Video
        enum AVCodecID codecID = stream->codecpar->codec_id;
        NSLog(@"Current video codec format is %s", avcodec_find_decoder(codecID)->name);
        // 目前只支持H264、H265(HEVC iOS11)编码格式的视频文件
        if ((codecID != AV_CODEC_ID_H264 && codecID != AV_CODEC_ID_HEVC) || (codecID == AV_CODEC_ID_HEVC && [[UIDevice currentDevice].systemVersion floatValue] < 11.0)) {
            NSLog(@"264 265 codec not support --- code: %ld", CodecErrorCode264265CodecNotSupport);
            return NO;
        }
        
        // iPhone 8以上机型支持有旋转角度的视频
        AVDictionaryEntry *tag = NULL;
        tag = av_dict_get(_formatContext->streams[_video_stream_index]->metadata, "rotate", tag, 0);
        if (tag != NULL) {
            int rotate = [[NSString stringWithFormat:@"%s",tag->value] intValue];
            if (rotate != 0 /* && >= iPhone 8P*/) {
//                log4cplus_error(kModuleName, "%s: Not support rotate for device ",__func__);
            }
        }
        
        /*
         各机型支持的最高分辨率和FPS组合:
         
         iPhone 6S: 60fps -> 720P
         30fps -> 4K
         
         iPhone 7P: 60fps -> 1080p
         30fps -> 4K
         
         iPhone 8: 60fps -> 1080p
         30fps -> 4K
         
         iPhone 8P: 60fps -> 1080p
         30fps -> 4K
         
         iPhone X: 60fps -> 1080p
         30fps -> 4K
         
         iPhone XS: 60fps -> 1080p
         30fps -> 4K
         */
        
        // 目前最高支持到60FPS
        if (_video_fps > kCodecSupportMaxFps + kCodecFpsOffSet) {
            // 目前支持的最高分辨率，但是可以丢帧
            NSLog(@"");
            return NO;
        }
        
        // 目前最高支持到3840*2160
        int max = MAX(_video_height, _video_width);
        if (max > kCodecSupportMaxWidth || _video_height * _video_width > kCodecSupportMaxWidth * kCodecSupportMaxHeight) {
            NSLog(@"resolution too much --- code: %ld", CodecErrorCodeResolutionNotSupport);
            return NO;
        }
        
        // 2k最大 60fps, 4k 最大30fps
//        // 60FPS -> 1080P
//        if (sourceFps > kXDXParseSupportMaxFps - kXDXParseFpsOffSet && (sourceWidth > kXDXParseWidth1920 || sourceHeight > kXDXParseHeight1080)) {
//            log4cplus_error(kModuleName, "%s: Not support the fps and resolution",__func__);
//            return NO;
//        }
//
//        // 30FPS -> 4K
//        if (sourceFps > kXDXParseSupportMaxFps / 2 + kXDXParseFpsOffSet && (sourceWidth >= kXDXParseSupportMaxWidth || sourceHeight >= kXDXParseSupportMaxHeight)) {
//            log4cplus_error(kModuleName, "%s: Not support the fps and resolution",__func__);
//            return NO;
//        }
        
        // 6S
        //        if ([[XDXAnywhereTool deviceModelName] isEqualToString:@"iPhone 6s"] && sourceFps > kXDXParseSupportMaxFps - kXDXParseFpsOffSet && (sourceWidth >= kXDXParseWidth1920  || sourceHeight >= kXDXParseHeight1080)) {
        //            log4cplus_error(kModuleName, "%s: Not support the fps and resolution",__func__);
        //            return NO;
        //        }
        return YES;
    } else {
        return NO;
    }
    
}

// 准备音频流
- (void)preparAudioStreams {
    _audio_stream_index = [self getStreamIndexWithStreamType:NO];
    if (_audio_stream_index < 0) {
        return;
    }
    
    AVStream *audioStream = _formatContext->streams[_audio_stream_index];
    BOOL issupportAudio = [self isSupportAudioStream:audioStream];
    if (!issupportAudio) {
        NSLog(@"not support video stream --- code: %ld", CodecErrorCodeAudioStreamNotSupport);
    }
}

- (BOOL)isSupportAudioStream:(AVStream *)stream {
    if (stream->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
        enum AVCodecID codecID = stream->codecpar->codec_id;
        NSLog(@"Current audio codec format is %s", avcodec_find_decoder(codecID)->name);
        // 本项目只支持AAC格式的音频
        if (codecID != AV_CODEC_ID_AAC) {
            NSLog(@"audio codec not support --- code: %ld", CodecErrorCodeAudioCodecNotSupport);
            return NO;
        }
        return YES;
    }else {
        return NO;
    }
}



- (int)getStreamIndexWithStreamType:(BOOL)isVideoStream {
    int avStreamIndex = -1;
    for (int i = 0; i < _formatContext->nb_streams; i++) {
        if ((isVideoStream ? AVMEDIA_TYPE_VIDEO : AVMEDIA_TYPE_AUDIO) == _formatContext->streams[i]->codecpar->codec_type) {
            avStreamIndex = i;
        }
    }
    
    if (avStreamIndex == -1) {
        NSLog(@"%@ stream not find --- code: %ld", (isVideoStream ? @"video" : @"audio"), (isVideoStream ? CodecErrorCodeVideoStreamNotFind : CodecErrorCodeAudioStreamNotFind));
        return -1;
    } else {
        return avStreamIndex;
    }
}

#pragma mark - demux

- (void)readPacket:(void (^)(BOOL, BOOL, AVPacket))handler {
    dispatch_async(_demuxQueue, ^{
        AVPacket packet;
        av_init_packet(&packet);
        int status = av_read_frame(self.formatContext, &packet);
//        NSLog(@"video_stream_index:%d\n audio_stream_index:%d\npacke_stream_index:%d", _video_stream_index, _audio_stream_index, packet.stream_index);
//        NSLog(@"----------------------------------------------");
        if (status < 0 || packet.size < 0) {
            // release
            if (handler) {
                handler(NO, YES, packet);
            }
            return ;
        }
        if (handler) {
            handler(packet.stream_index == self->_video_stream_index ? YES : NO, NO, packet);
        }
        av_packet_unref(&packet);
    });
}


- (int)getVideoStreamIndex; {
    return _video_stream_index;
}

/**
 销毁信息
 */
- (void)destory {
    
}

@end
