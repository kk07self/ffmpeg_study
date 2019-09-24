//
//  VideoDecodec.m
//  ffmpeg
//
//  Created by K K on 2019/9/6.
//  Copyright © 2019 K K. All rights reserved.
//

#import "VideoDecodec.h"
#import "CodecErrorCode.h"

#pragma mark - C Function

// 创建硬件解码器
AVBufferRef *hw_device_ctx = NULL;
static int init_hardware_decoder(AVCodecContext *ctx, const enum AVHWDeviceType type) {
    int err = av_hwdevice_ctx_create(&hw_device_ctx, type, NULL, NULL, 0);
    if (err < 0) {
//        log4cplus_error("XDXParseParse", "Failed to create specified HW device.\n");
        return err;
    }
    ctx->hw_device_ctx = av_buffer_ref(hw_device_ctx);
    return err;
}

// copy 数据
static NSData * copyFrameData(UInt8 *src, int linesize, int width, int height)
{
    width = MIN(linesize, width);
    NSMutableData *md = [NSMutableData dataWithLength: width * height];
    Byte *dst = md.mutableBytes;
    for (NSUInteger i = 0; i < height; ++i) {
        memcpy(dst, src, width);
        dst += width;
        src += linesize;
    }
    return md;
}


#pragma mark - VideoFrame 帧数据格式化
/// 帧数据基类
@interface VideoFrame()
@property (readwrite, nonatomic) VideoFrameFormat format;
@property (readwrite, nonatomic) NSUInteger width;
@property (readwrite, nonatomic) NSUInteger height;
@end
@implementation VideoFrame
@end

/// 帧数据RGB格式
@interface VideoFrameRGB()
@property (readwrite, nonatomic) NSUInteger linesize;
@property (readwrite, nonatomic, strong) NSData *rgb;
@end
@implementation VideoFrameRGB
@end

/// 帧数据YUV格式
@interface VideoFrameYUV()
@property (readwrite, nonatomic, strong) NSData *luma;
@property (readwrite, nonatomic, strong) NSData *chromaB;
@property (readwrite, nonatomic, strong) NSData *chromaR;
@end
@implementation VideoFrameYUV

- (void)dealloc {
    NSLog(@"dealloc: %@", self);
}

@end


#pragma mark - VideoDecodec 视频解码器
@interface VideoDecodec()

{
    uint64_t base_time;
    BOOL isFindIDR;
}

/** format context */
@property (nonatomic, assign) AVFormatContext *formatContext;

/** decodec context */
@property (nonatomic, assign) AVCodecContext *videoDecodecContext;

/** AVFrame */
@property (nonatomic, assign) AVFrame *videoFrame;

/** video stream index */
@property (nonatomic, assign) int videoStreamIndex;

/* 帧格式转换器 */
@property (nonatomic, assign) struct SwsContext *swsContext;

/* 帧格式转换桥接数据 */
@property (nonatomic, assign) AVPicture picture;

/* frameFormat */
@property (nonatomic, assign) VideoFrameFormat videoFrameFormat;

@end


@implementation VideoDecodec

#pragma mark - lifyCycle
- (instancetype)initWithFormatContext:(AVFormatContext *)formatContext videoStreamIndex:(int)videoStreamIndex; {
    if (self = [super init]) {
        _formatContext = formatContext;
        _videoStreamIndex = videoStreamIndex;
        _videoFrameFormat = VideoFrameFormatYUV;
        [self initDecodec];
    }
    return self;
}

// 初始化解码器
- (void)initDecodec {
    AVStream *videoStream = _formatContext->streams[_videoStreamIndex];
    // 创建解码器上下文、解码器
    _videoDecodecContext = [self createVideoDecodecContextWithStream:videoStream];
    if (!_videoDecodecContext) {
        NSLog(@"create video codec faild --- code: %ld",CodecErrorCodeVideoCreatDecodecContextError);
        return;
    }
    
    // 创建视频帧
    _videoFrame = av_frame_alloc();
    if (!_videoFrame) {
        NSLog(@"alloc video frame failed --- code: %ld", CodecErrorCodeVideoFrameAllocError);
        avcodec_close(_videoDecodecContext);
    }
}


