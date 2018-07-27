//  MyImageView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.

//The view in which the latex image is displayed is a little tuned. It knows its document
//and stores the full pdfdata (that may contain meta-data like keywords, creator...)
//Moreover, it supports drag'n drop

#import "MyImageView.h"

#import "AppController.h"
#import "HistoryItem.h"
#import "HistoryManager.h"
#import "LatexProcessor.h"
#import "LibraryFile.h"
#import "LibraryManager.h"
#import "MyDocument.h"
#import "NSApplicationExtended.h"
#import "NSAttributedStringExtended.h"
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

#import "rects.h"

//responds to a copy event, even if the Command-C was triggered in another view (like the library view)
NSString* CopyCurrentImageNotification = @"CopyCurrentImageNotification";
NSString* ImageDidChangeNotification = @"ImageDidChangeNotification";

@interface MyImageView (PrivateAPI)
-(void) _writeToPasteboard:(NSPasteboard*)pasteboard isLinkBackRefresh:(BOOL)isLinkBackRefresh lazyDataProvider:(id)lazyDataProvider;
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
    [NSArray arrayWithObjects:NSColorPboardType, NSPDFPboardType, NSFilenamesPboardType, NSFileContentsPboardType,
                              NSRTFDPboardType, nil]];
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
  NSColor* greyLevelColor = newColor ? [newColor colorUsingColorSpaceName:NSCalibratedWhiteColorSpace] : [NSColor whiteColor];
  backgroundColor = ([greyLevelColor whiteComponent] == 1.0f) ? nil : [newColor retain];
  //NSColor* colorFromUserDefaults = [NSColor colorWithData:[[NSUserDefaults standardUserDefaults] dataForKey:DefaultImageViewBackgroundKey]];
  //if (!backgroundColor && ![newColor isRGBEqualTo:colorFromUserDefaults])
  //  backgroundColor = [colorFromUserDefaults retain];
    
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
    handlesEvent = ((character == 'T') && ([theEvent modifierFlags] & NSCommandKeyMask)) ||
                   ((character == 'T') && ([theEvent modifierFlags] & NSCommandKeyMask) && ([theEvent modifierFlags] & NSShiftKeyMask)) ||
                   ((character == 'L') && ([theEvent modifierFlags] & NSCommandKeyMask) && ([theEvent modifierFlags] & NSShiftKeyMask));
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
  if (!image && pdfData)
  {
    NSPDFImageRep* pdfImageRep = [[NSPDFImageRep alloc] initWithData:pdfData];
    image = [[NSImage alloc] initWithSize:[pdfImageRep size]];
    [image setCacheMode:NSImageCacheNever];
    [image setDataRetained:YES];
    [image setScalesWhenResized:YES];
    [image addRepresentation:pdfImageRep];
    [pdfImageRep release];

    /*image = [[[NSImage alloc] initWithData:pdfData] autorelease];
    [image setCacheMode:NSImageCacheNever];
    [image setDataRetained:YES];
    [image recache];*/
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
    [self _writeToPasteboard:[link pasteboard] isLinkBackRefresh:YES lazyDataProvider:self];
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
  if ([theEvent modifierFlags] & NSControlKeyMask)
    [super mouseDown:theEvent];
  else
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
  
  [self _writeToPasteboard:pasteboard isLinkBackRefresh:NO lazyDataProvider:self];

  [super dragImage:draggedImage at:p offset:offset event:event pasteboard:pasteboard source:object slideBack:YES];
}


-(void) concludeDragOperation:(id <NSDraggingInfo>)sender
{
  //overwritten to avoid some strange additional "setImage" that would occur...
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
    NSData* data   = [[AppController appController] dataForType:exportFormat pdfData:pdfData jpegColor:color jpegQuality:quality
                                                 scaleAsPercent:[userDefaults floatForKey:DragExportScaleAsPercentKey]];

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
        [[NSWorkspace sharedWorkspace] setIcon:[LatexProcessor makeIconForData:pdfData backgroundColor:jpegBackgroundColor]
                                       forFile:filePath options:options];
        [names addObject:fileName];
      }
    }
  }
  return names;
}

-(void) _writeToPasteboard:(NSPasteboard*)pasteboard isLinkBackRefresh:(BOOL)isLinkBackRefresh lazyDataProvider:(id)lazyDataProvider
{
  HistoryItem* historyItem = [document historyItemWithCurrentState];
  [pasteboard addTypes:[NSArray arrayWithObject:HistoryItemsPboardType] owner:self];
  [pasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:[NSArray arrayWithObject:historyItem]] forType:HistoryItemsPboardType];
  [historyItem writeToPasteboard:pasteboard isLinkBackRefresh:isLinkBackRefresh lazyDataProvider:lazyDataProvider];
}

