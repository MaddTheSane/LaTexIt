//  MyImageView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//The view in which the latex image is displayed is a little tuned. It knows its document
//and stores the full pdfdata (that may contain meta-data like keywords, creator...)
//Moreover, it supports drag'n drop

#import "MyImageView.h"

#import "AppController.h"
#import "HistoryItem.h"
#import "HistoryManager.h"
#import "LibraryManager.h"
#import "MyDocument.h"
#import "NSApplicationExtended.h"
#import "NSColorExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"

#ifdef PANTHER
#import <LinkBack-panther/LinkBack.h>
#else
#import <LinkBack/LinkBack.h>
#endif

#ifndef PANTHER
#import <Quartz/Quartz.h>
#endif

//responds to a copy event, even if the Command-C was triggered in another view (like the library view)
NSString* CopyCurrentImageNotification = @"CopyCurrentImageNotification";
NSString* ImageDidChangeNotification = @"ImageDidChangeNotification";

@interface MyImageView (PrivateAPI)
-(void) _writeToPasteboard:(NSPasteboard*)pasteboard isLinkBackRefresh:(BOOL)isLinkBackRefresh;
-(void) _copyCurrentImageNotification:(NSNotification*)notification;
-(BOOL) _applyDataFromPasteboard:(NSPasteboard*)pboard;
@end

@implementation MyImageView

-(id) initWithCoder:(NSCoder*)coder
{
  if (![super initWithCoder:coder])
    return nil;
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_copyCurrentImageNotification:)
                                               name:CopyCurrentImageNotification object:nil];
  [self registerForDraggedTypes:
    [NSArray arrayWithObjects:NSColorPboardType, NSPDFPboardType, NSFilenamesPboardType, NSFileContentsPboardType, nil]];
  return self;
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [backgroundColor release];
  [super dealloc];
}

-(BOOL) acceptsFirstMouse:(NSEvent*)theEvent//we can start a drag without selecting the window first
{
  return YES;
}

-(NSColor*) backgroundColor
{
  return backgroundColor;
}

-(void) setBackgroundColor:(NSColor*)newColor updateHistoryItem:(BOOL)updateHistoryItem
{
  //we remove the background color if it is set to white. Useful for the history table view alternating white/blue rows
  [backgroundColor autorelease];
  NSColor* greyLevelColor = [newColor colorUsingColorSpaceName:NSCalibratedWhiteColorSpace];
  backgroundColor = ([greyLevelColor whiteComponent] == 1.0f) ? nil : [newColor retain];
  [self setNeedsDisplay:YES];
  if (updateHistoryItem && pdfData)
    [self setPDFData:[[document historyItemWithCurrentState] annotatedPDFDataUsingPDFKeywords:YES] cachedImage:[self image]];
}

//zooms the image, but does not modify it (drag'n drop will be with original image size)
-(IBAction) zoom:(id)sender
{
  [self setNeedsDisplay:YES];
}

//used to trigger latexisation using Command-T
-(BOOL) performKeyEquivalent:(NSEvent *)theEvent
{
  BOOL handlesEvent = NO;
  NSString* charactersIgnoringModifiers = [theEvent charactersIgnoringModifiers];
  if ([charactersIgnoringModifiers length])
  {
    unichar character = [charactersIgnoringModifiers characterAtIndex:0];
    handlesEvent = ((character == 'T') && ([theEvent modifierFlags] & NSCommandKeyMask));
    if (handlesEvent)
      [[document makeLatexButton] performClick:self];
  }
  return handlesEvent;
}

-(NSData*) pdfData //full pdfdata (that may contain meta-data like keywords, creator...)
{
  return pdfData;
}

//when you set the pdfData encapsulated by the imageView, it creates an NSImage with this data.
//but if you specify a non-nil cachedImage, it will use this cachedImage to be faster
//the data is full pdfdata (that may contain meta-data like keywords, creator...)
-(void) setPDFData:(NSData*)someData cachedImage:(NSImage*)cachedImage
{
  [someData retain];
  [pdfData release];
  pdfData = someData;
  NSImage* image = cachedImage;
  if (!image)
  {
    image = [[[NSImage alloc] initWithData:pdfData] autorelease];
    [image setCacheMode:NSImageCacheNever];
    [image setDataRetained:YES];
    [image recache];
  }
  [self setImage:image];
}

-(void) setImage:(NSImage*)image
{
  [image setScalesWhenResized:YES];
  [super setImage:image];
  [self zoom:zoomSlider];
  [[NSNotificationCenter defaultCenter] postNotificationName:ImageDidChangeNotification object:self];
}

//used to update the pasteboard content for a live Linkback link
-(void) updateLinkBackLink:(LinkBack*)link
{
  //may update linkback link
  if (pdfData && link)
  {
    [self _writeToPasteboard:[link pasteboard] isLinkBackRefresh:YES];
    [link sendEdit];
  }
}

-(unsigned int) draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  return [self image] ? NSDragOperationCopy : NSDragOperationNone;
}

