//
//  Bridge.h
//  Bridge10_5
//
//  Created by Pierre Chatelier on 08/08/08.
//  Copyright 2008 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface Bridge : NSObject {

}

+(BOOL) addMethod:(SEL)aSelector toClass:(Class)targetClass;

@end