//provides lazy data to a pasteboard
-(void) pasteboard:(NSPasteboard *)pasteboard provideDataForType:(NSString *)type
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSData* data = [[AppController appController] dataForType:[userDefaults integerForKey:DragExportTypeKey] pdfData:pdfData
                                                  jpegColor:[NSColor colorWithData:[userDefaults objectForKey:DragExportJpegColorKey]]
                                                jpegQuality:[userDefaults floatForKey:DragExportJpegQualityKey]
                                             scaleAsPercent:[userDefaults floatForKey:DragExportScaleAsPercentKey]];
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
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:@"com.adobe.pdf"]])
  {
    shouldBePDFData = YES;
    data = [pboard dataForType:@"com.adobe.pdf"];
  }
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSFileContentsPboardType]])
  {
    shouldBePDFData = YES;
    data = [pboard dataForType:NSFileContentsPboardType];
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
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSRTFDPboardType]])
  {
    NSData* rtfdData = [pboard dataForType:NSRTFDPboardType];
    NSDictionary* docAttributes = nil;
    NSAttributedString* attributedString = [[NSAttributedString alloc] initWithRTFD:rtfdData documentAttributes:&docAttributes];
    NSDictionary* pdfAttachments = [attributedString attachmentsOfType:@"pdf" docAttributes:docAttributes];
    NSData* pdfWrapperData = [pdfAttachments count] ? [[[pdfAttachments objectEnumerator] nextObject] regularFileContents] : nil;
    [attributedString release];
    ok = (pdfWrapperData != nil);
  }
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:@"com.apple.flat-rtfd"]])
  {
    NSData* rtfdData = [pboard dataForType:@"com.apple.flat-rtfd"];
    NSDictionary* docAttributes = nil;
    NSAttributedString* attributedString = [[NSAttributedString alloc] initWithRTFD:rtfdData documentAttributes:&docAttributes];
    NSDictionary* pdfAttachments = [attributedString attachmentsOfType:@"pdf" docAttributes:docAttributes];
    NSData* pdfWrapperData = [pdfAttachments count] ? [[[pdfAttachments objectEnumerator] nextObject] regularFileContents] : nil;
    [attributedString release];
    ok = (pdfWrapperData != nil);
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

-(BOOL) validateMenuItem:(id)sender
{
  BOOL ok = YES;
  if ([sender tag] == -1)//default
  {
    export_format_t exportFormat = (export_format_t)[[NSUserDefaults standardUserDefaults] integerForKey:DragExportTypeKey];
    [sender setTitle:[NSString stringWithFormat:@"%@ (%@)",
      NSLocalizedString(@"Default Format", @"Default Format"),
      [[AppController appController] nameOfType:exportFormat]]];
  }
  if ([sender tag] == EXPORT_FORMAT_EPS)
    ok = [[AppController appController] isGsAvailable];
  else if ([sender tag] == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
    ok = [[AppController appController] isGsAvailable] && [[AppController appController] isPs2PdfAvailable];
  if ([sender action] == @selector(copy:))
    ok = ok && ([self image] != nil);
  return ok;
}

-(IBAction) copy:(id)sender
{
  int tag = sender ? [sender tag] : -1;
  export_format_t exportFormat = (export_format_t)
                                    ((tag == -1) ? [[NSUserDefaults standardUserDefaults] integerForKey:DragExportTypeKey]
                                                 : tag);
  [self copyAsFormat:exportFormat];
}

-(void) copyAsFormat:(export_format_t)exportFormat
{
  NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard declareTypes:[NSArray array] owner:self];
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  export_format_t savExportFormat = [userDefaults integerForKey:DragExportTypeKey];
  [userDefaults setInteger:exportFormat forKey:DragExportTypeKey];
  //lazyDataProvider to nil to force immediate computation of the pdf with outlined fonts
  [self _writeToPasteboard:pasteboard isLinkBackRefresh:NO lazyDataProvider:nil];
  [userDefaults setInteger:savExportFormat forKey:DragExportTypeKey];
}

//In my opinion, this paste: is triggered only programmatically from the paste: of LineCountTextView
-(IBAction) paste:(id)sender
{
  [self _applyDataFromPasteboard:[NSPasteboard generalPasteboard]];
}
//end paste:

-(BOOL) _applyDataFromPasteboard:(NSPasteboard*)pboard
{
  BOOL ok = YES;
  NSString* type = nil;
  BOOL done = NO;
  if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSColorPboardType]]))
  {
    [self setBackgroundColor:[NSColor colorWithData:[pboard dataForType:type]] updateHistoryItem:YES];
    done = YES;
  }
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:LibraryItemsPboardType]]))
  {
    NSArray* libraryItemsArray = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:type]];
    unsigned int count = [libraryItemsArray count];
    LibraryFile* libraryFile = nil;
    while(count-- && !libraryFile)
      libraryFile = [[libraryItemsArray objectAtIndex:count] isKindOfClass:[LibraryFile class]] ? [libraryItemsArray objectAtIndex:count] : nil;
    if (libraryFile)
      [document applyLibraryFile:libraryFile];
    done = YES;
  }
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:HistoryItemsPboardType]]))
  {
    NSArray* historyItemsArray = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:type]];
    [document applyHistoryItem:[historyItemsArray lastObject]];
    done = YES;
  }
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"com.adobe.pdf", NSPDFPboardType, nil]]))
    done = [document applyPdfData:[pboard dataForType:type]];
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFileContentsPboardType]]))
    done = [document applyPdfData:[pboard dataForType:type]];
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]]))
  {
    NSArray* plist = [pboard propertyListForType:type];
    NSData* data = (plist && [plist count]) ? [NSData dataWithContentsOfFile:[plist objectAtIndex:0]] : nil;
    done = [document applyPdfData:data];
  }
  
  if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"com.apple.flat-rtfd", NSRTFDPboardType, nil]])))
  {
    NSData* rtfdData = [pboard dataForType:type];
    NSDictionary* docAttributes = nil;
    NSAttributedString* attributedString = [[NSAttributedString alloc] initWithRTFD:rtfdData documentAttributes:&docAttributes];
    NSDictionary* pdfAttachments = [attributedString attachmentsOfType:@"pdf" docAttributes:docAttributes];
    NSData* pdfWrapperData = [pdfAttachments count] ? [[[pdfAttachments objectEnumerator] nextObject] regularFileContents] : nil;
    if (pdfWrapperData)
      done = [document applyPdfData:pdfWrapperData];
    if (!done)
      [document applyString:[attributedString string]];
    [attributedString release];
    done = YES;
  }
  else if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"public.rtf", NSRTFPboardType, nil]])))
  {
    NSData* rtfData = [pboard dataForType:type];
    NSDictionary* docAttributes = nil;
    NSAttributedString* attributedString = [[NSAttributedString alloc] initWithRTF:rtfData documentAttributes:&docAttributes];
    [document applyString:[attributedString string]];
    [attributedString release];
    done = YES;
  }
  else if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"public.text", NSStringPboardType, nil]])))
  {
    [document applyString:[pboard stringForType:type]];
    done = YES;
  }
  else if (!done)
    ok = NO;
  return ok;
}

