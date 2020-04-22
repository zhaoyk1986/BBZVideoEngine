//
//  BBZInputNode.m
//  BBZVideoEngine
//
//  Created by bob on 2020/4/23.
//  Copyright © 2020年 BBZ. All rights reserved.
//

#import "BBZInputNode.h"
#import "NSDictionary+YYAdd.h"

@implementation BBZInputNode

-(instancetype)initWithDictionary:(NSDictionary *)dic {
    if (self = [super init]) {
        self.index = [dic intValueForKey:@"index" default:0];
        self.playOrder = [dic intValueForKey:@"playOrder" default:0];
        self.scale = [dic floatValueForKey:@"scale" default:1.0];
        self.assetOrder = [dic intValueForKey:@"assetOrder" default:0];
        id Obj = [dic objectForKey:@"action"];
        NSMutableArray *array = [NSMutableArray array];
        if ([Obj isKindOfClass:[NSDictionary class]]) {
            BBZNode *node = [[BBZNode alloc] initWithDictionary:Obj];
            [array addObject:node];
        } else if ([Obj isKindOfClass:[NSArray class]]) {
            for (NSDictionary *subDic in Obj) {
                BBZNode *node = [[BBZNode alloc] initWithDictionary:subDic];
                [array addObject:node];
            }
        }
        self.actions = array;
    }
    return self;
}

@end
