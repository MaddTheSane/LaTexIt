//
//  PreamblesController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 05/08/08.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PreamblesController : NSArrayController {

}

+(NSAttributedString*)  defaultLocalizedPreambleValueAttributedString;
+(NSMutableDictionary*) defaultLocalizedPreambleDictionary;
+(NSMutableDictionary*) defaultLocalizedPreambleDictionaryEncoded;

-(void) ensureDefaultPreamble;

-(id)   newObject; //redefined
-(BOOL) canRemove; //redefined
-(void) add:(id)sender; //redefined

@end
