//
//  NSObjectExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 16/03/07.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSObject (Extended)

+(nullable Class) dynamicCastToClass:(nonnull Class)aClass;
-(nullable id)    dynamicCastToClass:(nonnull Class)aClass;
@property (readonly, getter=isDarkMode) BOOL darkMode;

@end
