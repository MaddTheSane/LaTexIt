//  MyImageView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.

//The view in which the latex image is displayed is a little tuned. It knows its document
//and stores the full pdfdata (that may contain meta-data like keywords, creator...)
//Moreover, it supports drag'n drop

#import "MyImageView.h"

#import "AppController.h"
#import "CHDragFileWrapper.h"
#import "CHExportPrefetcher.h"
#import "CHProtoBuffers.h"
#import "DragFilterWindow.h"
#import "DragFilterWindowController.h"
#import "HistoryItem.h"
#import "HistoryManager.h"
#import "LatexitEquation.h"
#import "LaTeXProcessor.h"
#import "LibraryEquation.h"
#import "LibraryManager.h"
#import "MyDocument.h"
#import "NSAttributedStringExtended.h"
#import "NSColorExtended.h"
#import "NSFileManagerExtended.h"
#import "NSImageExtended.h"
#import "NSManagedObjectContextExtended.h"
#import "NSMutableArrayExtended.h"
#import "NSMenuExtended.h"
#import "NSObjectExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"
#import "RegexKitLite.h"
#import "Utils.h"
#import "LineCountTextView.h"

#import "CGExtras.h"

#import <LinkBack/LinkBack.h>
#import <Quartz/Quartz.h>

//static inline CGFloat frac(CGFloat x) {return x-floor(x);}
//static inline CGFloat sqr(CGFloat x) {return x*x;}

//responds to a copy event, even if the Command-C was triggered in another view (like the library view)
NSString* CopyCurrentImageNotification = @"CopyCurrentImageNotification";
NSString* ImageDidChangeNotification = @"ImageDidChangeNotification";

@interface TransparentView : NSView
@end
@implementation TransparentView
-(BOOL) acceptsFirstMouse:(NSEvent *)theEvent {return NO;}
-(BOOL) acceptsFirstResponder {return NO;}
-(BOOL) becomeFirstResponder {return NO;}
-(NSView*) hitTest:(NSPoint)aPoint {return nil;}
@end


@interface MyImageView ()
-(NSImage*) imageForDrag;
-(NSMenu*) lazyCopyAsContextualMenu;
-(void) _writeToPasteboard:(NSPasteboard*)pasteboard exportFormat:(export_format_t)exportFormat isLinkBackRefresh:(BOOL)isLinkBackRefresh lazyDataProvider:(id)lazyDataProvider;
-(void) _copyCurrentImageNotification:(NSNotification*)notification;
-(BOOL) _applyDataFromPasteboard:(NSPasteboard*)pboard sender:(id <NSDraggingInfo>)sender;
-(void) performProgrammaticDragCancellation:(id)context;
-(void) performProgrammaticRedrag:(id)context;
@end

@implementation MyImageView

-(id) initWithCoder:(NSCoder*)coder
{
  if ((!(self = [super initWithCoder:coder])))
    return nil;
  self->zoomLevel = 1.f;
  [self lazyCopyAsContextualMenu];
  [self setMenu:self->copyAsContextualMenu];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_copyCurrentImageNotification:)
                                               name:CopyCurrentImageNotification object:nil];
  [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:DefaultDoNotClipPreviewKey options:NSKeyValueObservingOptionNew context:nil];
  [self registerForDraggedTypes:
    [NSArray arrayWithObjects:NSColorPboardType, NSPDFPboardType,
                              NSFilenamesPboardType, NSFileContentsPboardType, NSFilesPromisePboardType,
                              NSRTFDPboardType, NSRTFPboardType, GetWebURLsWithTitlesPboardType(), NSStringPboardType,
                              @"com.adobe.pdf", @"public.tiff", @"public.png", @"public.jpeg", @"public.svg-image",
                              @"public.html",
                              //@"com.apple.iWork.TSPNativeMetadata",
                              nil]];
  return self;
}
//end initWithCoder:

-(void) dealloc
{
  [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:DefaultDoNotClipPreviewKey];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self->copyAsContextualMenu release];
  [self->backgroundColor release];
  [self->imageRep release];
  [self->transientFilesPromisedFilePaths release];
  [self->transientDragData release];
  [self->transientDragEquation release];
  [self->layerView release];
  [self->layerArrows release];
  [super dealloc];
}
//end dealloc

-(void) awakeFromNib
{
}
//end awakeFromNib

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  if ([keyPath isEqualToString:DefaultDoNotClipPreviewKey])
  {
    [self updateViewSize];
    [self setNeedsDisplay:YES];
  }//end if ([keyPath isEqualToString:DefaultDoNotClipPreviewKey])
}
//end observeValueForKeyPath:ofObject:change:context:

-(BOOL) acceptsFirstMouse:(NSEvent*)theEvent//we can start a drag without selecting the window first
{
  return YES;
}
//end acceptsFirstMouse

-(NSMenu*) lazyCopyAsContextualMenu
{
  //connect contextual copy As menu to imageView
  NSMenu* result = self->copyAsContextualMenu;
  if (!result)
  {
    self->copyAsContextualMenu = [[NSMenu alloc] init];
    NSMenuItem* superItem =
      [self->copyAsContextualMenu addItemWithTitle:NSLocalizedString(@"Copy the image as", @"Copy the image as") action:nil keyEquivalent:@""];
    NSMenu* subMenu = [[NSMenu alloc] init];
    [subMenu addItemWithTitle:NSLocalizedString(@"Default Format", @"Default Format") target:self action:@selector(copy:)
                keyEquivalent:@"c" keyEquivalentModifierMask:NSCommandKeyMask|NSAlternateKeyMask tag:-1];
    [subMenu addItem:[NSMenuItem separatorItem]];
    [subMenu addItemWithTitle:@"PDF" target:self action:@selector(copy:) keyEquivalent:@"" keyEquivalentModifierMask:0
                          tag:(int)EXPORT_FORMAT_PDF];
    [subMenu addItemWithTitle:NSLocalizedString(@"PDF with outlined fonts", @"PDF with outlined fonts") target:self action:@selector(copy:)
                keyEquivalent:@"c" keyEquivalentModifierMask:NSCommandKeyMask|NSShiftKeyMask|NSAlternateKeyMask
                          tag:(int)EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS];
    [subMenu addItemWithTitle:@"EPS" target:self action:@selector(copy:) keyEquivalent:@"" keyEquivalentModifierMask:0
                          tag:(int)EXPORT_FORMAT_EPS];
    [subMenu addItemWithTitle:@"TIFF" target:self action:@selector(copy:) keyEquivalent:@"" keyEquivalentModifierMask:0
                          tag:(int)EXPORT_FORMAT_TIFF];
    [subMenu addItemWithTitle:@"PNG" target:self action:@selector(copy:) keyEquivalent:@"" keyEquivalentModifierMask:0
                          tag:(int)EXPORT_FORMAT_PNG];
    [subMenu addItemWithTitle:@"JPEG" target:self action:@selector(copy:) keyEquivalent:@"" keyEquivalentModifierMask:0
                          tag:(int)EXPORT_FORMAT_JPEG];
    [self->copyAsContextualMenu setSubmenu:subMenu forItem:superItem];
    [subMenu release];
    result = self->copyAsContextualMenu;
  }//end if (!result)
  return result;
}
//end lazyCopyAsContextualMenu

-(CGFloat) zoomLevel
{
  return self->zoomLevel;
}
//end zoomLevel

-(void) setZoomLevel:(CGFloat)value
{
  if (self->zoomLevel != value)
  {
    self->zoomLevel = value;
    [self updateViewSize];
    [self setNeedsDisplay:YES];
  }//end if (self->zoomLevel != value)
}
//end setZoomLevel:

-(NSColor*) backgroundColor
{
  return self->backgroundColor;
}
//end backgroundColor:

-(void) setBackgroundColor:(NSColor*)newColor updateHistoryItem:(BOOL)updateHistoryItem
{
  //we remove the background color if it is set to white. Useful for the history table view alternating white/blue rows
  [self->backgroundColor autorelease];
  NSColor* greyLevelColor = newColor ? [newColor colorUsingColorSpaceName:NSCalibratedWhiteColorSpace] : [NSColor whiteColor];
  self->backgroundColor = ([greyLevelColor whiteComponent] == 1.0f) ? nil : [newColor retain];

  [self setNeedsDisplay:YES];
  if (updateHistoryItem && self->pdfData)
    [self setPDFData:[[self->document latexitEquationWithCurrentStateTransient:NO] annotatedPDFDataUsingPDFKeywords:YES] cachedImage:[self image]];
}
//end setBackgroundColor:updateHistoryItem:

