//  LibraryFile.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 2/05/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//The LibraryFile is a libraryItem (that can appear in the library outlineview)
//But it represents a "file", that is to say a document state
//This state is stored as an historyItem, that is already perfect for that

#import "LibraryFile.h"

#import "HistoryItem.h"

@implementation LibraryFile

static NSImage* smallFileIcon = nil; //to store the icon representing a LibraryFile

+(void) initialize
{
  if (!smallFileIcon)
  {
    //computes the icon used to represente a LibraryFile item
    NSBundle* mainBundle = [NSBundle mainBundle];
    NSString* resourcePath = [mainBundle resourcePath];
    NSString* fileName = nil;
    NSImage*  image = nil;
    fileName = [resourcePath stringByAppendingPathComponent:@"file-icon.png"];
    image = [[NSImage alloc] initWithContentsOfFile:fileName];
    NSSize   iconSize = [image size];
    smallFileIcon = [[NSImage alloc] initWithSize:NSMakeSize(16, 16)];
    [smallFileIcon lockFocus];
    [image drawInRect:NSMakeRect(0, 0, 16, 16)
             fromRect:NSMakeRect(0, 0, iconSize.width, iconSize.height)
            operation:NSCompositeCopy fraction:1.0];
    [smallFileIcon unlockFocus];
    [image release];
  }
}

-(void) dealloc
{
  [historyItem release];
  [super dealloc];
}

-(id) copyWithZone:(NSZone*) zone
{
  LibraryFile* newInstance = (LibraryFile*) [super copy];
  if (newInstance)
    newInstance->historyItem = [historyItem copy];
  return newInstance;
}

-(NSImage*) image
{
  return smallFileIcon; //icon of a LibraryFile
}

//The document's state contained in the LibraryFile item is called a "value"
//because the fact that it is represented by a historyItem
//should not be "public"

-(void) setValue:(HistoryItem*)aHistoryItem setAutomaticTitle:(BOOL)setAutomaticTitle
{
  [aHistoryItem retain];
  [historyItem release];
  historyItem = aHistoryItem;
  NSString* string = [[historyItem sourceText] string];
  unsigned int endIndex = MIN(17U, [string length]);
  if (setAutomaticTitle)
    [self setTitle:[string substringToIndex:endIndex]];
}

-(HistoryItem*) value
{
  return historyItem;
}

//NSCoding protocol

-(void) encodeWithCoder:(NSCoder*) coder
{
  [super encodeWithCoder:coder];
  [coder encodeObject:historyItem forKey:@"value"];
}

-(id) initWithCoder:(NSCoder*)coder
{
  if (![super initWithCoder:coder])
    return nil;
  historyItem = [[coder decodeObjectForKey:@"value"] retain];
  return self;
}

@end
