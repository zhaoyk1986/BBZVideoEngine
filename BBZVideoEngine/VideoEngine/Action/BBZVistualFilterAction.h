//
//  BBZVistualFilterAction.h
//  BBZVideoEngine
//
//  Created by Hbo on 2020/4/29.
//  Copyright © 2020 BBZ. All rights reserved.
//

#import "BBZAction.h"


@interface BBZVistualFilterAction : BBZAction
@property (nonatomic, assign) BOOL shouldIgnorMerge;//可能会有一些滤镜不希望被合并
@end


