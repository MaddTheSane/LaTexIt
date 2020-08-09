//
//  PaletteItem.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/12/05.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.

//This class is useful to describe a palette item

#import "PaletteItem.h"

#import "RegexKitLite.h"
#import "NSStringExtended.h"
#import "Utils.h"


static NSString* bulletString = @"\u2026";

@implementation PaletteItem

-(instancetype) initWithName:(NSString*)aName localizedName:(NSString*)aLocalizedName resourcePath:(NSString*)aResourcePath 
              type:(latex_item_type_t)aType numberOfArguments:(NSUInteger)aNumberOfArguments
              latexCode:(NSString*)aLatexCode requires:(NSString*)package
              argumentToken:(NSString*)anArgumentToken
              argumentTokenDefaultReplace:(NSString*)anArgumentTokenDefaultReplace
              argumentTokenRemoveBraces:(BOOL)anArgumentTokenRemoveBraces
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
  NSUInteger presetArgsCount = [self->latexCode componentsMatchedByRegex:@"\\{.*?(\\{.*\\})*\\}"].count;
  NSMutableString* stringOfArguments = [NSMutableString string];
  NSUInteger i = 0;
  for(i = presetArgsCount ; i<self->numberOfArguments ; ++i)
    [stringOfArguments appendFormat:@"{%@}", bulletString];
  if (self->type == LATEX_ITEM_TYPE_STANDARD)
    self->latexCode = [self->latexCode stringByAppendingString:stringOfArguments];

  self->requires = [package copy];
  self->argumentToken               = [anArgumentToken copy];
  self->argumentTokenDefaultReplace = [anArgumentTokenDefaultReplace copy];
  self->argumentTokenRemoveBraces = anArgumentTokenRemoveBraces;

  if (!self->name || !self->localizedName || !self->latexCode || !self->resourcePath)
  {
    return nil;
  }
  
  self->image = [[NSImage alloc] initWithContentsOfFile:aResourcePath];
  self->image.cacheMode = NSImageCacheNever;
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
-(BOOL)              argumentTokenRemoveBraces   {return self->argumentTokenRemoveBraces;}
@synthesize resourcePath;
@synthesize image;

-(NSString*) toolTip
{
  return [self->latexCode isEqualToString:[NSString stringWithFormat:@"\\%@", self->name]] ?
           self->latexCode :
           [NSString stringWithFormat:@"%@ : %@", self->localizedName, self->latexCode];
}
//end toolTip

-(NSString*) stringWithTextInserted:(NSString*)text outInterestingRange:(NSRange*)outInterestingRange
{
  NSMutableString* string = [NSMutableString stringWithString:self->latexCode];
  NSRange interestingRange = NSMakeRange(0, 0);
  if (self->type == LATEX_ITEM_TYPE_STANDARD)
  {
    NSError* error = nil;
    NSString* textBackslashed = [text stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    NSString* pattern =
      [NSString stringWithFormat:@"(\\{.*\\})*\\{%@\\}", NSStringWithNilDefault(self->argumentToken, bulletString)];
    NSString* patternReplacement =
      [NSString stringWithFormat:@"$1%@%@%@",
        self->argumentTokenRemoveBraces ? @"" : @"{",
        [textBackslashed length] ? textBackslashed : NSStringWithNilDefault(self->argumentTokenDefaultReplace, bulletString),
        self->argumentTokenRemoveBraces ? @"" : @"}"];
    NSRange searchRange = [string range];
    NSRange lastPatternRange = NSMakeRange(NSNotFound, 0);
    NSRange lastReplacementRange = NSMakeRange(NSNotFound, 0);
    lastPatternRange = [string rangeOfRegex:pattern options:0 inRange:searchRange capture:0 error:&error];
    while((lastPatternRange.location != NSNotFound) && lastPatternRange.length)
    {
      NSUInteger oldStringLength = [string length];
      [string replaceOccurrencesOfRegex:pattern withString:patternReplacement options:0 range:lastPatternRange error:&error];
      NSUInteger newStringLength = [string length];
      lastReplacementRange = NSMakeRange(lastPatternRange.location, lastPatternRange.length+newStringLength-oldStringLength);
      NSUInteger newSearchRangeLocation = NSMaxRange(lastReplacementRange);
      searchRange = NSMakeRange(newSearchRangeLocation, newStringLength-newSearchRangeLocation);
      lastPatternRange = [string rangeOfRegex:pattern options:0 inRange:searchRange capture:0 error:&error];
    }//end while pattern found
    interestingRange =
      ([textBackslashed length] != 0) ? [string range] :
      self->argumentTokenRemoveBraces || (lastReplacementRange.length <= 2) ? lastReplacementRange :
      NSMakeRange(lastReplacementRange.location+1, lastReplacementRange.length-2);
  }//end if (self->type == LATEX_ITEM_TYPE_STANDARD)
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
      NSString* replacement = ([text length] ? text : NSStringWithNilDefault(self->argumentTokenDefaultReplace, bulletString));
      if (replacement)
        [string replaceCharactersInRange:NSMakeRange(endBeginRange.location+1, endRange.location-endBeginRange.location-1)
                              withString:replacement];
    }//end if ((endRange.location != NSNotFound) && (endBeginRange.location+1 < length) && (endRange.location >= endBeginRange.location+1))
  }//end if (self->type == LATEX_ITEM_TYPE_ENVIRONMENT)
  if (outInterestingRange)
    *outInterestingRange = interestingRange;
  return string;
}
//end stringWithTextInserted:

@end
