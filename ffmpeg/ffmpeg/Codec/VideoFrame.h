//
//  VideoFrame.h
//  ffmpeg
//
//  Created by KK on 2019/9/23.
//  Copyright © 2019 K K. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

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

NS_ASSUME_NONNULL_END