// 创建解码器上下文
- (AVCodecContext *)createVideoDecodecContextWithStream:(AVStream *)stream {
    
    AVCodecContext *codecContext = NULL;
    AVCodec *codec = NULL;
    int ret = 0;
    // 硬件解码器
//    const char *codecName = av_hwdevice_get_type_name(AV_HWDEVICE_TYPE_VIDEOTOOLBOX);
//    enum AVHWDeviceType type = av_hwdevice_find_type_by_name(codecName);
//    if (type != AV_HWDEVICE_TYPE_VIDEOTOOLBOX) {
//        NSLog(@"not found videotoolbox --- code: %ld", CodecErrorCodeVideoNotFoundHardWare);
//        return NULL;
//    }
//
//    // 查找最好留解码器
//    ret = av_find_best_stream(_formatContext, AVMEDIA_TYPE_VIDEO, -1, -1, &codec, 0);
//    if (ret < 0) {
//        NSLog(@"av_find_best_stream faild --- code: %ld", CodecErrorCodeVideoNotFoundBestStream);
//        return NULL;
//    }
    
    codec = avcodec_find_decoder(stream->codecpar->codec_id);
    // 用解码器初始化解码器上下文
    codecContext = avcodec_alloc_context3(codec);
    if (!codecContext){
        NSLog(@"avcodec_alloc_context3 faild --- code: %ld", CodecErrorCodeVideoAllocError);
        return NULL;
    }
    
    // 将解码器流信息转给上下文
    ret = avcodec_parameters_to_context(codecContext, _formatContext->streams[_videoStreamIndex]->codecpar);
    if (ret < 0){
        NSLog(@"avcodec_parameters_to_context faild --- code: %ld", CodecErrorCodeVideoCodecParametersToContextError);
        return NULL;
    }
    
    // 初始化硬解码器
//    ret = init_hardware_decoder(codecContext, type);
//    if (ret < 0){
//        NSLog(@"hard ware decoder init faild --- code: %ld", CodecErrorCodeVideoHardWareDecoderInitError);
//        return NULL;
//    }
    
    // 开启硬解码器
    ret = avcodec_open2(codecContext, codec, NULL);
    if (ret < 0) {
        NSLog(@"avcodec_open2 faild --- code: %ld", CodecErrorCodeVideoDecoderOpenError);
        return NULL;
    }
    
    // 返回硬解码上下文
    return codecContext;
}


- (void)setupSwsContext {
    BOOL success = avpicture_alloc(&_picture, AV_PIX_FMT_RGBA, _videoDecodecContext->width, _videoDecodecContext->height) == 0;
    if (success == NO) {
        return;
    }
    if (_swsContext == NULL) {
        _swsContext = sws_getCachedContext(_swsContext,
        _videoDecodecContext->width,
        _videoDecodecContext->height,
        _videoDecodecContext->pix_fmt,
        _videoDecodecContext->width,
        _videoDecodecContext->height,
        AV_PIX_FMT_RGBA,
        SWS_FAST_BILINEAR,
        NULL, NULL, NULL);
    }
}

#pragma mark - decodec