//used to trigger latexisation using Command-T
-(BOOL) performKeyEquivalent:(NSEvent*)theEvent
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
      [[self->document lowerBoxLatexizeButton] performClick:self];
  }
  return handlesEvent;
}
//end performKeyEquivalent:

-(NSData*) pdfData //full pdfdata (that may contain meta-data like keywords, creator...)
{
  return self->pdfData;
}
//end pdfData:

-(NSSize) naturalPDFSize
{
  return self->naturalPDFSize;
}
//end naturalPDFSize

//when you set the pdfData encapsulated by the imageView, it creates an NSImage with this data.
//but if you specify a non-nil cachedImage, it will use this cachedImage to be faster
//the data is full pdfdata (that may contain meta-data like keywords, creator...)
-(void) setPDFData:(NSData*)someData cachedImage:(NSImage*)cachedImage
{
  [self->transientDragData release];
  self->transientDragData = nil;
  [self->transientDragEquation release];
  self->transientDragEquation = nil;

  [someData retain];
  [self->pdfData release];
  self->pdfData = someData;

  [self->imageRep release];
  self->imageRep = !self->pdfData ? nil : [[NSPDFImageRep alloc] initWithData:self->pdfData];
  self->naturalPDFSize = !self->imageRep ? NSZeroSize : [self->imageRep size];
  NSImage* image = [[cachedImage copy] autorelease];
  [image removeRepresentationsOfClass:[NSBitmapImageRep class]];
  if (image && ![image pdfImageRepresentation] && self->imageRep)
  {
    [image setCacheMode:NSImageCacheNever];
    [image addRepresentation:self->imageRep];
    //[image recache];
  }//end if (image && ![image pdfImageRepresentation] && self->imageRep)
  else if (!image && self->imageRep)
  {
    image = [[[NSImage alloc] initWithSize:[self->imageRep size]] autorelease];
    [image setCacheMode:NSImageCacheNever];
    [image addRepresentation:self->imageRep];
    //[image recache];
  }//end if (!image && self->imageRep)
  [self setImage:image];
  [self updateViewSize];
}
//end setPDFData:cachedImage:

-(void) setImage:(NSImage*)image
{
  [super setImage:image];
  [[NSNotificationCenter defaultCenter] postNotificationName:ImageDidChangeNotification object:self];
}
//end setImage:

//used to update the pasteboard content for a live Linkback link
-(void) updateLinkBackLink:(LinkBack*)link
{
  //may update linkback link
  if (self->pdfData && link)
  {
    export_format_t exportFormat = [[PreferencesController sharedController] exportFormatPersistent];
    [self _writeToPasteboard:[link pasteboard] exportFormat:exportFormat isLinkBackRefresh:YES lazyDataProvider:self];
    @try{
      [link sendEdit];
    }
    @catch(NSException* e){
      NSAlert* alert = [NSAlert alertWithError:[NSError errorWithDomain:[e name] code:-1 userInfo:[e userInfo]]];
      [alert setInformativeText:[e reason]];
      [alert runModal];
    }
  }
}
//end updateLinkBackLink:

-(NSDragOperation) draggingSession:(NSDraggingSession*)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
  NSDragOperation result = [self image] ? NSDragOperationCopy : NSDragOperationNone;
  return result;
}
//end draggingSession:sourceOperationMaskForDraggingContext:

-(NSDragOperation) draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  NSDragOperation result = [self image] ? NSDragOperationCopy : NSDragOperationNone;
  return result;
}
//end draggingSourceOperationMaskForLocal:

-(void) keyDown:(NSEvent*)theEvent
{
  id previousFirstResponder = [self->document previousFirstResponder];
  if ([[self window] makeFirstResponder:previousFirstResponder])
  {
    if ([previousFirstResponder respondsToSelector:@selector(restorePreviousSelectedRangeLocation)])
      [previousFirstResponder performSelector:@selector(restorePreviousSelectedRangeLocation)];
    [previousFirstResponder keyDown:theEvent];
  }//end if ([[self window] makeFirstResponder:previousFirstResponder])
}
//end keyDown:

//begins a drag operation
-(void) mouseDown:(NSEvent*)theEvent
{
  if ([theEvent modifierFlags] & NSControlKeyMask)
    [super mouseDown:theEvent];
  else
    [super mouseDown:theEvent];
}
//end mouseDown:

-(void) mouseDragged:(NSEvent*)event
{
  if (!self->isDragging && !([event modifierFlags] & NSControlKeyMask))
  {
    NSImage* draggedImage = [self image];
    if (draggedImage)
    {
      self->isDragging = YES;
      [self->transientDragData release];
      self->transientDragData = nil;
      [self->transientDragEquation release];
      self->transientDragEquation = nil;
      [self dragPromisedFilesOfTypes:[NSArray arrayWithObjects:@"pdf", @"eps", @"svg", @"tiff", @"jpeg", @"png", @"html", nil]
                            fromRect:[self frame] source:self slideBack:YES event:event];
      self->isDragging = NO;
    }//end if (draggedImage)
  }//end if (!self->isDragging)
  [super mouseDragged:event];
}
//end mouseDragged:

-(void) mouseUp:(NSEvent*)theEvent
{
  self->isDragging = NO;
  [super mouseUp:theEvent];
}
//end mouseUp:

-(void) draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
  if (self->isDragging && !self->shouldRedrag)
  {
    [[[AppController appController] dragFilterWindowController] setWindowVisible:NO withAnimation:YES];
    [[[AppController appController] dragFilterWindowController] setDelegate:nil];
  }//end if (self->isDragging)
  self->isDragging = NO;
  if (self->shouldRedrag)
    [self performSelector:@selector(performProgrammaticRedrag:) withObject:nil afterDelay:0];
}
//end draggedImage:endedAt:operation:

-(void) dragImage:(NSImage*)image at:(NSPoint)at offset:(NSSize)offset event:(NSEvent*)event
       pasteboard:(NSPasteboard*)pasteboard source:(id)object slideBack:(BOOL)slideBack
{
  NSImage* iconDragged = [self imageForDrag];
  NSSize   iconSize = [iconDragged size];
  NSPoint p = [self convertPoint:[event locationInWindow] fromView:nil];

  if (self->shouldRedrag)
    [[[[AppController appController] dragFilterWindowController] window] setIgnoresMouseEvents:NO];
  if (!self->shouldRedrag)
  {
    self->lastDragStartPointSelfBased = p;
    [[[AppController appController] dragFilterWindowController] setWindowVisible:YES withAnimation:YES atPoint:
      [[self window] convertBaseToScreen:[event locationInWindow]]];
    [[[AppController appController] dragFilterWindowController] setDelegate:self];
  }//end if (!self->shouldRedrag)
  self->shouldRedrag = NO;

  export_format_t exportFormat = [[PreferencesController sharedController] exportFormatCurrentSession];
  [self _writeToPasteboard:pasteboard exportFormat:exportFormat isLinkBackRefresh:NO lazyDataProvider:self];
  
  p.x -= iconSize.width/2;
  p.y -= iconSize.height/2;
  [super dragImage:iconDragged at:p offset:offset event:event pasteboard:pasteboard source:object slideBack:YES];
}
//end dragImage:at:offset:event:pasteboard:source:slideBack:

-(NSImage*) imageForDrag
{
  NSImage* result = [self image];
  if (!isMacOS10_5OrAbove())
  {
    NSImage* tiffImage = [[[NSImage alloc] initWithData:[result TIFFRepresentation]] autorelease];
    result = tiffImage;
  }//end if (!isMacOS10_5OrAbove())
  return result;
}
//end imageForDrag

-(void) concludeDragOperation:(id <NSDraggingInfo>)sender
{
  DebugLog(1, @">concludeDragOperation");
  //overridden to avoid some strange additional "setImage" that would occur...
  NSPasteboard* pboard = [sender draggingPasteboard];
  if ([self->transientFilesPromisedFilePaths count] &&
      [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilesPromisePboardType]])
    [self performSelector:@selector(waitForPromisedFiles:) withObject:[NSDate date] afterDelay:0.];
  [self->transientDragData release];
  self->transientDragData = nil;
  [self->transientDragEquation release];
  self->transientDragEquation = nil;
  DebugLog(1, @"<concludeDragOperation");
}
//end concludeDragOperation:

