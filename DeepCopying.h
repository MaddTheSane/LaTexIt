//
//  DeepCopying.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/10/06.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DeepCopying <NSObject>
-(id) deepCopy NS_RETURNS_RETAINED;
-(id) deepCopyWithZone:(nullable NSZone*)zone NS_RETURNS_RETAINED;
@end

@protocol DeepMutableCopying <NSObject>
-(id) deepMutableCopy NS_RETURNS_RETAINED;
-(id) deepMutableCopyWithZone:(nullable NSZone*)zone NS_RETURNS_RETAINED;
@end

NS_ASSUME_NONNULL_END
