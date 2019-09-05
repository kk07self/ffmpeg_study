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


#define Base_TB (AVRational){1, 30}


// 打印frame数据
static void log_packet1(AVRational *time_base, const AVFrame *pkt, const char *tag)
{
    printf("%s: pts:%s pts_time:%s dts:%s dts_time:%s duration:%s duration_time:%s\n",
           tag,
           av_ts2str(pkt->pts), av_ts2timestr(pkt->pts, time_base),
           av_ts2str(pkt->pkt_dts), av_ts2timestr(pkt->pkt_dts, time_base),
           av_ts2str(pkt->pkt_duration), av_ts2timestr(pkt->pkt_duration, time_base));
    
}

// 拷贝数据
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


@interface ViewController ()

/* 格式上下文 */
@property (nonatomic, assign) AVFormatContext *in_format_context;

/* 视频流下标 */
@property (nonatomic, assign) NSInteger v_stream_index;

/* 音频流下标 */
@property (nonatomic, assign) NSInteger a_stream_index;

/* 视频解码器 */
@property (nonatomic, assign) AVCodec *vdecodec;

/* 视频解码器上下文 */
@property (nonatomic, assign) AVCodecContext *vdecodec_context;

/* 视频解码frame */
@property (nonatomic, assign) AVFrame *vde_frame;

/* 音频解码器 */
@property (nonatomic, assign) AVCodec *adecodec;

/* 音频解码器上下文 */
@property (nonatomic, assign) AVCodecContext *adecodec_context;

/* 音频解码frame */
@property (nonatomic, assign) AVFrame *ade_frame;

/**
 预览视图
 */
@property (nonatomic, strong) GPUImageView *filterView;

/* rawDataInput */
@property (nonatomic, strong) GPUImageRawDataInput *rawDataInput;


/* 是否正在播放 */
@property (nonatomic, assign) BOOL isplaying;


/* file */
@property (nonatomic, strong) NSFileHandle *fileHandel;

/** scale */
@property (nonatomic, assign) struct SwsContext *swsContext;

/** picture */
@property (nonatomic, assign) AVPicture picture;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _filterView = [[GPUImageView alloc] initWithFrame:self.view.frame];
    [self.view insertSubview:_filterView atIndex:0];

    NSString *file = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"MP4"];
    [self createFormatContextWith:file];
}

- (void)dealloc {
    NSLog(@"--- dealloc");
    [self closeFile];
}

