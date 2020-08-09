//
//  PaletteItem.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/12/05.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.

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
  BOOL              argumentTokenRemoveBraces;
  NSImage* image;
}

-(instancetype)init UNAVAILABLE_ATTRIBUTE;
-(instancetype) initWithName:(NSString*)name localizedName:(NSString*)localizedName resourcePath:(NSString*)resourcePath 
              type:(latex_item_type_t)type numberOfArguments:(NSUInteger)numberOfArguments
              latexCode:(NSString*)latexCode requires:(NSString*)package
              argumentToken:(NSString*)argumentToken
              argumentTokenDefaultReplace:(NSString*)argumentTokenDefaultReplace
              argumentTokenRemoveBraces:(BOOL)anArgumentTokenRemoveBraces NS_DESIGNATED_INITIALIZER;

@property (readonly, copy) NSString *name;
@property (readonly, copy) NSString *localizedName;
@property (readonly, copy) NSString *resourcePath;
@property (readonly) latex_item_type_t type;
@property (readonly) NSUInteger        numberOfArguments;
@property (readonly, copy) NSString *latexCode;
@property (readonly, copy) NSString *requires;
@property (readonly, copy) NSString *argumentToken;
@property (readonly, copy) NSString *argumentTokenDefaultReplace;
-(BOOL)              argumentTokenRemoveBraces;

@property (readonly, strong) NSImage *image;
@property (readonly, copy) NSString *toolTip;
-(NSString*) stringWithTextInserted:(NSString*)text outInterestingRange:(NSRange*)outInterestingRange;

@end
