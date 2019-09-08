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


@interface AVPacketResult : NSObject

/** 是否为空 */
@property (nonatomic, assign) BOOL isNull;

/** 类型 */
@property (nonatomic, assign) enum AVMediaType mediaType;

/** packet */
@property (nonatomic, assign) AVPacket packet;

@end

@interface DemuxMedia : NSObject

- (instancetype)initWithFilePath:(NSString *)filePath;

/** format */
@property (nonatomic, assign, readonly) AVFormatContext *formatContext;


- (AVPacketResult *)getMediaoPacket;
- (int)getVideoStreamIndex;

@end

NS_ASSUME_NONNULL_END