-(void) waitForPromisedFiles:(id)object
{
  NSDate* beginDate = [object dynamicCastToClass:[NSDate class]];
  BOOL stop = ![self->transientFilesPromisedFilePaths count];
  BOOL done = NO;
  NSEnumerator* enumerator = [self->transientFilesPromisedFilePaths objectEnumerator];
  NSString* filePath = nil;
  while((filePath = [enumerator nextObject]))
  {
    NSString* sourceUTI = [[NSFileManager defaultManager] UTIFromPath:filePath];
    NSData* data = [NSData dataWithContentsOfFile:filePath options:NSUncachedRead error:nil];
    done = [self->document applyData:data sourceUTI:sourceUTI];
    if (done)
      break;
  }//end for each filePath
  stop |= done;
  NSTimeInterval elapsedTime = [[NSDate date] timeIntervalSinceDate:beginDate];
  stop |= (elapsedTime >= 10);
  if (!stop)
    [self performSelector:@selector(waitForPromisedFiles:) withObject:beginDate afterDelay:0.25];
  else//if (stop)
  {
    NSEnumerator* enumerator = [self->transientFilesPromisedFilePaths objectEnumerator];
    NSString* filePath = nil;
    while((filePath = [enumerator nextObject]))
      [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    [self->transientFilesPromisedFilePaths release];
    self->transientFilesPromisedFilePaths = nil;
  }//end if (stop)
}
//end concludeDragOperation:

-(void) dragFilterWindowController:(DragFilterWindowController*)dragFilterWindowController exportFormatDidChange:(export_format_t)exportFormat
{
  [self performProgrammaticDragCancellation:nil];
}
//end dragFilterWindowController:exportFormatDidChange:

-(void) performProgrammaticDragCancellation:(id)context
{
  DebugLog(1, @">performProgrammaticDragCancellation");
  self->shouldRedrag = YES;
  NSPoint mouseLocation1 = [NSEvent mouseLocation];
  CGPoint cgMouseLocation1 = NSPointToCGPoint(mouseLocation1);
  CGEventRef cgEvent0 =
    CGEventCreateMouseEvent(0, kCGEventLeftMouseUp, cgMouseLocation1, kCGMouseButtonLeft);
  if (isMacOS10_5OrAbove())
    CGEventSetLocation(cgEvent0, CGEventGetUnflippedLocation(cgEvent0));
  else//if (!isMacOS10_5OrAbove())
  {
    CGPoint point = CGEventGetLocation(cgEvent0);
    point.y = [[NSScreen mainScreen] frame].size.height-point.y;
    CGEventSetLocation(cgEvent0, point);
  }//if (!isMacOS10_5OrAbove())
  CGEventPost(kCGHIDEventTap, cgEvent0);
  CFRelease(cgEvent0);
  DebugLog(1, @"<");
}//end performProgrammaticDragCancellation:

-(void) performProgrammaticRedrag:(id)context
{
  DebugLog(1, @">performProgrammaticRedrag");
  self->shouldRedrag = YES;
  [[[[AppController appController] dragFilterWindowController] window] setIgnoresMouseEvents:YES];
  NSPoint center = self->lastDragStartPointSelfBased;
  NSPoint mouseLocation1 = [NSEvent mouseLocation];
  NSPoint mouseLocation2 = [[self window] convertBaseToScreen:[self convertPoint:center toView:nil]];
  CGPoint cgMouseLocation1 = NSPointToCGPoint(mouseLocation1);
  CGPoint cgMouseLocation2 = NSPointToCGPoint(mouseLocation2);
  CGEventRef cgEvent1 =
    CGEventCreateMouseEvent(0, kCGEventLeftMouseDown, cgMouseLocation2, kCGMouseButtonLeft);
  CGEventRef cgEvent2 =
    CGEventCreateMouseEvent(0, kCGEventLeftMouseDragged, cgMouseLocation2, kCGMouseButtonLeft);
  CGEventRef cgEvent3 =
    CGEventCreateMouseEvent(0, kCGEventLeftMouseDragged, cgMouseLocation1, kCGMouseButtonLeft);
  if (isMacOS10_5OrAbove())
  {
    CGEventSetLocation(cgEvent1, CGEventGetUnflippedLocation(cgEvent1));
    CGEventSetLocation(cgEvent2, CGEventGetUnflippedLocation(cgEvent2));
    CGEventSetLocation(cgEvent3, CGEventGetUnflippedLocation(cgEvent3));
  }//end if (isMacOS10_5OrAbove())
  else//if (!isMacOS10_5OrAbove())
  {
    CGPoint point = CGPointZero;
    NSRect screenFrame = [[NSScreen mainScreen] frame];
    point = CGEventGetLocation(cgEvent1);
    point.y = screenFrame.size.height-point.y;
    CGEventSetLocation(cgEvent1, point);
    point = CGEventGetLocation(cgEvent2);
    point.y = screenFrame.size.height-point.y;
    CGEventSetLocation(cgEvent2, point);
    point = CGEventGetLocation(cgEvent3);
    point.y = screenFrame.size.height-point.y;
    CGEventSetLocation(cgEvent3, point);
  }//if (!isMacOS10_5OrAbove())
  CGEventPost(kCGHIDEventTap, cgEvent1);
  CGEventPost(kCGHIDEventTap, cgEvent2);
  CGEventPost(kCGHIDEventTap, cgEvent3);
  CFRelease(cgEvent1);
  CFRelease(cgEvent2);
  CFRelease(cgEvent3);
  DebugLog(1, @"<performProgrammaticRedrag");
}
//end performProgrammaticRedrag:

//creates the promised file of the drag
-(NSArray*) namesOfPromisedFilesDroppedAtDestination:(NSURL*)dropDestination
{
  NSMutableArray* names = [NSMutableArray arrayWithCapacity:1];
  if (self->pdfData)
  {
    NSString* dropPath = [dropDestination path];
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSString* filePrefix = @"latex-image";
    
    NSString* extension = nil;
    PreferencesController* preferencesController = [PreferencesController sharedController];
    export_format_t exportFormat = [preferencesController exportFormatCurrentSession];
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
      case EXPORT_FORMAT_MATHML:
        extension = @"html";
        break;
      case EXPORT_FORMAT_SVG:
        extension = @"svg";
        break;
      case EXPORT_FORMAT_TEXT:
        extension = @"tex";
        break;
    }

    NSDictionary* exportOptions = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithFloat:[preferencesController exportJpegQualityPercent]], @"jpegQuality",
                                   [NSNumber numberWithFloat:[preferencesController exportScalePercent]], @"scaleAsPercent",
                                   [NSNumber numberWithBool:[preferencesController exportTextExportPreamble]], @"textExportPreamble",
                                   [NSNumber numberWithBool:[preferencesController exportTextExportEnvironment]], @"textExportEnvironment",
                                   [NSNumber numberWithBool:[preferencesController exportTextExportBody]], @"textExportBody",
                                   [preferencesController exportJpegBackgroundColor], @"jpegColor",//at the end for the case it is null
                                   nil];
    NSData* data = nil;
    if (!data && self->transientDragEquation)
      data = [[self->transientDragEquation exportPrefetcher] fetchDataForFormat:exportFormat wait:YES];
    if (!data)
      data = [[LaTeXProcessor sharedLaTeXProcessor] dataForType:exportFormat pdfData:self->pdfData
                     exportOptions:exportOptions
                     compositionConfiguration:[preferencesController compositionConfigurationDocument]
                     uniqueIdentifier:[NSString stringWithFormat:@"%p", self]];
    if (extension)
    {
      NSString* fileName = nil;
      NSString* filePath = nil;
      unsigned long i = 1;
      //we try to compute a name that is not already in use
      do
      {
        fileName = [NSString stringWithFormat:@"%@-%lu.%@", filePrefix, (unsigned long)i++, extension];
        filePath = [dropPath stringByAppendingPathComponent:fileName];
      } while (i && [fileManager fileExistsAtPath:filePath]);
      
      //if we find such a name, use it
      if (![fileManager fileExistsAtPath:filePath])
      {
        [fileManager createFileAtPath:filePath contents:data attributes:nil];
        [fileManager setAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:'LTXt'] forKey:NSFileHFSCreatorCode]
                             ofItemAtPath:filePath error:0];
        NSColor* jpegBackgroundColor = (exportFormat == EXPORT_FORMAT_JPEG) ? [exportOptions objectForKey:@"jpegColor"] : nil;
        if ((exportFormat != EXPORT_FORMAT_PNG) &&
            (exportFormat != EXPORT_FORMAT_TIFF) &&
            (exportFormat != EXPORT_FORMAT_JPEG))
          [[NSWorkspace sharedWorkspace] setIcon:[[LaTeXProcessor sharedLaTeXProcessor] makeIconForData:self->pdfData backgroundColor:jpegBackgroundColor]
                                         forFile:filePath options:NSExclude10_4ElementsIconCreationOption];
        [names addObject:fileName];
      }//end if (![fileManager fileExistsAtPath:filePath])
    }//end if (extension)
  }//end if (self->pdfData)
  return names;
}
//end namesOfPromisedFilesDroppedAtDestination:

