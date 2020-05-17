//
//  BBZAssetWriter.m
//  BBZVideoEngine
//
//  Created by Hbo on 2020/5/15.
//  Copyright © 2020 BBZ. All rights reserved.
//

#import "BBZAssetWriter.h"
#import <AVFoundation/AVFoundation.h>
#import "GPUImageOutput.h"


@interface BBZAssetWriter ()

@property (nonatomic, strong) dispatch_queue_t inputQueue;
@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *videoInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *videoPixelBufferAdaptor;
@property (nonatomic, strong) AVAssetWriterInput *audioInput;

@property (nonatomic, copy) NSString *outputFile;
@property (nonatomic, copy) NSString *fileType;
@property (nonatomic, assign) CGSize videoSize;
@property (nonatomic, assign) NSTimeInterval audioFrameDurationHint;

@property (nonatomic, assign) CMTime startTime;
@property (nonatomic, assign) CMTime previousFrameTime;
@property (nonatomic, assign) CMTime previousAudioTime;
@property (nonatomic, assign) BOOL audioEncodingIsFinished;
@property (nonatomic, assign) BOOL videoEncodingIsFinished;
@end


@implementation BBZAssetWriter


- (instancetype)initWithOutputFile:(NSString *)strFilePath size:(CGSize)videoSize fileType:(NSString *)fileType {
    if(self = [super init]) {
        _outputFile = strFilePath;
        _videoSize = videoSize;
        _fileType = fileType;
         NSError *error;
        _assetWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:_outputFile] fileType:_fileType error:&error];
        if (error != nil) {
            BBZERROR(@"Error: %@", error);
            return nil;
        }
        _assetWriter.shouldOptimizeForNetworkUse = YES;
        _assetWriter.movieFragmentInterval = CMTimeMakeWithSeconds(1.0, 1000);
        NSString *strQueue = [NSString stringWithFormat:@"VideoEncoderInputQueue-%p",self];
        self.inputQueue = dispatch_queue_create([strQueue UTF8String], GPUImageDefaultQueueAttribute());
        _startTime = kCMTimeInvalid;
        _previousFrameTime = kCMTimeNegativeInfinity;
        _previousAudioTime = kCMTimeNegativeInfinity;
    }
    return self;
}

- (void)startWriting {
    dispatch_async(self.inputQueue, ^{
        [self creatVideoInput];
        if(self.hasAudioTrack) {
            [self createAudioInput];
        }
        [self.assetWriter  startWriting];
    });
}

- (void)creatVideoInput {
    NSDictionary *videoOutputSettings = self.videoOutputSettings;
    if (!videoOutputSettings) {
        videoOutputSettings = @{AVVideoCodecKey: AVVideoCodecH264,
                                AVVideoWidthKey: @(((int)_videoSize.width)),
                                AVVideoHeightKey: @(((int)_videoSize.height)),
                                AVVideoMaxKeyFrameIntervalDurationKey : @(3),
                                };
    }
    else
    {
        NSNumber *width = videoOutputSettings[AVVideoWidthKey];
        NSNumber *height = videoOutputSettings[AVVideoHeightKey];
        _videoSize = CGSizeMake([width doubleValue], [height doubleValue]);
    }
    
    self.videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoOutputSettings];
    self.videoInput.expectsMediaDataInRealTime = NO;
    
    NSDictionary *attributes = @{(id)kCVPixelBufferWidthKey: @(((int)_videoSize.width)),
                                 (id)kCVPixelBufferHeightKey: @(((int)_videoSize.height)),
                                 (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    
    self.videoPixelBufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.videoInput sourcePixelBufferAttributes:attributes];
    
    [_assetWriter addInput:self.videoInput];
}

- (void)createAudioInput {
    NSDictionary *audioOutputSettings = self.audioOutputSettings;
    self.audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioOutputSettings];
    self.audioInput.expectsMediaDataInRealTime = NO;
    [_assetWriter addInput:self.audioInput];
}

- (void)writeVideoFrameBuffer:(CMSampleBufferRef)frameBuffer {
    CVImageBufferRef videoFrame = CMSampleBufferGetImageBuffer(frameBuffer);
    CMTime time = CMSampleBufferGetOutputPresentationTimeStamp(frameBuffer);
    [self writeVideoPixelBuffer:videoFrame withPresentationTime:time];
}

- (void)writeVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer withPresentationTime:(CMTime)time {
    dispatch_async(self.inputQueue, ^{
        CFRetain(pixelBuffer);
        [self processVideoPixelBuffer:pixelBuffer withPresentationTime:time];
        CFRelease(pixelBuffer);
    });
}

- (void)writeSyncVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer withPresentationTime:(CMTime)time {
    dispatch_sync(self.inputQueue, ^{
        [self processVideoPixelBuffer:pixelBuffer withPresentationTime:time];
    });
}

- (void)processVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer withPresentationTime:(CMTime)frameTime {
    if (CMTIME_IS_INVALID(self.startTime)) {
        if (self.assetWriter.status != AVAssetWriterStatusWriting) {
            [self.assetWriter startWriting];
        }
        
        [self.assetWriter startSessionAtSourceTime:frameTime];
        self.startTime = frameTime;
    }
    while (self.videoInput.readyForMoreMediaData == NO && ! self.videoEncodingIsFinished ) {
        if (self.assetWriter.status != AVAssetWriterStatusWriting)
        {
            return;
        }
        
        usleep(100000);
        BBZINFO(@"sleep on writing video");
    }
    BOOL bAdd = YES;
    if (self.assetWriter.status == AVAssetWriterStatusWriting) {
        if (CMTIME_IS_NUMERIC(frameTime) == NO)  {
            BBZERROR(@" write video frame with invalid presentation time");
            return;
        }
        if (![(AVAssetWriterInputPixelBufferAdaptor*)self.videoPixelBufferAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:frameTime]) {
            bAdd = NO;
            BBZERROR(@" appendPixelBuffer error, %@", self.assetWriter.error);
        }
    }
    if(!bAdd && self.assetWriter.status == AVAssetWriterStatusFailed) {
        if (self.completionBlock) {
            self.completionBlock(NO, self.assetWriter.error);
        }
    }
    if(bAdd && [self.writeControl respondsToSelector:@selector(didWriteVideoFrame)]) {
        [self.writeControl didWriteVideoFrame];
    }
}

