//  LibraryFolder.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//The LibraryFolder is a libraryItem (that can appear in the library outlineview)
//But it represents a "folder", that is to say a parent for other library items
//It contains nothing more than a LibraryItem, which is already similar to an XMLNode

#import "LibraryFolder.h"

@implementation LibraryFolder

static NSImage* smallFolderIcon = nil; //stores the icon of a LibraryFolder
static NSImage* bigFolderIcon   = nil; //stores the big icon of a LibraryFolder

+(void) initialize
{
  if (!smallFolderIcon) //computes the icon of a LibraryFolder
  {
    NSBundle* mainBundle = [NSBundle mainBundle];
    NSString* resourcePath = [mainBundle resourcePath];
    NSString* fileName = nil;
    NSImage*  image = nil;
    fileName = [resourcePath stringByAppendingPathComponent:@"big-folder-icon.tiff"];
    image = [[NSImage alloc] initWithContentsOfFile:fileName];
    bigFolderIcon = [image retain];
    NSSize   iconSize = [image size];
    smallFolderIcon = [[NSImage alloc] initWithSize:NSMakeSize(16, 16)];
    [smallFolderIcon lockFocus];
    [image drawInRect:NSMakeRect(0, 0, 16, 16)
             fromRect:NSMakeRect(0, 0, iconSize.width, iconSize.height)
            operation:NSCompositeCopy fraction:1.0];
    [smallFolderIcon unlockFocus];
    [image release];
  }
}

-(id) copyWithZone:(NSZone*)zone
{
  LibraryFolder* newInstance = (LibraryFolder*) [super copyWithZone:zone];
  return newInstance;
}

-(NSImage*) icon
{
  return smallFolderIcon; //icon of a LibraryFolder
}

-(NSImage*) bigIcon
{
  return bigFolderIcon; //icon of a LibraryFolder
}

//NSCoding protocol

-(void) encodeWithCoder:(NSCoder*)coder
{
  [super encodeWithCoder:coder];
}

-(id) initWithCoder:(NSCoder*)coder
{
  if (![super initWithCoder:coder])
    return nil;
  return self;
}

@end
