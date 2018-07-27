//
//  PaletteItem.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/12/05.
//  Copyright 2005 PaletteItem. All rights reserved.

//This class is useful to describe a palette item

#import "PaletteItem.h"


@implementation PaletteItem

+(id) paletteItemWithName:(NSString*)name requires:(NSString*)package
{return [[[[self class] alloc] initWithName:name requires:package] autorelease];}

+(id) paletteItemWithName:(NSString*)name type:(latex_item_type_t)type requires:(NSString*)package
{return [[[[self class] alloc] initWithName:name type:type requires:package] autorelease];}

+(id) paletteItemWithName:(NSString*)name latexCode:(NSString*)latexCode type:(latex_item_type_t)type requires:(NSString*)package
{return [[[[self class] alloc] initWithName:name latexCode:latexCode type:type requires:package] autorelease];}

+(id) paletteItemWithName:(NSString*)name resourceName:(NSString*)resourceName requires:(NSString*)package
{return [[[[self class] alloc] initWithName:name resourceName:resourceName requires:package] autorelease];}

+(id) paletteItemWithName:(NSString*)name resourceName:(NSString*)resourceName type:(latex_item_type_t)type requires:(NSString*)package
{return [[[[self class] alloc] initWithName:name resourceName:resourceName type:type requires:package] autorelease];}

-(id) initWithName:(NSString*)aName requires:(NSString*)package
{return [self initWithName:aName resourceName:aName
                 latexCode:[NSString stringWithFormat:@"\\%@", aName] type:LATEX_ITEM_TYPE_KEYWORD requires:package];}

-(id) initWithName:(NSString*)aName type:(latex_item_type_t)aType requires:(NSString*)package
{return [self initWithName:aName resourceName:aName latexCode:[NSString stringWithFormat:@"\\%@", aName] type:aType requires:package];}

-(id) initWithName:(NSString*)aName latexCode:(NSString*)aLatexCode type:(latex_item_type_t)aType requires:(NSString*)package
{return [self initWithName:aName resourceName:aName latexCode:aLatexCode type:aType requires:package];}

-(id) initWithName:(NSString*)aName resourceName:(NSString*)aResourceName requires:(NSString*)package
{return [self initWithName:aName resourceName:aResourceName
                 latexCode:[NSString stringWithFormat:@"\\%@", aName] type:LATEX_ITEM_TYPE_KEYWORD requires:package];}

-(id) initWithName:(NSString*)aName resourceName:(NSString*)aResourceName type:(latex_item_type_t)aType requires:(NSString*)package
{return [self initWithName:aName resourceName:aResourceName
                 latexCode:[NSString stringWithFormat:@"\\%@", aName] type:aType requires:package];}

-(id) initWithName:(NSString*)aName resourceName:(NSString*)aResourceName latexCode:(NSString*)aLatexCode 
              type:(latex_item_type_t)aType requires:(NSString*)package
{
  if (![super init])
    return nil;
  type      = aType;
  name      = [aName copy];
  latexCode = [aLatexCode copy];
  requires  = [package copy];
  image     = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForImageResource:aResourceName]];
  [image setCacheMode:NSImageCacheNever];
  [image setDataRetained:YES];
  [image recache];
  return self;
}

-(void) dealloc
{
  [name release];
  [latexCode release];
  [image release];
  [super dealloc];
}

-(NSString*) name         {return name;}
-(NSString*) latexCode    {return latexCode;}
-(NSString*) requires     {return requires;}
-(NSImage*)  image        {return image;}
-(latex_item_type_t) type {return type;}

-(NSString*) toolTip
{
  NSMutableString* toolTip = [NSMutableString stringWithString:latexCode];
  if (type == LATEX_ITEM_TYPE_FUNCTION)
    [toolTip appendString:@"{...}"];
  return toolTip;
}

@end