- (void)writeAudioFrameBuffer:(CMSampleBufferRef)frameBuffer {
//    if (self.hasAudioTrack) {
//        return;
//    }
    if(!self.audioInput) {
        return;
    }
    dispatch_sync(self.inputQueue, ^{
        [self processAudioBuffer:frameBuffer];
    });
}

- (void)processAudioBuffer:(CMSampleBufferRef)audioBuffer {
    CFRetain(audioBuffer);
    CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(audioBuffer);
    if (CMTIME_IS_INVALID(self.startTime)) {
        if (self.assetWriter.status != AVAssetWriterStatusWriting)  {
            [self.assetWriter startWriting];
        }
        [self.assetWriter startSessionAtSourceTime:currentSampleTime];
        self.startTime = currentSampleTime;
    } else {
        CFRelease(audioBuffer);
        audioBuffer = [self adjustTime:audioBuffer by:self.startTime];
        CFRetain(audioBuffer);
    }

    currentSampleTime = CMSampleBufferGetPresentationTimeStamp(audioBuffer);
    self.previousAudioTime = currentSampleTime;

    while(!self.audioInput.readyForMoreMediaData && ! self.audioEncodingIsFinished ) {
        BBZINFO(@"audio waiting...");
        usleep(100000);
    }
    BOOL bAdd = YES;
    if (!self.audioInput.readyForMoreMediaData) {
        BBZINFO(@"2: Had to drop an audio frame %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, currentSampleTime)));
        bAdd = NO;
    } else if(self.assetWriter.status == AVAssetWriterStatusWriting) {
        if(![self.audioInput appendSampleBuffer:audioBuffer]) {
             BBZINFO(@"Problem appending audio buffer at time: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, currentSampleTime)));
            bAdd = NO;
        }
        
    } else {
        BBZINFO(@"Wrote an audio frame %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, currentSampleTime)));
        bAdd = NO;
    }

    if (_shouldInvalidateAudioSampleWhenDone) {
        CMSampleBufferInvalidate(audioBuffer);
    }
    CFRelease(audioBuffer);
    if(!bAdd && self.assetWriter.status == AVAssetWriterStatusFailed) {
        if(self.completionBlock) {
            self.completionBlock(NO, self.assetWriter.error);
        }
    }
    if(bAdd && [self.writeControl respondsToSelector:@selector(didWriteAudioFrame)]) {
        [self.writeControl didWriteAudioFrame];
    }
}

- (void)cancleWriting {
    dispatch_async(self.inputQueue, ^{
        [self asyncCancleWriting];
    });
}

- (void)asyncCancleWriting {
    if (self.assetWriter.status == AVAssetWriterStatusCompleted) {
        return;
    }

    if(self.assetWriter.status == AVAssetWriterStatusWriting && !self.videoEncodingIsFinished) {
        self.videoEncodingIsFinished = YES;
        [self.videoInput markAsFinished];
    }
    if(self.assetWriter.status == AVAssetWriterStatusWriting && !self.audioEncodingIsFinished) {
        self.audioEncodingIsFinished = YES;
        [self.audioInput markAsFinished];
    }
    [self.assetWriter cancelWriting];

}

- (void)finishWriting {
    dispatch_async(self.inputQueue, ^{
        [self asyncfinishWriting];
    });
}

- (void)asyncfinishWriting {
    if (self.assetWriter.status == AVAssetWriterStatusCompleted || self.assetWriter.status == AVAssetWriterStatusCancelled || self.assetWriter.status == AVAssetWriterStatusUnknown) {
        if(self.completionBlock) {
            self.completionBlock(YES, nil);
        }
        return;
    }
    if(self.assetWriter.status == AVAssetWriterStatusWriting && !self.videoEncodingIsFinished) {
        self.videoEncodingIsFinished = YES;
        [self.videoInput markAsFinished];
    }
    if(self.assetWriter.status == AVAssetWriterStatusWriting && !self.audioEncodingIsFinished) {
        self.audioEncodingIsFinished = YES;
        [self.audioInput markAsFinished];
    }
    __weak typeof(self) weakSelf = self;
    [self.assetWriter finishWritingWithCompletionHandler:^(void) {
         __strong typeof(self) strongSelf = weakSelf;
         if (strongSelf.completionBlock) {
             strongSelf.completionBlock(YES, nil);
         }
     }];
}

- (CMSampleBufferRef)adjustTime:(CMSampleBufferRef) sample by:(CMTime) offset {
    CMItemCount count;
    CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
    CMSampleTimingInfo* pInfo = malloc(sizeof(CMSampleTimingInfo) * count);
    CMSampleBufferGetSampleTimingInfoArray(sample, count, pInfo, &count);
    
    for (CMItemCount i = 0; i < count; i++) {
        pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset);
        pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset);
    }
    
    CMSampleBufferRef sout;
    CMSampleBufferCreateCopyWithNewTiming(nil, sample, count, pInfo, &sout);
    free(pInfo);
    
    return sout;
}

@end
