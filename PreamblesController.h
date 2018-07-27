//
//  PreamblesController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 05/08/08.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PreamblesController : NSArrayController {

}

+(id) defaultLocalizedPreambleDictionary;
+(id) encodePreamble:(NSDictionary*)preambleDictionary;
+(id) decodePreamble:(NSDictionary*)preambleAsPlist;

-(id) newObject; //redefined
-(BOOL) canRemove; //redefined

@end
