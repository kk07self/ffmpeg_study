//
//  DisplayGLView.h
//  ffmpeg
//
//  Created by KK on 2019/9/23.
//  Copyright © 2019 K K. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VideoDecodec.h"

NS_ASSUME_NONNULL_BEGIN

@interface DisplayGLView : UIView

- (instancetype)initWithFrame:(CGRect)frame videoFormat:(VideoFrameFormat)format;

- (void)render:(VideoFrame * _Nullable )frame;

@end

NS_ASSUME_NONNULL_END
