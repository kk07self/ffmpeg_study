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

@interface VideoDecodec : NSObject

- (instancetype)initWithFormatContext:(AVFormatContext *)formatContext videoStreamIndex:(int)videoStreamIndex;

- (CVPixelBufferRef)decodecPacket:(AVPacket)packet;

@end

NS_ASSUME_NONNULL_END
