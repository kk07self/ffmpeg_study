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

@interface Decodec : NSObject

- (instancetype)initWithFilePath:(NSString *)filePath options:(DecodeOptions *)options;

/** options */
@property (nonatomic, strong, readonly) DecodeOptions *options;

- (CVPixelBufferRef)getPixelBuffer;

@end

NS_ASSUME_NONNULL_END