- (VideoFrame *)decodecPacket:(AVPacket)packet; {
    
    if (packet.flags == 1 && isFindIDR == NO) {
        isFindIDR = YES;
        base_time = _videoFrame->pts;
    }
    
    Float64 current_timestamp = [self getCurrentTimestamp];
    AVStream *videoStream = _formatContext->streams[_videoStreamIndex];
    int fps = get_avstream_fps_timeBase(videoStream);
    
    // 发送解码j前数据
    avcodec_send_packet(_videoDecodecContext, &packet);
    // 接收解码器后的数据
    while (0 == avcodec_receive_frame(_videoDecodecContext, _videoFrame))
    {
        VideoFrame *frame;
        if (_videoFrameFormat == VideoFrameFormatYUV) {
            // 转YUV
            VideoFrameYUV *yuvFrame = [[VideoFrameYUV alloc] init];
            yuvFrame.luma = copyFrameData(_videoFrame->data[0], _videoFrame->linesize[0], _videoDecodecContext->width, _videoDecodecContext->height);
            yuvFrame.chromaB = copyFrameData(_videoFrame->data[1], _videoFrame->linesize[1], _videoDecodecContext->width/2, _videoDecodecContext->height/2);
            yuvFrame.chromaR = copyFrameData(_videoFrame->data[2], _videoFrame->linesize[2], _videoDecodecContext->width/2, _videoDecodecContext->height/2);
            frame = yuvFrame;
        } else {
            // 转RGB
//            if (_swsContext == NULL) {
//                [self setupSwsContext];
//            }
//            VideoFrameRGB *rgbFrame = [[VideoFrameRGB alloc] init];
////            AVFrame newframe;
//            sws_scale(_swsContext, (const uint8_t **)_videoFrame->data, _videoFrame->linesize, 0, _videoDecodecContext->height,
//            _picture.data,
//            _picture.linesize);
//            rgbFrame.linesize = _picture.linesize[0];
//            rgbFrame.rgb = [NSData dataWithBytes:_picture.data[0] length:rgbFrame.linesize*_videoDecodecContext->height];
//            frame = rgbFrame;
        }
        frame.format = _videoFrameFormat;
        frame.width = _videoFrame->width;
        frame.height = _videoFrame->height;
        return frame;
        
        CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)_videoFrame->data[3];
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoDecodec:getVideoPixelBuffer:)]) {
            [self.delegate videoDecodec:self getVideoPixelBuffer:pixelBuffer];
            return nil;
        }
        CMTime presentationTimeStamp = kCMTimeInvalid;
        int64_t originPTS = _videoFrame->pts;
        int64_t newPTS    = originPTS - base_time;
        presentationTimeStamp = CMTimeMakeWithSeconds(current_timestamp + newPTS * av_q2d(videoStream->time_base) , fps);
        CMSampleBufferRef sampleBufferRef = [self convertCVImageBufferRefToCMSampleBufferRef:(CVPixelBufferRef)pixelBuffer
                                                                   withPresentationTimeStamp:presentationTimeStamp];

        if (sampleBufferRef) {
            if ([self.delegate respondsToSelector:@selector(videoDecodec:getVideoSampleBuffer:)]) {
                [self.delegate videoDecodec:self getVideoSampleBuffer:sampleBufferRef];
            }

            CFRelease(sampleBufferRef);
        }
    }
    return NULL;
}



- (CMSampleBufferRef)convertCVImageBufferRefToCMSampleBufferRef:(CVImageBufferRef)pixelBuffer withPresentationTimeStamp:(CMTime)presentationTimeStamp
{
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    CMSampleBufferRef newSampleBuffer = NULL;
    OSStatus res = 0;
    
    CMSampleTimingInfo timingInfo;
    timingInfo.duration              = kCMTimeInvalid;
    timingInfo.decodeTimeStamp       = presentationTimeStamp;
    timingInfo.presentationTimeStamp = presentationTimeStamp;
    
    CMVideoFormatDescriptionRef videoInfo = NULL;
    res = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
    if (res != 0) {
        NSLog(@"Create video format description failed --- code: %ld", CodeErrorCodeVideoDecodeCreateVideoFormatError);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return NULL;
    }
    
    res = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                             pixelBuffer,
                                             true,
                                             NULL,
                                             NULL,
                                             videoInfo,
                                             &timingInfo, &newSampleBuffer);
    
    CFRelease(videoInfo);
    if (res != 0) {
        NSLog(@"Create sample buffer failed --- code: %ld", CodeErrorCodeVideoDecodeCreateSampleBufferError);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return NULL;
        
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    return newSampleBuffer;
}

- (Float64)getCurrentTimestamp {
    CMClockRef hostClockRef = CMClockGetHostTimeClock();
    CMTime hostTime = CMClockGetTime(hostClockRef);
    return CMTimeGetSeconds(hostTime);
}

- (struct SwsContext *)swsContext {
    if (_swsContext == NULL) {
        _swsContext = sws_getCachedContext(_swsContext,
        _videoDecodecContext->width,
        _videoDecodecContext->height,
        _videoDecodecContext->pix_fmt,
        _videoDecodecContext->width,
        _videoDecodecContext->height,
        AV_PIX_FMT_RGBA,
        SWS_FAST_BILINEAR,
        NULL, NULL, NULL);
    }
    return _swsContext;
}


@end