-(void) _copyCurrentImageNotification:(NSNotification*)notification
{
  [self copy:self];
}

-(void) drawRect:(NSRect)rect
{
  NSRect bounds = [self bounds];
  NSRect inRoundedRect1 = NSInsetRect(bounds, 1, 1);
  NSRect inRoundedRect2 = NSInsetRect(bounds, 2, 2);
  NSRect inRoundedRect3 = NSInsetRect(bounds, 3, 3);
  NSRect inRect = NSInsetRect(bounds, 7, 7);
  CGContextRef cgContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
  CGContextSetRGBFillColor(cgContext, 0.95f, 0.95f, 0.95f, 1.0f);
  fillRoundedRect(cgContext, *((CGRect*)&inRoundedRect1), 2.f, 2.f);
  CGContextSetRGBStrokeColor(cgContext, 0.68f, 0.68f, 0.68f, 1.f);
  mystrokeRoundedRect(cgContext, *((CGRect*)&inRoundedRect3), 2.f, 2.f);
  CGContextSetRGBStrokeColor(cgContext, 0.95f, 0.95f, 0.95f, 1.0f);
  mystrokeRoundedRect(cgContext, *((CGRect*)&inRoundedRect1), 2.f, 2.f);
  CGContextSetRGBStrokeColor(cgContext, 0.95f, 0.95f, 0.95f, 1.0f);
  mystrokeRoundedRect(cgContext, *((CGRect*)&inRoundedRect2), 2.f, 2.f);

  NSImage* image = [self image];
  NSSize naturalImageSize = image ? [image size] : NSZeroSize;
  float factor = exp(3*([zoomSlider floatValue]-1));
  NSSize newSize = naturalImageSize;
  newSize.width *= factor;
  newSize.height *= factor;

  NSRect destRect = NSMakeRect(0, 0, newSize.width, newSize.height);
  float factorX = (destRect.size.width  > inRect.size.width)  ? inRect.size.width /destRect.size.width  : 1;
  destRect.size.width  *= factorX;
  destRect.size.height *= factorX;
  float factorY = (destRect.size.height > inRect.size.height) ? inRect.size.height/destRect.size.height : 1;
  destRect.size.width  *= factorY;
  destRect.size.height *= factorY;
  destRect.origin.x = inRect.origin.x+inRect.size.width /2-destRect.size.width /2;
  destRect.origin.y = inRect.origin.y+inRect.size.height/2-destRect.size.height/2;

  if (backgroundColor)
  {
    [backgroundColor set];
    NSRectFill(inRect);
  }
  [image drawInRect:destRect fromRect:NSMakeRect(0, 0, naturalImageSize.width, naturalImageSize.height)  operation:NSCompositeSourceOver fraction:1.0];
}
//end drawRect:

@end
