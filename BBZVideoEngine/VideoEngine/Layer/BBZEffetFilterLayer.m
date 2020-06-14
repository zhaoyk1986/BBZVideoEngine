//
//  BBZEffetFilterLayer.m
//  BBZVideoEngine
//
//  Created by bob on 2020/4/29.
//  Copyright © 2020年 BBZ. All rights reserved.
//

#import "BBZEffetFilterLayer.h"
#import "BBZFilterAction.h"

@implementation BBZEffetFilterLayer

- (BBZActionBuilderResult *)buildTimelineNodes:(BBZActionBuilderResult *)inputBuilder {
    NSAssert(self.model.assetItems.count > 0, @"must have at least one asset");
    BBZActionBuilderResult *builder = nil;
    if(self.model.filterModel.filterGroups.count > 0) {
        builder = [self buildEffectTimeLine:inputBuilder];
    }
    return builder;
}


- (BBZActionBuilderResult *)buildEffectTimeLine:(BBZActionBuilderResult *)inputBuilderResult {
    
    BBZActionBuilderResult *builder = [[BBZActionBuilderResult alloc] init];
    builder.startTime = 0;
    builder.groupIndex = 0;
    NSMutableArray *retArray = [NSMutableArray array];
    for (BBZFilterNode *filterNode in self.model.filterModel.filterGroups) {
        NSUInteger startTime = filterNode.begin * BBZVideoDurationScale;
        if(filterNode.bPlayFromEnd) {
            startTime = MAX(inputBuilderResult.startTime - filterNode.duration, 0);
        }
        startTime = MIN(startTime, inputBuilderResult.startTime);
        CGFloat duration = filterNode.duration;
        duration = MIN(duration, inputBuilderResult.startTime - (startTime + duration));
        duration = MAX(duration, 0);
        if(fabs(duration) < 0.01) {
            BBZERROR(@"duration is zero");
            continue;
        }
        BBZActionTree *effectTree = [self actionTreeWithFilterNode:filterNode duration:duration startTime:startTime];
        if(effectTree) {
            [retArray addObject:effectTree];
            builder.groupIndex++;
            builder.assetIndex++;
            effectTree.groupIndex = builder.groupIndex;
        }
    }
    builder.groupActions = retArray;
    return builder;
 
}

- (BBZActionTree *)actionTreeWithFilterNode:(BBZFilterNode *)filterNode
                                  duration:(NSUInteger)duration
                                 startTime:(NSUInteger)startTime{
    BBZActionTree *effectTree = [BBZActionTree createActionWithBeginTime:startTime endTime:startTime+duration];
    for (BBZNode *node in filterNode.actions) {
        BBZVistualFilterAction *filterAction = [[BBZVistualFilterAction alloc] initWithNode:node];
        filterAction.renderSize = self.context.renderSize;
        filterAction.startTime = startTime + node.begin * BBZVideoDurationScale;
        filterAction.duration = MIN(duration, (node.end - node.begin) * node.repeat * BBZVideoDurationScale);
        [effectTree addAction:filterAction];
    }
    if(effectTree.actions.count == 0) {
        effectTree = nil;
    }
    return effectTree;
}


@end
