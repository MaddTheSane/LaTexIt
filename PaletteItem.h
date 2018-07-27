//
//  PaletteItem.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/12/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.

//This class is useful to describe a palette item

#import <Cocoa/Cocoa.h>

typedef enum {LATEX_ITEM_TYPE_STANDARD, LATEX_ITEM_TYPE_ENVIRONMENT} latex_item_type_t;

@interface PaletteItem : NSObject {
  NSString*         name;
  NSString*         localizedName;
  NSString*         resourcePath;
  latex_item_type_t type;
  unsigned int      numberOfArguments;
  NSString*         latexCode;
  NSString*         requires;

  NSImage* image;
}

-(id) initWithName:(NSString*)name localizedName:(NSString*)localizedName resourcePath:(NSString*)resourcePath 
              type:(latex_item_type_t)type numberOfArguments:(unsigned int)numberOfArguments
              latexCode:(NSString*)latexCode requires:(NSString*)package;
                
-(NSString*)         name;
-(NSString*)         localizedName;
-(NSString*)         resourcePath;
-(latex_item_type_t) type;
-(unsigned int)      numberOfArguments;
-(NSString*)         latexCode;
-(NSString*)         requires;

-(NSImage*)  image;
-(NSString*) toolTip;
-(NSString*) formatStringToInsertText;

@end
