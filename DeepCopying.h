//
//  DeepCopying.h
//  MozoDojo
//
//  Created by Pierre Chatelier on 19/10/06.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol DeepCopying
-(id) deepCopy;
-(id) deepCopyWithZone:(NSZone*)zone;
@end

@protocol DeepMutableCopying
-(id) deepMutableCopy;
-(id) deepMutableCopyWithZone:(NSZone*)zone;
@end