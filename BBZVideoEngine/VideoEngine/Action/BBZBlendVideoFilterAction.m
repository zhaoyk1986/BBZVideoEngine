//
//  BBZBlendVideoFilterAction.m
//  BBZVideoEngine
//
//  Created by Hbo on 2020/11/2.
//  Copyright © 2020 BBZ. All rights reserved.
//

#import "BBZBlendVideoFilterAction.h"
#import "GPUImageFramebuffer+BBZ.h"
#import "BBZNodeAnimationParams+property.h"
#import "BBZFilterMixer.h"
#import "BBZMaskVideoFilter.h"
#import "BBZAssetReader.h"
#import "BBZVideoAsset.h"


@interface BBZBlendVideoFilterAction ()
@property (nonatomic, strong) BBZAssetReader *reader;
@property (nonatomic, strong) BBZAssetReaderRandomAccessVideoOutput *videoOutPut;

@end

@implementation BBZBlendVideoFilterAction

- (instancetype)initWithNode:(BBZNode *)node {
    if(self = [super initWithNode:node]) {
        [self createVideoReader];
    }
    return self;
}



- (void)createImageFilter {
    BBZFilterMixer *mixer = [BBZFilterMixer filterMixerWithNodes:@[self.node]];
    self.multiFilter = [[BBZMaskVideoFilter alloc] initWithVertexShaderFromString:mixer.vShaderString fragmentShaderFromString:mixer.fShaderString];
    [super createImageFilter];
}

- (void)createVideoReader {
    NSString *strPath = self.node.filePath;
    NSString *strFile = [NSString stringWithFormat:@"%@/%@", strPath, self.node.attenmentFile];
    if(![[NSFileManager defaultManager] fileExistsAtPath:strFile]) {
        NSAssert(false, @"maskVideo file not exist");
        return;
    }
    
    AVURLAsset *avAsset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:strFile] options:nil];
    BBZVideoAsset *videoAsset = [BBZVideoAsset assetWithAVAsset:avAsset];
     self.reader = [[BBZAssetReader alloc] initWithAsset:(AVAsset *)videoAsset.asset];
    self.reader.timeRange = videoAsset.playTimeRange;
    self.videoOutPut = [[BBZAssetReaderRandomAccessVideoOutput alloc] initWithOutputSettings:[self defaultVideoOutputSettings]];
    [self.reader addOutput:self.videoOutPut];
}

- (NSDictionary *)defaultVideoOutputSettings {
    return @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
}


- (void)lock {
    [super lock];
    if(!self.reader) {
        [self createVideoReader];
        [self.videoOutPut startProcessing];
    }
}

- (void)destroySomething{
    [self.videoOutPut endProcessing];
    [self.reader removeOutput:self.videoOutPut];
    self.videoOutPut = nil;
    self.reader = nil;
    [super destroySomething];
}


#pragma mark - time
- (void)updateWithTime:(CMTime)time {
    /*
     time 为真实时间
     node里面 时间为放大了100倍的时间，需要进行换算 ，然后计算 node当前值
     */
    if(!self.node.name) {
        NSAssert(false, @"error");
        return;
    }
    CMTime actionTime = CMTimeSubtract(time, self.realStartCMTime);
    if (CMTIME_IS_NUMERIC(actionTime) &&
        CMTIME_COMPARE_INLINE(actionTime, >=, kCMTimeZero)) {
        CMTime assetTime = [self.node relativeTimeFromActionTime:actionTime];
        [self.videoOutPut sampleBufferAtTime:assetTime];
        NSLog(@"BBZBlendVideoFilterAction %.4f,%.4f,%.4f", CMTimeGetSeconds(time),CMTimeGetSeconds(actionTime),CMTimeGetSeconds(assetTime));
    } else {
        NSAssert(false, @"time error");
    }
    
//    BBZNodeAnimationParams *params = [self.node paramsAtTime:relativeTime];
    
//    runAsynchronouslyOnVideoProcessingQueue(^{
//        self.multiFilter.vector4ParamValue1 =(GPUVector4){params.param1, params.param2, params.param3, params.param4};
//        BBZINFO(@"updateWithTime %f, %f, %f, %f %@", params.param1, params.param2, params.param3, params.param4, self.node.name);
//    });
    
    
}

- (void)newFrameAtTime:(CMTime)time {
    if(!self.videoOutPut.currentSampleBuffer) {
        BBZERROR(@"lost MaskVideo");
        return;
    }

   CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(self.videoOutPut.currentSampleBuffer);
    if (!pixelBuffer) {
        NSAssert(false, @"CMSampleBufferGetImageBuffer error");
        return;
    }
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    GPUImageFramebuffer *maskFrameBuffer = [GPUImageFramebuffer BBZ_frameBufferWithCVPixelBuffer:pixelBuffer];
    [self.multiFilter addFrameBuffer:maskFrameBuffer];
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
}


@end
