//
//  BodyTemplatesController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 05/08/08.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BodyTemplatesController : NSArrayController {

}

+(NSDictionary*)        noneBodyTemplate;
+(NSAttributedString*)  defaultLocalizedBodyTemplateHeadAttributedString;
+(NSAttributedString*)  defaultLocalizedBodyTemplateTailAttributedString;
+(NSMutableDictionary*) defaultLocalizedBodyTemplateDictionary;
+(NSMutableDictionary*) defaultLocalizedBodyTemplateDictionaryEncoded;

-(void) ensureDefaultBodyTemplate;

-(id) arrangedObjectsNamesWithNone;

-(id)   newObject; //redefined
-(BOOL) canRemove; //redefined
-(void) add:(id)sender; //redefined

@end
