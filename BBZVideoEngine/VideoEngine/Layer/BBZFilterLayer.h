//
//  BBZFilterLayer.h
//  BBZVideoEngine
//
//  Created by Hbo on 2020/4/20.
//  Copyright © 2020 BBZ. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "bbzAction.h"
#import "BBZVideoModel.h"
#import "BBZEngineContext.h"
#import "BBZActionTree.h"


@protocol BBZFilterLayerProtocol <NSObject>
- (void)filterLayerAppendTimePoint:(NSArray *)timePoints;
@end

@interface BBZFilterLayer : NSObject
@property (nonatomic, strong, readonly) BBZVideoModel *model;
@property (nonatomic, strong, readonly) BBZEngineContext *context;
@property (nonatomic, weak) id<BBZFilterLayerProtocol> layerDelegate;

- (instancetype)initWithModel:(BBZVideoModel *)model context:(BBZEngineContext *)context;
- (void)buildTimelineNodes;

@end

@interface BBZActionBuilderResult : NSObject
@property (nonatomic, assign) NSUInteger groupIndex;
@property (nonatomic, assign) NSUInteger assetIndex;
@property (nonatomic, assign) double startTime;
@property (nonatomic, strong) NSArray<BBZAction* > *groupActions;
@end

