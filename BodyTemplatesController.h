//
//  BodyTemplatesController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 05/08/08.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BodyTemplatesController : NSArrayController {

}

+(NSDictionary*)        noneBodyTemplate;
+(NSMutableDictionary*) defaultLocalizedBodyTemplateDictionary;
+(NSMutableDictionary*) defaultLocalizedBodyTemplateDictionaryEncoded;
+(NSMutableDictionary*) bodyTemplateDictionaryForEnvironment:(NSString*)environment;
+(NSMutableDictionary*) bodyTemplateDictionaryEncodedForEnvironment:(NSString*)environment;

@property (readonly, strong) id arrangedObjectsNamesWithNone;

@property (readonly, strong) id newObject; //redefined
@property (readonly) BOOL canRemove; //redefined
-(void) add:(id)sender; //redefined

@end
