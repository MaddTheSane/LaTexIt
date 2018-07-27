//
//  PaletteItem.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/12/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.

//This class is useful to describe a palette item

#import <Cocoa/Cocoa.h>

typedef enum {LATEX_ITEM_TYPE_KEYWORD, LATEX_ITEM_TYPE_FUNCTION} latex_item_type_t;

@interface PaletteItem : NSObject {
  NSString* name;
  NSString* latexCode;
  NSString* requires;
  NSImage*  image;
  latex_item_type_t type;
}

+(id) paletteItemWithName:(NSString*)name requires:(NSString*)package;
+(id) paletteItemWithName:(NSString*)name type:(latex_item_type_t)type requires:(NSString*)package;
+(id) paletteItemWithName:(NSString*)name latexCode:(NSString*)latexCode type:(latex_item_type_t)type requires:(NSString*)package;
+(id) paletteItemWithName:(NSString*)name resourceName:(NSString*)resourceName requires:(NSString*)package;
+(id) paletteItemWithName:(NSString*)name resourceName:(NSString*)resourceName type:(latex_item_type_t)type requires:(NSString*)package;

-(id) initWithName:(NSString*)name requires:(NSString*)package;
-(id) initWithName:(NSString*)name type:(latex_item_type_t)type requires:(NSString*)package;
-(id) initWithName:(NSString*)name latexCode:(NSString*)latexCode type:(latex_item_type_t)type requires:(NSString*)package;
-(id) initWithName:(NSString*)name resourceName:(NSString*)resourceName requires:(NSString*)package;
-(id) initWithName:(NSString*)name resourceName:(NSString*)resourceName type:(latex_item_type_t)type requires:(NSString*)package;

-(id) initWithName:(NSString*)aName resourceName:(NSString*)aResourceName latexCode:(NSString*)aLatexCode 
              type:(latex_item_type_t)aType  requires:(NSString*)package;

-(NSString*) name;
-(NSString*) latexCode;
-(NSString*) requires;
-(NSImage*)  image;
-(latex_item_type_t) type;
-(NSString*) toolTip;

@end