- (void) closeFile {
    
    if (_vde_frame) {
        av_free(_vde_frame);
        _vde_frame = NULL;
    }
    _vdecodec_context = nil;
    
    if (_ade_frame) {
        av_free(_ade_frame);
        _ade_frame = NULL;
    }
    if (_in_format_context) {
        
        _in_format_context->interrupt_callback.opaque = NULL;
        _in_format_context->interrupt_callback.callback = NULL;
        
        avformat_close_input(&_in_format_context);
        _in_format_context = NULL;
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    _isplaying = !_isplaying;
    if (_isplaying) {
        // 播放
        [self player];
    }
}

- (void)player {
    [self readFrame];
}


// 通过文件路径，创建格式上下文
- (void)createFormatContextWith:(NSString *)filepath {

    // check 视频地址是否有效
    if (filepath == nil || filepath.length <= 0) {
        NSLog(@"输入的视频地址无效");
        return;
    }

    // format_context 创建
    const char *in_file_name = [filepath cStringUsingEncoding:NSASCIIStringEncoding];
    int status = avformat_open_input(&_in_format_context, in_file_name, 0, 0);
    if (status < 0) {
        NSLog(@"open input file error:%d", status);
        return;
    }

    // 打印format_context信息
    av_dump_format(_in_format_context, 0, in_file_name, 0);

    // stream 查看
    status = avformat_find_stream_info(_in_format_context, 0);
    if (status < 0) {
        NSLog(@"null streams:%d", status);
        return;
    }

    // 获取streams
    NSMutableArray *v_streams = [NSMutableArray array];
    NSMutableArray *a_streams = [NSMutableArray array];
    for (NSInteger i = 0; i < _in_format_context->nb_streams; i++) {
        AVStream *stream = _in_format_context->streams[i];
        if (stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            // 视频流
            [v_streams addObject:[NSNumber numberWithInteger:i]];
            _v_stream_index = i;
        } else if (stream->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            // 音频流
            [a_streams addObject:[NSNumber numberWithInteger:i]];
            _a_stream_index = i;
        }
    }

    // 开启视频解码器
    [self open_video_decoder];

    // 开启音频解码器
    [self open_video_decoder];
}


// 打开视频解码器
- (void)open_video_decoder {

    // 解码器
    if (!_vdecodec) {
//        AVStream *stream = _in_format_context->streams[_v_stream_index];
        _vdecodec = avcodec_find_decoder(AV_CODEC_ID_H264);
        if (!_vdecodec) {
            NSLog(@"find decoder error");
            return;
        }
    }

    // 解码器上下文
    if (!_vdecodec_context) {
        _vdecodec_context = avcodec_alloc_context3(_vdecodec);
        if (!_vdecodec_context) {
            NSLog(@"alloc vdecodec context error");
            return;
        }
    }

    // 解码器参数配置
    AVStream *stream = _in_format_context->streams[_v_stream_index];
    
//    _vdecodec_context->extradata_size = stream->codecpar->extradata_size;
//    _vdecodec_context->extradata = malloc(_vdecodec_context->extradata_size);
//    memcpy(_vdecodec_context->extradata, stream->codecpar->extradata, _vdecodec_context->extradata_size);
    int status;
    status = avcodec_parameters_to_context(_vdecodec_context, stream->codecpar);
    if (status < 0) {
        NSLog(@"vdecodec context parameters error:%d", status);
        return;
    }
    _vdecodec_context->pix_fmt = AV_PIX_FMT_YUV420P;
//    _vdecodec_context->pix_fmt = AV_PIX_FMT_BGRA;
    _vdecodec_context->width = 540;
    _vdecodec_context->height = 960;
    _vdecodec_context->bit_rate = 5000*1000;
    
    // 打开解码器
    status = avcodec_open2(_vdecodec_context, _vdecodec, NULL);
    if (status < 0) {
        NSLog(@"vcodec open error:%d", status);
        return;
    }

    // 创建解码接受AVFrame
    if (_vde_frame) {
        _vde_frame = av_frame_alloc();
        if (!_vde_frame) {
            NSLog(@"vde_frame alloc error");
            return;
        }
    }
}


// 打开音频解码器
- (void)open_audio_decoder {
    NSLog(@" 音频先不做处理 ");
}


// 解封装
- (void)readFrame {
    int status;
    AVPacket pkt;
    while (_isplaying) {
        status = av_read_frame(_in_format_context, &pkt);
        if (status < 0) {
            break;
        }
        // 去解码
        if (pkt.stream_index == _v_stream_index) {
            // 视频解码
            [self decodec_video_packet:&pkt];
            // 写入file
//            [self writePacket:pkt];
//            _file
        }
        av_packet_unref(&pkt);
    }
    NSLog(@"--------完成");
}

- (void)writeData {
//    NSUInteger size = _vde_frame->linesize[0] + _vde_frame->linesize[1] + _vde_frame->linesize[2];
//    Byte *bytes = malloc(size);
//    memcpy(bytes, _vde_frame->data[0], _vde_frame->linesize[0]);
//    memcpy(bytes + _vde_frame->linesize[0], _vde_frame->data[1], _vde_frame->linesize[1]);
//    memcpy(bytes + _vde_frame->linesize[0] + _vde_frame->linesize[1], _vde_frame->data[2], _vde_frame->linesize[2]);
    
//    NSData *data1 = [NSData dataWithBytes:_vde_frame->data[0] length:_vde_frame->linesize[0]];
//    NSData *data2 = [NSData dataWithBytes:_vde_frame->data[1] length:_vde_frame->linesize[1]];
//    NSData *data3 = [NSData dataWithBytes:_vde_frame->data[2] length:_vde_frame->linesize[2]];
    NSData *data1 = copyFrameData(_vde_frame->data[0], _vde_frame->linesize[0], _vdecodec_context->width, _vdecodec_context->height);
    NSData *data2 = copyFrameData(_vde_frame->data[1], _vde_frame->linesize[1], _vdecodec_context->width/2, _vdecodec_context->height/2);
    NSData *data3 = copyFrameData(_vde_frame->data[2], _vde_frame->linesize[2], _vdecodec_context->width/2, _vdecodec_context->height/2);
    NSMutableData *all = [NSMutableData dataWithLength:data1.length + data2.length + data3.length];
    [all appendData:data1];
    [all appendData:data2];
    [all appendData:data3];
//    NSData *data = [NSData dataWithBytes:bytes length:size];
    [self.fileHandel writeData:all];
    [NSThread sleepForTimeInterval:0.01];
}

// 解码视频
- (void)decodec_video_packet:(AVPacket *)packet {
    
    if (!_vde_frame) {
        _vde_frame = av_frame_alloc();
        if (!_vde_frame) {
            NSLog(@" vde_frame alloc error");
            return;
        }
    }
    
    int status = -1;
    status = avcodec_send_packet(_vdecodec_context, packet);
    if (status < 0) {
        NSLog(@"vcodec_send_packet error: %d", status);
        return;
    }

    while (status >= 0) {
        status = avcodec_receive_frame(_vdecodec_context, _vde_frame);
        //解码成功，但是还没够frame返回，需要继续添加pkt
        if (status == AVERROR(EAGAIN) || status == AVERROR_EOF){
            if(status==AVERROR_EOF){
                NSLog(@"所有都解码完成，返回空告诉外界");
            }
            return ;
        }
        else if (status < 0) {
            fprintf(stderr, "Error during decoding\n");
            return ;
        }

        //修改解码后的参数，转换为我们常见的pts是0 1 2，ctb
        _vde_frame->pts = av_rescale_q(_vde_frame->pts, _in_format_context->streams[_v_stream_index]->time_base, Base_TB);
        _vde_frame->pkt_duration = av_rescale_q(_vde_frame->pkt_duration, _in_format_context->streams[_v_stream_index]->time_base, Base_TB);
        _vde_frame->pkt_dts = av_rescale_q(_vde_frame->pkt_dts, _in_format_context->streams[_v_stream_index]->time_base, Base_TB);

        //这里解码后的AVFrame
        log_packet1(&(Base_TB), _vde_frame, "vdecode");
        
        if (!_swsContext &&
            ![self setupScaler]) {
            NSLog(@"fail setup video scaler");
            return;
        }
        
        sws_scale(_swsContext,
                  (const uint8_t **)_vde_frame->data,
                  _vde_frame->linesize,
                  0,
                  _vdecodec_context->height,
                  _picture.data,
                  _picture.linesize);
        
        
        [self decodec_video_successed:_picture];
//        [self writeData];
    }
}

- (BOOL)setupScaler {
    int status = avpicture_alloc(&_picture,
                                    AV_PIX_FMT_RGBA,
                                    _vdecodec_context->width,
                                    _vdecodec_context->height) == 0;
    
    if (status < 0)
        return NO;
    
    _swsContext = sws_getCachedContext(_swsContext,
                                       _vdecodec_context->width,
                                       _vdecodec_context->height,
                                       _vdecodec_context->pix_fmt,
                                       _vdecodec_context->width,
                                       _vdecodec_context->height,
                                       AV_PIX_FMT_RGBA,
                                       SWS_FAST_BILINEAR,
                                       NULL, NULL, NULL);
    
    return _swsContext != NULL;
}

// 解码成功回调
- (void)decodec_video_successed:(AVPicture)picture {
    AVStream *stream = self.in_format_context->streams[_v_stream_index];
    CGSize size = CGSizeMake(stream->codecpar->width, stream->codecpar->height);
    if (!_rawDataInput) {
        _rawDataInput = [[GPUImageRawDataInput alloc] initWithBytes:(GLubyte *)(picture.data[0]) size:size];
        [_rawDataInput addTarget:_filterView];
    } else {
        [_rawDataInput updateDataFromBytes:(GLubyte *)(picture.data[0]) size:size];
    }
    [_rawDataInput processData];
    [NSThread sleepForTimeInterval:0.03];
}

// 解码音频
- (void)decodec_audio_packet:(AVPacket *)packet {

}



- (NSFileHandle *)fileHandel {
    if (!_fileHandel) {
//        NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
//        NSString *filePath = [cachePath stringByAppendingPathComponent:[NSString stringWithFormat:@"com-%ld.yuv", (NSInteger)[[NSDate date] timeIntervalSince1970]]];
        NSString *filePath = @"/Users/kk/Desktop/com.yuv";
//        if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
//            [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes: nil];
//        }
        _fileHandel = [NSFileHandle fileHandleForWritingAtPath:filePath];
    }
    return _fileHandel;
}

@end