//begins a drag operation
-(void) mouseDown:(NSEvent*)theEvent
{
  NSImage* draggedImage = [self image];

  if (draggedImage)
  {
    //NSPasteboard* pasteboard = [NSPasteboard pasteboardWithName:NSDragPboard];
    //[pasteboard declareTypes:[NSArray arrayWithObject:NSFilesPromisePboardType] owner:self];
    [self dragPromisedFilesOfTypes:[NSArray arrayWithObjects:@"pdf", @"eps", @"tiff", @"jpeg", @"png", nil]
                          fromRect:[self frame] source:self slideBack:YES event:theEvent];
  }
}

-(void) dragImage:(NSImage*)image at:(NSPoint)at offset:(NSSize)offset event:(NSEvent*)event
       pasteboard:(NSPasteboard*)pasteboard source:(id)object slideBack:(BOOL)slideBack
{
  NSImage* draggedImage = [self image];
  NSImage* iconDragged = draggedImage;
  NSSize   iconSize = [iconDragged size];
  NSPoint p = [self convertPoint:[event locationInWindow] fromView:nil];
  p.x -= iconSize.width/2;
  p.y -= iconSize.height/2;
  
  [self _writeToPasteboard:pasteboard isLinkBackRefresh:NO];

  [super dragImage:draggedImage at:p offset:offset event:event pasteboard:pasteboard source:object slideBack:YES];
}

//creates the promised file of the drag
-(NSArray*) namesOfPromisedFilesDroppedAtDestination:(NSURL*)dropDestination
{
  NSMutableArray* names = [NSMutableArray arrayWithCapacity:1];
  if (pdfData)
  {
    NSString* dropPath = [dropDestination path];
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSString* filePrefix = @"latex-image";
    
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    export_format_t exportFormat = [userDefaults integerForKey:DragExportTypeKey];
    NSString* extension = nil;
    switch(exportFormat)
    {
      case EXPORT_FORMAT_PDF:
      case EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS:
        extension = @"pdf";
        break;
      case EXPORT_FORMAT_EPS:
        extension = @"eps";
        break;
      case EXPORT_FORMAT_TIFF:
        extension = @"tiff";
        break;
      case EXPORT_FORMAT_PNG:
        extension = @"png";
        break;
      case EXPORT_FORMAT_JPEG:
        extension = @"jpeg";
        break;
    }

    NSColor* color = [NSColor colorWithData:[userDefaults objectForKey:DragExportJpegColorKey]];
    float  quality = [userDefaults floatForKey:DragExportJpegQualityKey];
    NSData* data   = [[AppController appController] dataForType:exportFormat pdfData:pdfData jpegColor:color jpegQuality:quality];

    if (extension)
    {
      NSString* fileName = nil;
      NSString* filePath = nil;
      unsigned long i = 1;
      //we try to compute a name that is not already in use
      do
      {
        fileName = [NSString stringWithFormat:@"%@-%u.%@", filePrefix, i++, extension];
        filePath = [dropPath stringByAppendingPathComponent:fileName];
      } while (i && [fileManager fileExistsAtPath:filePath]);
      
      //if we find such a name, use it
      if (![fileManager fileExistsAtPath:filePath])
      {
        [fileManager createFileAtPath:filePath contents:data attributes:nil];
        [fileManager changeFileAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:'LTXt'] forKey:NSFileHFSCreatorCode]
                                   atPath:filePath];
        unsigned int options = 0;
        #ifndef PANTHER
        options = NSExclude10_4ElementsIconCreationOption;
        #endif
        NSColor* jpegBackgroundColor = (exportFormat == EXPORT_FORMAT_JPEG) ? color : nil;
        [[NSWorkspace sharedWorkspace] setIcon:[[AppController appController] makeIconForData:pdfData backgroundColor:jpegBackgroundColor]
                                       forFile:filePath options:options];
        [names addObject:fileName];
      }
    }
  }
  return names;
}

-(void) _writeToPasteboard:(NSPasteboard*)pasteboard isLinkBackRefresh:(BOOL)isLinkBackRefresh
{
  HistoryItem* historyItem = [document historyItemWithCurrentState];
  [pasteboard addTypes:[NSArray arrayWithObject:HistoryItemsPboardType] owner:self];
  [pasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:[NSArray arrayWithObject:historyItem]] forType:HistoryItemsPboardType];
  [historyItem writeToPasteboard:pasteboard forDocument:document isLinkBackRefresh:isLinkBackRefresh lazyDataProvider:self];
}

//provides lazy data to a pasteboard
-(void) pasteboard:(NSPasteboard *)pasteboard provideDataForType:(NSString *)type
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSData* data = [[AppController appController] dataForType:[userDefaults integerForKey:DragExportTypeKey] pdfData:pdfData
                                                  jpegColor:[NSColor colorWithData:[userDefaults objectForKey:DragExportJpegColorKey]]
                                                jpegQuality:[userDefaults floatForKey:DragExportJpegQualityKey]];
  [pasteboard setData:data forType:type];
}

