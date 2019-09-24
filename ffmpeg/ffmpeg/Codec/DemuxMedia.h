//
//  DemuxMedia.h
//  ffmpeg
//
//  Created by K K on 2019/9/6.
//  Copyright © 2019 K K. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "libavformat/avformat.h"

NS_ASSUME_NONNULL_BEGIN


@interface DemuxMedia : NSObject

- (instancetype)initWithFilePath:(NSString *)filePath;

/** format */
@property (nonatomic, assign, readonly) AVFormatContext *formatContext;

- (void)readPacket:(void (^)(BOOL isVideoPacket, BOOL isReadFinished, AVPacket packet))handler;

- (int)getVideoStreamIndex;

- (AVPacket *)readerPacket;

@end

NS_ASSUME_NONNULL_END
