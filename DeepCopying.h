//
//  DeepCopying.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/10/06.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol DeepCopying
-(id) copyDeep;
-(id) copyDeepWithZone:(NSZone*)zone;
@end

@protocol DeepMutableCopying
-(id) mutableCopyDeep;
-(id) mutableCopyDeepWithZone:(NSZone*)zone;
@end
