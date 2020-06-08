//
//  BBZVideoInputFilter.h
//  BBZVideoEngine
//
//  Created by Hbo on 2020/5/4.
//  Copyright © 2020 BBZ. All rights reserved.
//

#import "BBZMultiImageFilter.h"

//typedef NS_ENUM(NSInteger, BBZVideoInputType) {
//    BBZVideoInputTypeImage,
//    BBZVideoInputTypeVideo,
//};


typedef NS_ENUM(NSUInteger, BBZVideoFillModeType) {
    BBZVideoFillModeStretch,
    BBZVideoFillModePreserveAspectRatio,
    BBZVideoFillModePreserveAspectRatioAndFill
};

/*
 使用transform有三种场景
 1.视频输入
 2.image输入
 */
@interface BBZVideoInputFilter : BBZMultiImageFilter

@property (nonatomic, assign) BOOL bUseBackGroundImage;
@property (nonatomic, strong) GPUImageFramebuffer *bgFrameBuffer;
//@property (nonatomic, assign) BBZVideoInputType type;
@property (nonatomic, assign) CGSize renderSize;
@property (nonatomic, assign) CGAffineTransform affineTransform;
@property (nonatomic, assign) CATransform3D transform3D;
@property (nonatomic, assign) BBZVideoFillModeType fillType;


//- (void)renderVideo:(CMSampleBufferRef)sampleBuffer atTime:(CMTime)time;
//- (void)renderImage:(GPUImageFramebuffer *)imageFrameBuffer atTime:(CMTime)time;


@end