-(void) _writeToPasteboard:(NSPasteboard*)pasteboard exportFormat:(export_format_t)exportFormat isLinkBackRefresh:(BOOL)isLinkBackRefresh lazyDataProvider:(id)lazyDataProvider
{
  DebugLog(1, @">");
  [self->document triggerSmartHistoryFeature];

  LatexitEquation* equation = [document latexitEquationWithCurrentStateTransient:NO];
  [self->transientDragEquation release];
  self->transientDragEquation = [equation retain];

  [pasteboard addTypes:[NSArray arrayWithObject:LatexitEquationsPboardType] owner:self];
  [pasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:[NSArray arrayWithObjects:equation, nil]] forType:LatexitEquationsPboardType];
  [equation writeToPasteboard:pasteboard exportFormat:exportFormat isLinkBackRefresh:isLinkBackRefresh lazyDataProvider:lazyDataProvider];
  if (self->isDragging && (lazyDataProvider == self))
  {
    [pasteboard addTypes:@[/*NSFileContentsPboardType,*//* NSFilenamesPboardType, NSURLPboardType,*/ ]
                   owner:lazyDataProvider];
  }//end if (self->isDragging && (lazyDataProvider == self))
  DebugLog(1, @"<");
}
//end _writeToPasteboard:isLinkBackRefresh:lazyDataProvider:

//provides lazy data to a pasteboard
-(void) pasteboard:(NSPasteboard *)pasteboard provideDataForType:(NSString*)type
{
  DebugLog(1, @">pasteboard:%p provideDataForType:%@", pasteboard, type);
  PreferencesController* preferencesController = [PreferencesController sharedController];
  export_format_t exportFormat = [preferencesController exportFormatCurrentSession];
  BOOL hasAlreadyCachedData = (self->transientDragData != nil) && (exportFormat == self->transientLastExportFormat);
  self->transientLastExportFormat = exportFormat;
  
  NSDictionary* exportOptions = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithFloat:[preferencesController exportJpegQualityPercent]], @"jpegQuality",
                                 [NSNumber numberWithFloat:[preferencesController exportScalePercent]], @"scaleAsPercent",
                                 [NSNumber numberWithBool:[preferencesController exportTextExportPreamble]], @"textExportPreamble",
                                 [NSNumber numberWithBool:[preferencesController exportTextExportEnvironment]], @"textExportEnvironment",
                                 [NSNumber numberWithBool:[preferencesController exportTextExportBody]], @"textExportBody",
                                 [preferencesController exportJpegBackgroundColor], @"jpegColor",//at the end for the case it is null
                                 nil];
  NSData* data = hasAlreadyCachedData ? self->transientDragData : nil;
  if (!data && self->transientDragEquation)
    data = [[self->transientDragEquation exportPrefetcher] fetchDataForFormat:exportFormat wait:YES];
  if (!data)
    data = [[LaTeXProcessor sharedLaTeXProcessor]
      dataForType:exportFormat pdfData:self->pdfData
      exportOptions:exportOptions
      compositionConfiguration:[preferencesController compositionConfigurationDocument]
      uniqueIdentifier:[NSString stringWithFormat:@"%p", self]];
  if (!hasAlreadyCachedData)
  {
    [self->transientDragData release];
    self->transientDragData = [data copy];
  }//end if (!hasAlreadyCachedData)
  if ([type isEqualToString:NSFileContentsPboardType] || [type isEqualToString:NSFilenamesPboardType] || [type isEqualToString:NSURLPboardType])
  {
    NSString* extension = nil;
    NSString* uti = nil;
    switch(exportFormat)
    {
      case EXPORT_FORMAT_PDF:
      case EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS:
        extension = @"pdf";
        uti = @"com.adobe.pdf";
        break;
      case EXPORT_FORMAT_EPS:
        extension = @"eps";
        uti = @"com.adobe.encapsulated-​postscript";
        break;
      case EXPORT_FORMAT_TIFF:
        extension = @"tiff";
        uti = @"public.tiff";
        break;
      case EXPORT_FORMAT_PNG:
        extension = @"png";
        uti = @"public.png";
        break;
      case EXPORT_FORMAT_JPEG:
        extension = @"jpeg";
        uti = @"public.jpeg";
        break;
      case EXPORT_FORMAT_MATHML:
        extension = @"html";
        uti = @"public.html";
        break;
      case EXPORT_FORMAT_SVG:
        extension = @"svg";
        uti = @"public.svg-image";
        break;
      case EXPORT_FORMAT_TEXT:
        extension = @"tex";
        uti = @"public.text";
        break;
    }
    if (data)
    {
      if ([type isEqualToString:NSFileContentsPboardType])
        [pasteboard setData:data forType:NSFileContentsPboardType];
      else if ([type isEqualToString:NSFilenamesPboardType])
      {
        NSString* folder = [[NSWorkspace sharedWorkspace] temporaryDirectory];
        NSString* filePath = !extension ? nil :
        [[folder stringByAppendingPathComponent:@"latexit-drag"] stringByAppendingPathExtension:extension];
        if (filePath)
        {
          if (!hasAlreadyCachedData)
            [data writeToFile:filePath atomically:YES];
          NSURL* fileURL = [NSURL fileURLWithPath:filePath];
          if (isMacOS10_6OrAbove())
            [pasteboard writeObjects:[NSArray arrayWithObjects:fileURL, nil]];
          //else
            [pasteboard setPropertyList:[NSArray arrayWithObjects:filePath, nil] forType:type];
        }//end if (filePath)
      }//end if ([type isEqualToString:NSFilenamesPboardType])
      else if ([type isEqualToString:NSURLPboardType])
      {
        NSString* folder = [[NSWorkspace sharedWorkspace] temporaryDirectory];
        NSString* filePath = !extension ? nil :
        [[folder stringByAppendingPathComponent:@"latexit-drag"] stringByAppendingPathExtension:extension];
        if (filePath)
        {
          if (!hasAlreadyCachedData)
            [data writeToFile:filePath atomically:YES];
          NSURL* fileURL = [NSURL fileURLWithPath:filePath];
          if (isMacOS10_6OrAbove())
            [pasteboard writeObjects:[NSArray arrayWithObjects:fileURL, nil]];
          else
            [fileURL writeToPasteboard:pasteboard];
        }//end if (filePath)
      }//end if ([type isEqualToString:NSURLPboardType])
    }//end if (data)
  }//end if ([type isEqualToString:NSFileContentsPboardType] || [type isEqualToString:NSFilenamesPboardType] || [type isEqualToString:NSURLPboardType])
  else//if (![type isEqualToString:NSFileContentsPboardType] && ![type isEqualToString:NSFilenamesPboardType] && ![type isEqualToString:NSURLPboardType])
  {
    if (exportFormat != EXPORT_FORMAT_MATHML)
      [pasteboard setData:data forType:type];
    else//if (exportFormat == EXPORT_FORMAT_MATHML)
    {
      NSString* documentString = !data ? nil : [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
      NSString* blockQuote = [documentString stringByMatching:@"<blockquote(.*?)>.*</blockquote>" options:RKLDotAll inRange:NSMakeRange(0, [documentString length]) capture:0 error:0];
      if (blockQuote)
        [pasteboard setString:blockQuote forType:type];
    }//end if (exportFormat == EXPORT_FORMAT_MATHML)
  }//end if (![type isEqualToString:NSFileContentsPboardType] && ![type isEqualToString:NSFilenamesPboardType] && ![type isEqualToString:NSURLPboardType])
  DebugLog(1, @"<pasteboard:%p provideDataForType:%@", pasteboard, type);
}
//end pasteboard:provideDataForType:

