//
//  PaletteItem.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/12/05.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.

//This class is useful to describe a palette item

#import <Cocoa/Cocoa.h>

typedef enum {LATEX_ITEM_TYPE_STANDARD, LATEX_ITEM_TYPE_ENVIRONMENT} latex_item_type_t;

@interface PaletteItem : NSObject {
  NSString*         name;
  NSString*         localizedName;
  NSString*         resourcePath;
  latex_item_type_t type;
  NSUInteger        numberOfArguments;
  NSString*         latexCode;
  NSString*         requires;
  NSString*         argumentToken;
  NSString*         argumentTokenDefaultReplace;
  NSImage* image;
}

-(id) initWithName:(NSString*)name localizedName:(NSString*)localizedName resourcePath:(NSString*)resourcePath 
              type:(latex_item_type_t)type numberOfArguments:(NSUInteger)numberOfArguments
              latexCode:(NSString*)latexCode requires:(NSString*)package
              argumentToken:(NSString*)argumentToken
              argumentTokenDefaultReplace:(NSString*)argumentTokenDefaultReplace;

-(NSString*)         name;
-(NSString*)         localizedName;
-(NSString*)         resourcePath;
-(latex_item_type_t) type;
-(NSUInteger)        numberOfArguments;
-(NSString*)         latexCode;
-(NSString*)         requires;
-(NSString*)         argumentToken;
-(NSString*)         argumentTokenDefaultReplace;

-(NSImage*)  image;
-(NSString*) toolTip;
-(NSString*) stringWithTextInserted:(NSString*)text;

@end
