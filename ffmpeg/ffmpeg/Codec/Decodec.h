//
//  Decodec.h
//  ffmpeg
//
//  Created by K K on 2019/9/6.
//  Copyright © 2019 K K. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "DecodeOptions.h"

NS_ASSUME_NONNULL_BEGIN

@class Decodec;
@protocol DecodecDelegate <NSObject>

- (void)decodecVideWitd:(Decodec *)decodec samplebuffer:(CMSampleBufferRef)samplebuffer;

@end

@interface Decodec : NSObject

- (instancetype)initWithFilePath:(NSString *)filePath options:(DecodeOptions *)options;

/** options */
@property (nonatomic, strong, readonly) DecodeOptions *options;

/* desc */
@property (nonatomic, assign) id<DecodecDelegate> delegate;

- (void)startDecode;
- (void)pauseDecode;

- (CVPixelBufferRef)getPixelBuffer;

@end

NS_ASSUME_NONNULL_END
