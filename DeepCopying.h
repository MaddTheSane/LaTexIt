//
//  DeepCopying.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/10/06.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DeepCopying <NSObject>
-(id) copyDeep;
-(id) copyDeepWithZone:(nullable NSZone*)zone;
@end

@protocol DeepMutableCopying <NSObject>
-(id) mutableCopyDeep;
-(id) mutableCopyDeepWithZone:(nullable NSZone*)zone;
@end

NS_ASSUME_NONNULL_END