//We can drop on the imageView only if the PDF has been made by LaTeXiT (as "creator" document attribute)
//So, the keywords of the PDF contain the whole document state
-(NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
  NSDragOperation result = NSDragOperationNone;
  BOOL ok = NO;
  NSString* type = nil;
  NSPasteboard* pboard = [sender draggingPasteboard];
  if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSColorPboardType]]))
    ok = YES;
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSPDFPboardType, @"com.adobe.pdf", nil]]))
    ok = YES;
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFileContentsPboardType]]))
    ok = YES;
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]]))
  {
    NSArray* plist = [[pboard propertyListForType:NSFilenamesPboardType] dynamicCastToClass:[NSArray class]];
    NSString* filepath = !([plist count] == 1) ? nil : [plist lastObject];
    NSString* sourceUTI = [[NSFileManager defaultManager] UTIFromPath:filepath];
    ok = UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.tex")) || [LatexitEquation latexitEquationPossibleWithUTI:sourceUTI];
  }//end if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]]))
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilesPromisePboardType]]))
  {
    ok = YES;//([pboard availableTypeFromArray:[NSArray arrayWithObject:@"com.apple.iWork.TSPNativeMetadata"]] != nil);
  }//end if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]]))
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:GetWebURLsWithTitlesPboardType(), nil]]))
    ok = YES;
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSRTFDPboardType, @"com.apple.flat-rtfd", nil]]))
  {
    NSData* rtfdData = [pboard dataForType:type];
    NSDictionary* docAttributes = nil;
    NSAttributedString* attributedString = [[NSAttributedString alloc] initWithRTFD:rtfdData documentAttributes:&docAttributes];
    NSDictionary* pdfAttachments = [attributedString attachmentsOfType:@"pdf" docAttributes:docAttributes];
    NSData* pdfWrapperData = [pdfAttachments count] ? [[[pdfAttachments objectEnumerator] nextObject] regularFileContents] : nil;
    ok = attributedString || (pdfWrapperData != nil);//now, allow string
    [attributedString release];
  }//end if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSRTFDPboardType, @"com.apple.flat-rtfd", nil]]))
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObjects:NSRTFPboardType, NSStringPboardType, nil]])
    ok = YES;
  result = ok ? NSDragOperationCopy : NSDragOperationNone;
  return result;
}
//end draggingEntered:

-(BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
  DebugLog(1, @">performDragOperation");
  BOOL result = [self _applyDataFromPasteboard:[sender draggingPasteboard] sender:sender];
  [self->transientDragData release];
  self->transientDragData = nil;
  [self->transientDragEquation release];
  self->transientDragEquation = nil;
  DebugLog(1, @"<performDragOperation");
  return result;
}
//end performDragOperation:

-(BOOL) validateMenuItem:(id)sender
{
  BOOL ok = YES;
  if ([sender tag] == -1)//default
  {
    export_format_t defaultExportFormat = [[PreferencesController sharedController] exportFormatCurrentSession];
    [sender setTitle:[NSString stringWithFormat:@"%@ (%@)",
      NSLocalizedString(@"Default Format", @"Default Format"),
      [[AppController appController] nameOfType:defaultExportFormat]]];
  }
  if ([sender tag] == EXPORT_FORMAT_EPS)
    ok = [[AppController appController] isGsAvailable];
  else if ([sender tag] == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
    ok = [[AppController appController] isGsAvailable] && [[AppController appController] isPsToPdfAvailable];
  else if ([sender tag] == EXPORT_FORMAT_SVG)
    ok = [[AppController appController] isPdfToSvgAvailable];
  if ([sender action] == @selector(copy:))
    ok = ok && ([self image] != nil);
  return ok;
}
//end validateMenuItem:

-(IBAction) copy:(id)sender
{
  [self->transientDragData release];
  self->transientDragData = nil;
  [self->transientDragEquation release];
  self->transientDragEquation = nil;
  NSInteger tag = sender ? [sender tag] : -1;
  export_format_t copyExportFormat = ((tag == -1) ? [[PreferencesController sharedController] exportFormatCurrentSession] : (export_format_t) tag);
  [self copyAsFormat:copyExportFormat];
}
//end copy:

-(void) copyAsFormat:(export_format_t)copyExportFormat
{
  [self->transientDragData release];
  self->transientDragData = nil;
  [self->transientDragEquation release];
  self->transientDragEquation = nil;
  NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard declareTypes:[NSArray array] owner:self];
  PreferencesController* preferencesController = [PreferencesController sharedController];
  export_format_t oldExportFormat = [preferencesController exportFormatCurrentSession];
  [preferencesController setExportFormatCurrentSession:copyExportFormat];
  //lazyDataProvider to nil to force immediate computation of the pdf with outlined fonts
  [self _writeToPasteboard:pasteboard exportFormat:copyExportFormat isLinkBackRefresh:NO lazyDataProvider:nil];
  [preferencesController setExportFormatCurrentSession:oldExportFormat];
}
//end copyAsFormat:

//In my opinion, this paste: is triggered only programmatically from the paste: of LineCountTextView
-(IBAction) paste:(id)sender
{
  [self _applyDataFromPasteboard:[NSPasteboard generalPasteboard] sender:sender];
}
//end paste:

-(BOOL) _applyDataFromPasteboard:(NSPasteboard*)pboard sender:(id <NSDraggingInfo>)sender;
{
  BOOL ok = YES;
  NSString* type = nil;
  BOOL done = NO;
  
  if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSColorPboardType]])))
  {
    DebugLog(1, @"_applyDataFromPasteboard type = %@", type);
    [self setBackgroundColor:[NSColor colorWithData:[pboard dataForType:type]] updateHistoryItem:YES];
    done = YES;
  }//end if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSColorPboardType]])))
  if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:LibraryItemsWrappedPboardType]])))
  {
    DebugLog(1, @"_applyDataFromPasteboard type = %@", type);
    NSArray* libraryItemsWrappedArray = [pboard propertyListForType:type];
    NSUInteger count = [libraryItemsWrappedArray count];
    LibraryEquation* libraryEquation = nil;
    while(count-- && !libraryEquation)
    {
      NSString* objectIDAsString = [libraryItemsWrappedArray objectAtIndex:count];
      NSManagedObject* libraryItem = [[[LibraryManager sharedManager] managedObjectContext] managedObjectForURIRepresentation:[NSURL URLWithString:objectIDAsString]];
      libraryEquation = ![libraryItem isKindOfClass:[LibraryEquation class]] ? nil : (LibraryEquation*)libraryItem;
    }
    if (libraryEquation)
      [self->document applyLibraryEquation:libraryEquation];
    done = YES;
  }//end if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:LibraryItemsWrappedPboardType]])))
  if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:LibraryItemsArchivedPboardType]])))
  {
    DebugLog(1, @"_applyDataFromPasteboard type = %@", type);
    NSArray* libraryItemsArray = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:type]];
    NSUInteger count = [libraryItemsArray count];
    LibraryEquation* libraryEquation = nil;
    while(count-- && !libraryEquation)
      libraryEquation = [[libraryItemsArray objectAtIndex:count] isKindOfClass:[LibraryEquation class]] ? [libraryItemsArray objectAtIndex:count] : nil;
    if (libraryEquation)
      [self->document applyLibraryEquation:libraryEquation];
    done = YES;
  }//end if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:LibraryItemsArchivedPboardType]])))
  if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:LatexitEquationsPboardType]])))
  {
    DebugLog(1, @"_applyDataFromPasteboard type = %@", type);
    NSArray* latexitEquationsArray = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:type]];
    [self->document applyLatexitEquation:[latexitEquationsArray lastObject] isRecentLatexisation:NO];
    done = YES;
  }//end if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:LatexitEquationsPboardType]])))
  if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"com.adobe.pdf", NSPDFPboardType, nil]])))
  {
    DebugLog(1, @"_applyDataFromPasteboard type = %@", type);
    done = [self->document applyData:[pboard dataForType:type] sourceUTI:@"com.adobe.pdf"];
  }//end if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"com.adobe.pdf", NSPDFPboardType, nil]])))
  if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFileContentsPboardType]])))
  {
    DebugLog(1, @"_applyDataFromPasteboard type = %@", type);
    done = [self->document applyData:[pboard dataForType:type] sourceUTI:@"com.adobe.pdf"];
  }//end if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFileContentsPboardType]])))
  if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]])))
  {
    DebugLog(1, @"_applyDataFromPasteboard type = %@", type);
    NSArray* plist = [[pboard propertyListForType:type] dynamicCastToClass:[NSArray class]];
    NSString* filepath = ![plist count] ? nil : [[plist objectAtIndex:0] dynamicCastToClass:[NSString class]];
    NSString* sourceUTI = [[NSFileManager defaultManager] UTIFromPath:filepath];
    NSData* data = !filepath ? nil : [NSData dataWithContentsOfFile:filepath options:NSUncachedRead error:nil];
    done = [self->document applyData:data sourceUTI:sourceUTI];
  }//end if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]])))
  if (!done && ![sender draggingSource] &&
      ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilesPromisePboardType]])))
  {
    [self->transientFilesPromisedFilePaths release];
    self->transientFilesPromisedFilePaths = [[NSMutableArray alloc] init];
    NSString* workingDirectory = [[NSWorkspace sharedWorkspace] temporaryDirectory];
    NSURL* workingDirectoryURL = [NSURL fileURLWithPath:workingDirectory];
    NSArray* files = [sender namesOfPromisedFilesDroppedAtDestination:workingDirectoryURL];
    NSEnumerator* enumerator = [files objectEnumerator];
    NSString* fileName = nil;
    while((fileName = [enumerator nextObject]))
    {
      NSString* filePath = [workingDirectory stringByAppendingPathComponent:fileName];
      [(NSMutableArray*)self->transientFilesPromisedFilePaths safeAddObject:filePath];
    }//end for each filename
    done = YES;
  }//end if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]]))
  /*if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:@"com.apple.iWork.TSPNativeMetadata"]])))
  {
    DebugLog(1, @"com.apple.iWork.TSPNativeMetadata found in clipboard");
    NSData* data = [pboard dataForType:@"com.apple.iWork.TSPNativeMetadata"];
    //NSData* data = [NSData dataWithContentsOfFile:@"/Volumes/Leopard/Users/chacha/Desktop/com.apple.iWork.TSPNativeMetadata"];
    if (data)
    {
      DebugLog(1, @"data associated to com.apple.iWork.TSPNativeMetadata : %@", data);
      NSString* pdfFileName = nil;
      NSString* uuid = nil;
      [CHProtoBuffers parseData:data outPdfFileName:&pdfFileName outUUID:&uuid];
      DebugLog(1, @"after parsing data, pdfFileName = <%@> uuid = <%@>", pdfFileName, uuid);
      if (pdfFileName && uuid)
      {
        MDQueryRef query = MDQueryCreate(kCFAllocatorDefault,
          (CFStringRef)[NSString stringWithFormat:@"kCHiWorkDocumentUUIDKey == %@", uuid],
          (CFArrayRef)[NSArray arrayWithObjects:(NSString*)kMDItemContentModificationDate, nil],
          (CFArrayRef)[NSArray arrayWithObjects:(NSString*)kMDItemContentModificationDate, nil]);
        MDQuerySetSearchScope(query,
          (CFArrayRef)[NSArray arrayWithObjects:(NSString*)kMDQueryScopeAllIndexed, nil],
          0);
        MDQueryExecute(query, kMDQuerySynchronous);
        NSUInteger count = MDQueryGetResultCount(query);
        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSString* pdfFilePath = nil;
        NSDate* pdfLastDate = nil;
        DebugLog(1, @"query returned %d items", count);
        while(count--)
        {
          MDItemRef item = (MDItemRef)MDQueryGetResultAtIndex(query, count);
          NSString* path = (NSString*)MDItemCopyAttribute(item, kMDItemPath);
          DebugLog(1, @"item path : <%@>", path);
          NSString* candidatePath = [[path stringByAppendingPathComponent:@"Data"] stringByAppendingPathComponent:pdfFileName];
          DebugLog(1, @"candidate path : <%@>", candidatePath);
          if ([fileManager fileExistsAtPath:candidatePath])
          {
            DebugLog(1, @"candidate path exists", candidatePath);
            NSError* error = nil;
            NSDictionary* fileAttributes = [fileManager attributesOfItemAtPath:candidatePath error:&error];
            NSDate* modificationDate = [fileAttributes fileModificationDate];
            NSDate* creationDate = [fileAttributes fileCreationDate];
            DebugLog(1, @"candidate modificationDate = <%@>", modificationDate);
            DebugLog(1, @"candidate creationDate = <%@>", creationDate);
            NSDate* candidateDate =
              !modificationDate ? creationDate :
              !creationDate ? modificationDate :
              [modificationDate laterDate:creationDate];
            DebugLog(1, @"candidateDate = <%@>", candidateDate);
            if (!pdfFilePath || !pdfLastDate || ([pdfLastDate compare:candidateDate] != NSOrderedDescending))
            {
              pdfFilePath = candidatePath;
              pdfLastDate = candidateDate;
              DebugLog(1, @"keep pdfFilePath = <%@>", pdfFilePath);
            }//end if (!pdfFilePath || !pdfLastDate || ([pdfLastDate compare:candidateDate] != NSOrderedDescending))
          }//end if ([fileManager fileExistsAtPath:candidatePath])
        }//end for each candidate
        if (pdfFilePath)
        {
          NSData* filePdfData = [NSData dataWithContentsOfFile:pdfFilePath];
          DebugLog(1, @"filePdfData = %p", filePdfData);
          done = filePdfData && [self->document applyData:filePdfData sourceUTI:@"com.adobe.pdf"];
        }//end if (pdfFilePath)
      }//end if (pdfFileName && uuid)
    }//end if (data)
  }//end if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:@"com.apple.iWork.TSPNativeMetadata"]])))*/
  if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:GetWebURLsWithTitlesPboardType(), nil]])))
  {
    DebugLog(1, @"_applyDataFromPasteboard type = %@", type);
    id plist = [pboard propertyListForType:type];
    NSArray* array = ![plist isKindOfClass:[NSArray class]] ? nil : (NSArray*)plist;
    array = [array lastObject];//array of titles
    NSEnumerator* enumerator = ![plist isKindOfClass:[NSArray class]] ? nil : [array objectEnumerator];
    NSString* title = nil;
    NSMutableString* concats = nil;
    while((title = [enumerator nextObject]))
    {
      title = ![title isKindOfClass:[NSString class]] ? nil : title;
      if (title)
      {
        if (!concats)
          concats = [NSMutableString stringWithString:title];
        else
          [concats appendString:title];
      }//end if (title)
    }//end while((title = [enumerator nextObject]))
    if (concats)
      [self->document applyString:concats];
    done = (concats != nil);
  }//end (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:GetWebURLsWithTitlesPboardType(), nil]])))
  if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"com.apple.flat-rtfd", NSRTFDPboardType, nil]])))
  {
    DebugLog(1, @"_applyDataFromPasteboard type = %@", type);
    NSData* rtfdData = [pboard dataForType:type];
    NSDictionary* docAttributes = nil;
    NSAttributedString* attributedString = [[NSAttributedString alloc] initWithRTFD:rtfdData documentAttributes:&docAttributes];
    NSDictionary* pdfAttachments = [attributedString attachmentsOfType:@"pdf" docAttributes:docAttributes];
    NSData* pdfWrapperData = [pdfAttachments count] ? [[[pdfAttachments objectEnumerator] nextObject] regularFileContents] : nil;
    if (pdfWrapperData)
      done = [self->document applyData:pdfWrapperData sourceUTI:@"com.adobe.pdf"];
    [attributedString release];
  }//end (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"com.apple.flat-rtfd", NSRTFDPboardType, nil]])))
  if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"public.rtf", NSRTFPboardType, nil]])))
  {
    DebugLog(1, @"_applyDataFromPasteboard type = %@", type);
    NSData* rtfData = [pboard dataForType:type];
    NSDictionary* docAttributes = nil;
    NSAttributedString* attributedString = [[NSAttributedString alloc] initWithRTF:rtfData documentAttributes:&docAttributes];
    NSString* string = [attributedString string];
    NSData* data = [string dataUsingEncoding:NSUTF8StringEncoding];
    //[self->document applyString:string];
    [self->document applyData:data sourceUTI:@"public.text"];
    [attributedString release];
    done = YES;
  }
  if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"public.text", NSStringPboardType, nil]])))
  {
    DebugLog(1, @"_applyDataFromPasteboard type = %@", type);
    //NSString* string = [pboard stringForType:type];
    //[self->document applyString:string];
    [self->document applyData:[pboard dataForType:type] sourceUTI:@"public.text"];
    done = YES;
  }//end if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"public.text", NSStringPboardType, nil]])))
  if (!done)
    ok = NO;
  return ok;
}
//end _applyDataFromPasteboard:sender:

-(void) _copyCurrentImageNotification:(NSNotification*)notification
{
  [self copy:self];
}
//end _copyCurrentImageNotification:

-(void) drawRect:(NSRect)rect
{
  BOOL doNotClipPreview = [[PreferencesController sharedController] doNotClipPreview];
  if (doNotClipPreview)
  {
    NSRect bounds = [self bounds];
    NSRect inRoundedRect1 = NSInsetRect(bounds, 1, 1);
    NSRect inRoundedRect2 = NSInsetRect(bounds, 2, 2);
    NSRect inRoundedRect3 = NSInsetRect(bounds, 3, 3);
    NSRect inRect = NSInsetRect(bounds, 7, 7);
    CGContextRef cgContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    CGContextSetRGBFillColor(cgContext, 0.95f, 0.95f, 0.95f, 1.0f);
    CGContextAddRoundedRect(cgContext, CGRectFromNSRect(inRoundedRect1), 4.f, 4.f);
    CGContextFillPath(cgContext);
    CGContextSetRGBStrokeColor(cgContext, 0.68f, 0.68f, 0.68f, 1.f);
    CGContextAddRoundedRect(cgContext, CGRectFromNSRect(inRoundedRect3), 4.f, 4.f);
    CGContextStrokePath(cgContext);
    CGContextSetRGBStrokeColor(cgContext, 0.95f, 0.95f, 0.95f, 1.0f);
    CGContextAddRoundedRect(cgContext, CGRectFromNSRect(inRoundedRect1), 4.f, 4.f);
    CGContextStrokePath(cgContext);
    CGContextSetRGBStrokeColor(cgContext, 0.95f, 0.95f, 0.95f, 1.0f);
    CGContextAddRoundedRect(cgContext, CGRectFromNSRect(inRoundedRect2), 4.f, 4.f);
    CGContextStrokePath(cgContext);

    NSImage* image = [self image];
    NSSize naturalImageSize = image ? [image size] : NSZeroSize;
    CGFloat factor = exp(3*(self->zoomLevel-1));
    NSSize newSize = naturalImageSize;
    newSize.width *= factor;
    newSize.height *= factor;

    NSRect destRect = NSMakeRect(0, 0, newSize.width, newSize.height);
    destRect = adaptRectangle(destRect, inRect, YES, NO, NO);
    if (self->backgroundColor)
    {
      [self->backgroundColor set];
      NSRectFill(inRect);
    }
    //[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    if (self->imageRep)
      [self->imageRep drawInRect:destRect];
    else
      [[self image] drawInRect:destRect fromRect:NSMakeRect(0, 0, naturalImageSize.width, naturalImageSize.height)
              operation:NSCompositeSourceOver fraction:1.];
  }//end if (doNotClipPreview)
  else//if (!doNotClipPreview)
  {
    NSRect inRect = NSInsetRect([self bounds], 7, 7);

    CGFloat factor = exp(3*(self->zoomLevel-1));
    NSSize newSize = self->naturalPDFSize;
    newSize.width *= factor;
    newSize.height *= factor;

    NSRect destRect = NSMakeRect(0, 0, newSize.width, newSize.height);
    destRect = adaptRectangle(destRect, inRect, YES, NO, NO);
    if (self->backgroundColor)
    {
      [self->backgroundColor set];
      NSRectFill(inRect);
    }//end if (self->backgroundColor)
    
    CGContextRef cgContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    NSClipView* clipView = [[self superview] dynamicCastToClass:[NSClipView class]];
    NSScrollView* scrollView = (NSScrollView*)[clipView superview];
    NSRect borderRect = !clipView ? [self bounds] : [clipView visibleRect];
    NSRect inRoundedRect1 = NSInsetRect(borderRect, 0, 0);
    NSRect inRoundedRect2 = NSInsetRect(borderRect, 2, 2);
    NSRect inRoundedRect3 = NSInsetRect(borderRect, 3, 3);
    CGContextSetRGBFillColor(cgContext, 0.95f, 0.95f, 0.95f, 1.0f);
    CGFloat backgroundRGBcomponents[4] = {0.95f, 0.95f, 0.95f, 1.0f};
    [[self->backgroundColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace]
      getRed:&backgroundRGBcomponents[0] green:&backgroundRGBcomponents[1] blue:&backgroundRGBcomponents[2] alpha:&backgroundRGBcomponents[3]];
    CGContextSetRGBFillColor(cgContext, backgroundRGBcomponents[0], backgroundRGBcomponents[1], backgroundRGBcomponents[2], backgroundRGBcomponents[3]);

    CGContextAddRect(cgContext, CGRectFromNSRect([self bounds]));
    CGContextFillPath(cgContext);

    if (self->imageRep)
      [self->imageRep drawInRect:destRect];
    else
      [[self image] drawInRect:destRect fromRect:NSMakeRect(0, 0, self->naturalPDFSize.width, self->naturalPDFSize.height)
              operation:NSCompositeSourceOver fraction:1.];

    NSRect documentRect = [self frame];
    NSRect documentVisibleRect = !clipView ? NSZeroRect : [clipView documentVisibleRect];
    BOOL canScrollUp    = clipView && (NSMaxY(documentVisibleRect) < NSMaxY(documentRect));
    BOOL canScrollRight = clipView && (NSMaxX(documentVisibleRect) < NSMaxX(documentRect));
    BOOL canScrollDown  = clipView && (documentVisibleRect.origin.y > documentRect.origin.y);
    BOOL canScrollLeft  = clipView && (documentVisibleRect.origin.x > documentRect.origin.x);
    BOOL shouldDisplayScrollUp    = canScrollUp    && (isMacOS10_7OrAbove() && [[scrollView verticalScroller] scrollerStyle]);
    BOOL shouldDisplayScrollRight = canScrollRight && (isMacOS10_7OrAbove() && [[scrollView horizontalScroller] scrollerStyle]);
    BOOL shouldDisplayScrollDown  = canScrollDown  && (isMacOS10_7OrAbove() && [[scrollView verticalScroller] scrollerStyle]);
    BOOL shouldDisplayScrollLeft  = canScrollLeft  && (isMacOS10_7OrAbove() && [[scrollView horizontalScroller] scrollerStyle]);
    BOOL shouldDisplayArrows = shouldDisplayScrollUp || shouldDisplayScrollRight || shouldDisplayScrollDown || shouldDisplayScrollLeft;
    BOOL arrowsVisibleChanged =
      (self->previousArrowsVisible[0] != shouldDisplayScrollUp) ||
      (self->previousArrowsVisible[1] != shouldDisplayScrollRight) ||
      (self->previousArrowsVisible[2] != shouldDisplayScrollDown) ||
      (self->previousArrowsVisible[3] != shouldDisplayScrollLeft);
    [self->layerArrows setHidden:!shouldDisplayArrows];
    if (arrowsVisibleChanged)
      [self->layerArrows setNeedsDisplay];
    self->previousArrowsVisible[0] = shouldDisplayScrollUp;
    self->previousArrowsVisible[1] = shouldDisplayScrollRight;
    self->previousArrowsVisible[2] = shouldDisplayScrollDown;
    self->previousArrowsVisible[3] = shouldDisplayScrollLeft;
    
    CGContextSetRGBFillColor(cgContext, 0.95f, 0.95f, 0.95f, 1.0f);
    CGContextAddRoundedRect(cgContext, CGRectFromNSRect(inRoundedRect1), 4.f, 4.f);
    CGContextAddRoundedRect(cgContext, CGRectFromNSRect(inRoundedRect3), 4.f, 4.f);
    CGContextEOFillPath(cgContext);
    CGContextSetRGBStrokeColor(cgContext, 0.68f, 0.68f, 0.68f, 1.f);
    CGContextAddRoundedRect(cgContext, CGRectFromNSRect(inRoundedRect3), 4.f, 4.f);
    CGContextStrokePath(cgContext);
    CGContextSetRGBStrokeColor(cgContext, 0.95f, 0.95f, 0.95f, 1.0f);
    CGContextAddRoundedRect(cgContext, CGRectFromNSRect(inRoundedRect1), 4.f, 4.f);
    CGContextStrokePath(cgContext);
    CGContextSetRGBStrokeColor(cgContext, 0.95f, 0.95f, 0.95f, 1.0f);
    CGContextAddRoundedRect(cgContext, CGRectFromNSRect(inRoundedRect2), 4.f, 4.f);
    CGContextStrokePath(cgContext);
  }//end if (!doNotClipPreview)
}
//end drawRect:

-(void) magnifyWithEvent:(NSEvent*)event
{
  CGFloat newZoomLevel = [self zoomLevel]+[event magnification];
  [self setZoomLevel:MAX(0, MIN(2, newZoomLevel))];
}
//end magnifyWithEvent:

