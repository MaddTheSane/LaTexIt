//
//  PaletteItem.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/12/05.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.

//This class is useful to describe a palette item

#import "PaletteItem.h"

#import <RegexKitLite.h>

@implementation PaletteItem

-(id) initWithName:(NSString*)aName localizedName:(NSString*)aLocalizedName resourcePath:(NSString*)aResourcePath 
              type:(latex_item_type_t)aType numberOfArguments:(NSUInteger)aNumberOfArguments
              latexCode:(NSString*)aLatexCode requires:(NSString*)package
              argumentToken:(NSString*)anArgumentToken
              argumentTokenDefaultReplace:(NSString*)anArgumentTokenDefaultReplace
{
  if ((!(self = [super init])) || !aName)
    return nil;

  self->name              = [aName copy];
  self->localizedName     = aLocalizedName ? [aLocalizedName copy] : [self->name copy];
  self->resourcePath      = aResourcePath  ? [aResourcePath copy]  : [self->name copy];
  self->type              = aType;
  self->numberOfArguments = aNumberOfArguments;
  self->latexCode         = aLatexCode ? [aLatexCode copy] :
                            (self->type == LATEX_ITEM_TYPE_ENVIRONMENT ?
                              [[NSString alloc] initWithFormat:@"\\begin{%@}...\\end{%@}", name, name] :
                              [[NSString alloc] initWithFormat:@"\\%@", name]);
  const unichar bulletChar = 0x2026;
  NSString* bulletString = [NSString stringWithCharacters:&bulletChar length:1];
  NSUInteger presetArgsCount = [[self->latexCode componentsMatchedByRegex:@"\\{.*?(\\{.*\\})*\\}"] count];
  NSMutableString* stringOfArguments = [NSMutableString string];
  NSUInteger i = 0;
  for(i = presetArgsCount ; i<self->numberOfArguments ; ++i)
    [stringOfArguments appendFormat:@"{%@}", bulletString];
  if (self->type == LATEX_ITEM_TYPE_STANDARD)
    self->latexCode = [self->latexCode stringByAppendingString:stringOfArguments];

  self->requires = [package copy];
  self->argumentToken               = !anArgumentToken ? @"" : [anArgumentToken copy];
  self->argumentTokenDefaultReplace = !anArgumentTokenDefaultReplace ? @"" : [anArgumentTokenDefaultReplace copy];

  if (!self->name || !self->localizedName || !self->latexCode || !self->resourcePath)
  {
    return nil;
  }
  
  self->image = [[NSImage alloc] initWithContentsOfFile:aResourcePath];
  [self->image setCacheMode:NSImageCacheNever];
  [self->image recache];
  return self;
}
//end initWithName:localizedName:resourcePath:type:numberOfArguments:latexCode:requires:

@synthesize name;
@synthesize localizedName;
@synthesize type;
@synthesize numberOfArguments;
@synthesize latexCode;
@synthesize requires;
@synthesize argumentToken;
@synthesize argumentTokenDefaultReplace;
@synthesize resourcePath;
@synthesize image;

-(NSString*) toolTip
{
  return [self->latexCode isEqualToString:[NSString stringWithFormat:@"\\%@", self->name]] ?
           self->latexCode :
           [NSString stringWithFormat:@"%@ : %@", self->localizedName, self->latexCode];
}
//end toolTip

-(NSString*) stringWithTextInserted:(NSString*)text
{
  NSMutableString* string = [NSMutableString stringWithString:self->latexCode];
  if (self->type == LATEX_ITEM_TYPE_STANDARD)
  {
    [string replaceOccurrencesOfString:[NSString stringWithFormat:@"{%@}", self->argumentToken]
                            withString:[NSString stringWithFormat:@"{%@}", [text length] ? text : self->argumentTokenDefaultReplace]
                               options:0 range:NSMakeRange(0, [string length])];
  }
  else if (self->type == LATEX_ITEM_TYPE_ENVIRONMENT)
  {
    NSUInteger length = [string length];
    NSRange beginRange = [string rangeOfString:@"\\begin{"];
    NSRange endBeginRange =
      (beginRange.location != NSNotFound) ? [string rangeOfString:@"}" options:0 range:NSMakeRange(beginRange.location, length-beginRange.location)]
                                          : beginRange;
    NSRange endRange =
      (endBeginRange.location != NSNotFound) ? [string rangeOfString:@"\\end{" options:0 range:NSMakeRange(endBeginRange.location, length-endBeginRange.location)]
                                             : endBeginRange;
    if ((endRange.location != NSNotFound) && (endBeginRange.location+1 < length) && (endRange.location >= endBeginRange.location+1))
    {
      NSString* replacement = ([text length] ? text : self->argumentTokenDefaultReplace);
      if (replacement)
        [string replaceCharactersInRange:NSMakeRange(endBeginRange.location+1, endRange.location-endBeginRange.location-1)
                              withString:replacement];
    }//end if ((endRange.location != NSNotFound) && (endBeginRange.location+1 < length) && (endRange.location >= endBeginRange.location+1))
  }
  return string;
}
//end stringWithTextInserted:

@end
