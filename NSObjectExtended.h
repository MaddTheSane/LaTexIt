//
//  NSObjectExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 16/03/07.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSObject (Extended)

+(Class) dynamicCastToClass:(Class)aClass;
-(id)    dynamicCastToClass:(Class)aClass;
-(BOOL)  isDarkMode;

@end