//We can drop on the imageView only if the PDF has been made by LaTeXiT (as "creator" document attribute)
//So, the keywords of the PDF contain the whole document state
-(NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
  BOOL ok = NO;
  BOOL shouldBePDFData = NO;
  NSData* data = nil;
  
  NSPasteboard* pboard = [sender draggingPasteboard];
  if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSColorPboardType]])
    ok = YES;
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSPDFPboardType]])
  {
    shouldBePDFData = YES;
    data = [pboard dataForType:NSPDFPboardType];
  }
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSFileContentsPboardType]])
  {
    shouldBePDFData = YES;
    data = [pboard dataForType:NSPDFPboardType];
  }
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]])
  {
    shouldBePDFData = YES;
    NSArray* plist = [pboard propertyListForType:NSFilenamesPboardType];
    if (plist && [plist count])
    {
      NSString* filename = [plist objectAtIndex:0];
      //on Panther, we rely on the extension to see if it is valid pdf. On Tiger, we will use PDFDocument
      #ifdef PANTHER
      if ([[[filename pathExtension] lowercaseString] isEqualToString:@"pdf"])
      #endif
      data = [NSData dataWithContentsOfFile:filename];
    }
  }
  
  if (shouldBePDFData)
  {
    ok = (data != nil);
    #ifndef PANTHER
    if (ok)
    {
      PDFDocument* pdfDocument = [[PDFDocument alloc] initWithData:data];
      ok &= (pdfDocument != nil);
      [pdfDocument release];
    }
    #endif
  }

  return ok ? NSDragOperationCopy : NSDragOperationNone;
}

//this fixes a bug of panther http://lists.apple.com/archives/cocoa-dev/2005/Jan/msg02129.html
#ifdef PANTHER
-(void) draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
  [[NSPasteboard pasteboardWithName:NSDragPboard] declareTypes:nil owner:nil];
}
#endif

-(BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
  return [self _applyDataFromPasteboard:[sender draggingPasteboard]];
}

-(IBAction) copy:(id)sender
{
  NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard declareTypes:[NSArray array] owner:self];
  [self _writeToPasteboard:pasteboard isLinkBackRefresh:NO];
}

//In my opinion, this paste: is triggered only programmatically from the paste: of LineCountTextView
-(IBAction) paste:(id)sender
{
  [self _applyDataFromPasteboard:[NSPasteboard generalPasteboard]];
}

-(BOOL) _applyDataFromPasteboard:(NSPasteboard*)pboard
{
  BOOL ok = YES;
  if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSColorPboardType]])
    [self setBackgroundColor:[NSColor colorWithData:[pboard dataForType:NSColorPboardType]] updateHistoryItem:YES];
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:LibraryItemsPboardType]])
  {
    NSArray* libraryItemsArray = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:LibraryItemsPboardType]];
    [document applyHistoryItem:(HistoryItem*)[[libraryItemsArray lastObject] value]];
  }
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:HistoryItemsPboardType]])
  {
    NSArray* historyItemsArray = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:HistoryItemsPboardType]];
    [document applyHistoryItem:[historyItemsArray lastObject]];
  }
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSPDFPboardType]])
    [document applyPdfData:[pboard dataForType:NSPDFPboardType]];
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSFileContentsPboardType]])
    [document applyPdfData:[pboard dataForType:NSFileContentsPboardType]];
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]])
  {
    NSArray* plist = [pboard propertyListForType:NSFilenamesPboardType];
    NSData* data = (plist && [plist count]) ? [NSData dataWithContentsOfFile:[plist objectAtIndex:0]] : nil;
    [document applyPdfData:data];
  }
  else
    ok = NO;
  return ok;
}

-(void) _copyCurrentImageNotification:(NSNotification*)notification
{
  [self copy:self];
}

-(void) drawRect:(NSRect)rect
{
  //we very temporaryly change the image size, just for drawing
  //it is not done permanently in setImage:,  for two reasons:
  //  -we should not modify here the images stored in the history items, this is not what we want
  //  -if we work on copy of images from history items, the requires some time, to copy the image, each time
  //   the history selection changes (and it is rather long when browsing the whole history)
  
  NSImage* image = [self image];
  NSSize naturalImageSize = image ? [image size] : NSMakeSize(0, 0);
  float factor = exp(3*([zoomSlider floatValue]-1));
  NSSize newSize = naturalImageSize;
  newSize.width *= factor;
  newSize.height *= factor;
  NSSize viewSize = [self frame].size;
    
  //if is useless to get a newSize greater than the imageView size
  if (newSize.height > viewSize.height)
    newSize = NSMakeSize((viewSize.height/newSize.height)*newSize.width, viewSize.height);
  if (newSize.width > viewSize.width)
    newSize = NSMakeSize(viewSize.width, (viewSize.width/newSize.width)*newSize.height);

  [image setSize:newSize];
  if (backgroundColor)
  {
    [backgroundColor set];
    NSRect bounds = [self bounds];
    NSRectFill(NSMakeRect(bounds.origin.x+5, bounds.origin.y+5, bounds.size.width-10, bounds.size.height-10));
  }
  [super drawRect:rect];
  [image setSize:naturalImageSize];
}

@end
