//
//  PaletteItem.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/12/05.
//  Copyright 2005, 2006, 2007, 2008 Pierre Chatelier. All rights reserved.

//This class is useful to describe a palette item

#import "PaletteItem.h"


@implementation PaletteItem

-(id) initWithName:(NSString*)aName localizedName:(NSString*)aLocalizedName resourcePath:(NSString*)aResourcePath 
              type:(latex_item_type_t)aType numberOfArguments:(unsigned int)aNumberOfArguments
              latexCode:(NSString*)aLatexCode requires:(NSString*)package
{
  if (![super init] || !aName)
    return nil;

  name              = [aName copy];
  localizedName     = aLocalizedName ? [aLocalizedName copy] : [name copy];
  resourcePath      = aResourcePath  ? [aResourcePath copy]  : [name copy];
  type              = aType;
  numberOfArguments = aNumberOfArguments;
  latexCode         = aLatexCode ? [aLatexCode copy] :
                        (type == LATEX_ITEM_TYPE_ENVIRONMENT ? [[NSString alloc] initWithFormat:@"\\begin{%@}...\\end{%@}", name, name]
                                                             : [[NSString alloc] initWithFormat:@"\\%@", name]);
  NSMutableString* stringOfArguments = [NSMutableString string];
  unsigned int i = 0;
  for(i = 0 ; i<numberOfArguments ; ++i)
    [stringOfArguments appendString:@"{}"];
  if (type == LATEX_ITEM_TYPE_STANDARD)
    latexCode = [[[latexCode autorelease] stringByAppendingString:stringOfArguments] retain];

  requires = [package copy];

  if (!name || !localizedName || !latexCode || !resourcePath)
  {
    [self autorelease];
    return nil;
  }
  
  image = [[NSImage alloc] initWithContentsOfFile:aResourcePath];
  [image setCacheMode:NSImageCacheNever];
  [image setDataRetained:YES];
  [image recache];
  return self;
}
//end initWithName:localizedName:resourcePath:type:numberOfArguments:latexCode:requires:

-(void) dealloc
{
  [name          release];
  [localizedName release];
  [latexCode     release];
  [requires      release];
  [resourcePath  release];
  [image         release];
  [super dealloc];
}
//end dealloc

-(NSString*)         name              {return name;}
-(NSString*)         localizedName     {return localizedName;}
-(latex_item_type_t) type              {return type;}
-(unsigned int)      numberOfArguments {return numberOfArguments;}
-(NSString*)         latexCode         {return latexCode;}
-(NSString*)         requires          {return requires;}
-(NSString*)         resourcePath      {return resourcePath;}
-(NSImage*)          image             {return image;}

-(NSString*) toolTip
{
  return [latexCode isEqualToString:[NSString stringWithFormat:@"\\%@", name]]
           ? latexCode : [NSString stringWithFormat:@"%@ : %@", localizedName, latexCode];
}
//end toolTip

-(NSString*) formatStringToInsertText
{
  NSMutableString* string = [NSMutableString stringWithString:latexCode];
  if (type == LATEX_ITEM_TYPE_STANDARD)
  {
    NSRange range = [string rangeOfString:@"{}"];
    if (range.location != NSNotFound)
      [string replaceCharactersInRange:range withString:@"{%@}"];
  }
  else if (type == LATEX_ITEM_TYPE_ENVIRONMENT)
  {
    unsigned int length = [string length];
    NSRange beginRange = [string rangeOfString:@"\\begin{"];
    NSRange endBeginRange =
      (beginRange.location != NSNotFound) ? [string rangeOfString:@"}" options:0 range:NSMakeRange(beginRange.location, length-beginRange.location)]
                                          : beginRange;
    NSRange endRange =
      (endBeginRange.location != NSNotFound) ? [string rangeOfString:@"\\end{" options:0 range:NSMakeRange(endBeginRange.location, length-endBeginRange.location)]
                                             : endBeginRange;
    if ((endRange.location != NSNotFound) && (endBeginRange.location+1 < length) && (endRange.location >= endBeginRange.location+1))
      [string replaceCharactersInRange:NSMakeRange(endBeginRange.location+1, endRange.location-endBeginRange.location-1)  withString:@"%@"];
  }
  return string;
}
//end formatStringToInsertText

@end
