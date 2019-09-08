//
//  CodecErrorCode.h
//  ffmpeg
//
//  Created by K K on 2019/9/6.
//  Copyright © 2019 K K. All rights reserved.
//

#ifndef CodecErrorCode_h
#define CodecErrorCode_h

//#define 

typedef enum : NSInteger {
    // filepath
    CodecErrorCodeNullFilePath = 1000001,
    
    // 1001··· demux
    CodecErrorCodeFormatContextNotInit = 1001001,
    CodecErrorCodeStreamNotFind        = 1001002,
    CodecErrorCodeVideoStreamNotFind   = 1001003,
    CodecErrorCodeAudioStreamNotFind   = 1001003,
    CodecErrorCode264265CodecNotSupport   = 1001004,
    CodecErrorCodeResolutionNotSupport   = 1001005,
    CodecErrorCodeVideoStreamNotSupport   = 1001006,
    CodecErrorCodeAudioStreamNotSupport   = 1001007,
    CodecErrorCodeAudioCodecNotSupport   = 1001008,
    CodecErrorCodeGetPacketWithOutFormatConext   = 1001009,
    
    // 1002··· decode
    CodecErrorCodeVideoCreatDecodecContextError = 1002000,
    CodecErrorCodeVideoNotFoundHardWare  = 1002001,
    CodecErrorCodeVideoNotFoundBestStream = 1002002,
    CodecErrorCodeVideoAllocError = 1002003,
    CodecErrorCodeVideoCodecParametersToContextError = 1002004,
    CodecErrorCodeVideoHardWareDecoderInitError = 1002005,
    CodecErrorCodeVideoDecoderOpenError = 1002006,
    CodecErrorCodeVideoFrameAllocError = 1002007,
    
    // 1003··· videoDecode
    
} CodecErrorCode;



/**
 获取帧率

 @param st 流
 @return 帧率
 */
static int get_avstream_fps_timeBase(AVStream *st) {
    float fps, timebase = 0.0;
    
    if (st->time_base.den && st->time_base.num)
        timebase = av_q2d(st->time_base);
    //    else if(st->codecpar->time_base.den && st->codec->time_base.num)
    //        timebase = av_q2d(st->codec->time_base);
    
    if (st->avg_frame_rate.den && st->avg_frame_rate.num)
        fps = av_q2d(st->avg_frame_rate);
    else if (st->r_frame_rate.den && st->r_frame_rate.num)
        fps = av_q2d(st->r_frame_rate);
    else
        fps = 1.0 / timebase;
    
    return fps;
}
#endif /* CodecErrorCode_h */