-(void) updateViewSize
{
  BOOL doNotClipPreview = [[PreferencesController sharedController] doNotClipPreview];
  if (doNotClipPreview)
  {
    NSClipView* clipView = [[self superview] dynamicCastToClass:[NSClipView class]];
    if (clipView)
    {
      NSScrollView* scrollView = (NSScrollView*)[[clipView superview] retain];
      NSRect frame = [scrollView frame];
      NSView* superView = [scrollView superview];
      NSView* selfView = [self retain];
      [superView replaceSubview:scrollView with:selfView];
      [selfView setFrame:frame];
      [selfView release];
      [scrollView release];
      [self->layerView removeFromSuperview];
      [self->layerView release];
      self->layerView = nil;
      [self->layerArrows release];
      self->layerArrows = nil;
    }//end if (clipView)
  }//end if (doNotClipPreview)
  else//if (!doNotClipPreview)
  {
    NSClipView* clipView = [[self superview] dynamicCastToClass:[NSClipView class]];
    if (!clipView)
    {
      NSScrollView* scrollView = [[[NSScrollView alloc] initWithFrame:[self frame]] autorelease];
      [scrollView setAutoresizingMask:[self autoresizingMask]];
      NSView* superView = [self superview];
      NSView* selfView = [self retain];
      [superView replaceSubview:selfView with:scrollView];
      [scrollView setHasHorizontalScroller:NO];
      [scrollView setHasVerticalScroller:NO];
      clipView = (NSClipView*)[scrollView contentView];
      [clipView setCopiesOnScroll:NO];
      [scrollView setDocumentView:selfView];
      [selfView release];
      
      if (isMacOS10_7OrAbove())
      {
        if (!self->layerView)
        {
          self->layerView = [[TransparentView alloc] initWithFrame:[scrollView frame]];
          [self->layerView setNextResponder:scrollView];
          [self->layerView setWantsLayer:YES];
          [self->layerView setAutoresizingMask:[scrollView autoresizingMask]];
          [[scrollView superview] addSubview:self->layerView];
          [[self->layerView layer] setFrame:NSRectToCGRect([self->layerView bounds])];
        }
        if (!self->layerArrows)
        {
          CABasicAnimation* opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
          [opacityAnimation setDuration:1.0];
          [opacityAnimation setRepeatCount:HUGE_VALF];
          [opacityAnimation setAutoreverses:YES];
          [opacityAnimation setFromValue:[NSNumber numberWithFloat:1.0]];
          [opacityAnimation setToValue:[NSNumber numberWithFloat:0.0]];
          [opacityAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]];

          self->layerArrows = [[CALayer alloc] init];
          [self->layerArrows setFrame:[[self->layerView layer] bounds]];
          [self->layerArrows setHidden:YES];
          [self->layerArrows setDelegate:self];
          [self->layerArrows addAnimation:opacityAnimation forKey:@"animateOpacity"];
          [[self->layerView layer] addSublayer:self->layerArrows];
          [self->layerArrows setNeedsDisplay];
          [self setNeedsDisplay:YES];
        }//end if (!self->layerArrows)
      }//end if (isMacOS10_7OrAbove())
    }//end if (!clipView)
    CGFloat factor = exp(3*(self->zoomLevel-1));
    NSSize newSize = self->naturalPDFSize;
    newSize.width *= factor;
    newSize.height *= factor;
    NSScrollView* scrollView = (NSScrollView*)[clipView superview];
    NSSize containerSize = [scrollView contentSize];
    /*if (newSize.width > containerSize.width)
    {
      newSize.width = containerSize.width;
      newSize.height = !self->naturalPDFSize.width ? 0 : containerSize.width*self->naturalPDFSize.height/self->naturalPDFSize.width;
    }//end if (newSize.width > containerSize)*/
    [scrollView setHasHorizontalScroller:(newSize.width > containerSize.width)];
    [scrollView setHasVerticalScroller:(newSize.height > containerSize.height)];
    [[scrollView horizontalScroller] setControlSize:NSSmallControlSize];
    [[scrollView verticalScroller] setControlSize:NSSmallControlSize];
    [self setFrame:NSMakeRect(0, 0, MAX([scrollView contentSize].width, newSize.width), MAX([scrollView contentSize].height, newSize.height))];
  }//end if (!doNotClipPreview)
}
//end updateViewSize

-(void) drawLayer:(CALayer*)layer inContext:(CGContextRef)cgContext
{
  NSClipView* clipView = [[self superview] dynamicCastToClass:[NSClipView class]];
  NSScrollView* scrollView = (NSScrollView*)[clipView superview];
  NSRect documentRect = [self frame];
  NSRect documentVisibleRect = !clipView ? NSZeroRect : [clipView documentVisibleRect];
  BOOL canScrollUp    = clipView && (NSMaxY(documentVisibleRect) < NSMaxY(documentRect));
  BOOL canScrollRight = clipView && (NSMaxX(documentVisibleRect) < NSMaxX(documentRect));
  BOOL canScrollDown  = clipView && (documentVisibleRect.origin.y > documentRect.origin.y);
  BOOL canScrollLeft  = clipView && (documentVisibleRect.origin.x > documentRect.origin.x);
  BOOL shouldDisplayScrollUp    = canScrollUp    && (isMacOS10_7OrAbove() && [[scrollView verticalScroller] scrollerStyle]);
  BOOL shouldDisplayScrollRight = canScrollRight && (isMacOS10_7OrAbove() && [[scrollView horizontalScroller] scrollerStyle]);
  BOOL shouldDisplayScrollDown  = canScrollDown  && (isMacOS10_7OrAbove() && [[scrollView verticalScroller] scrollerStyle]);
  BOOL shouldDisplayScrollLeft  = canScrollLeft  && (isMacOS10_7OrAbove() && [[scrollView horizontalScroller] scrollerStyle]);
  BOOL shouldDisplayArrow[4] = {shouldDisplayScrollUp, shouldDisplayScrollRight, shouldDisplayScrollDown, shouldDisplayScrollLeft};
  
  //NSRect borderRect = !clipView ? [self bounds] : NSMakeRect(0, 0, [clipView bounds].size.width, [clipView bounds].size.height);
  NSRect inRoundedRect3 = [scrollView bounds];//NSInsetRect(borderRect, 3, 3);
  CGPoint trianglePoints[] = {CGPointMake(-2, -1), CGPointMake(0, 1), CGPointMake(2, -1)};
  NSUInteger i = 0;
  for(i = 0 ; i<4 ; ++i)
  {
    if (shouldDisplayArrow[i])
    {
      CGContextSaveGState(cgContext);
      CGContextSetShadow(cgContext, CGSizeMake(1, -1), 3.);
      if (i == 0)
        CGContextTranslateCTM(cgContext, inRoundedRect3.origin.x+inRoundedRect3.size.width/2, inRoundedRect3.origin.y+inRoundedRect3.size.height-10);
      else if (i == 1)
        CGContextTranslateCTM(cgContext, inRoundedRect3.origin.x+inRoundedRect3.size.width-10, inRoundedRect3.origin.y+inRoundedRect3.size.height/2);
      else if (i == 2)
        CGContextTranslateCTM(cgContext, inRoundedRect3.origin.x+inRoundedRect3.size.width/2, inRoundedRect3.origin.y+10);
      else if (i == 3)
        CGContextTranslateCTM(cgContext, inRoundedRect3.origin.x+10, inRoundedRect3.origin.y+inRoundedRect3.size.height/2);
      CGContextScaleCTM(cgContext, 4, 4);
      CGContextScaleCTM(cgContext, 1, -1);
      CGContextRotateCTM(cgContext, -M_PI+i*M_PI/2);
      CGContextAddLines(cgContext, trianglePoints, sizeof(trianglePoints)/sizeof(CGPoint));
      CGContextSetRGBFillColor(cgContext, 1., 0., 0., 1);
      CGContextFillPath(cgContext);
      CGContextAddLines(cgContext, trianglePoints, sizeof(trianglePoints)/sizeof(CGPoint));
      CGContextSetLineWidth(cgContext, 1./4);
      CGContextSetRGBStrokeColor(cgContext, 1., 1., 1., 1);
      CGContextStrokePath(cgContext);
      CGContextRestoreGState(cgContext);
    }//end if shouldDisplayArrow
  }//end for each shouldDisplayArrow
}
//end drawLayer:inContext:

@end
