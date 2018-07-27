//  MyImageView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005-2013 Pierre Chatelier. All rights reserved.

//The view in which the latex image is displayed is a little tuned. It knows its document
//and stores the full pdfdata (that may contain meta-data like keywords, creator...)
//Moreover, it supports drag'n drop

#import "MyImageView.h"

#import "AppController.h"
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
#import "NSManagedObjectContextExtended.h"
#import "NSMenuExtended.h"
#import "NSObjectExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"
#import "Utils.h"

#import "CGExtras.h"

#import <LinkBack/LinkBack.h>
#import <Quartz/Quartz.h>

static inline CGFloat frac(CGFloat x) {return x-floor(x);}
static inline CGFloat sqr(CGFloat x) {return x*x;}

//responds to a copy event, even if the Command-C was triggered in another view (like the library view)
NSString* CopyCurrentImageNotification = @"CopyCurrentImageNotification";
NSString* ImageDidChangeNotification = @"ImageDidChangeNotification";

@interface NSScroller (Bridge10_7)
-(NSInteger) scrollerStyle;
@end
@interface NSEvent (Bridge10_6)
-(CGFloat) magnification;
@end

@interface MyImageView (PrivateAPI)
-(NSImage*) imageForDrag;
-(NSMenu*) lazyCopyAsContextualMenu;
-(void) _writeToPasteboard:(NSPasteboard*)pasteboard isLinkBackRefresh:(BOOL)isLinkBackRefresh lazyDataProvider:(id)lazyDataProvider;
-(void) _copyCurrentImageNotification:(NSNotification*)notification;
-(BOOL) _applyDataFromPasteboard:(NSPasteboard*)pboard;
-(void) performProgrammaticDragCancellation:(id)context;
-(void) performProgrammaticRedrag:(id)context;
-(void) updateViewSize;
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
  [self registerForDraggedTypes:
    [NSArray arrayWithObjects:NSColorPboardType, NSPDFPboardType, NSFilenamesPboardType, NSFileContentsPboardType,
                              NSRTFDPboardType, NSRTFPboardType, GetWebURLsWithTitlesPboardType(), NSStringPboardType,
                              @"com.adobe.pdf", @"public.tiff", @"public.png", @"public.jpeg", @"public.svg-image",
                              @"public.html", nil]];
  return self;
}
//end initWithCoder:

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self->copyAsContextualMenu release];
  [self->backgroundColor release];
  [self->imageRep release];
  [super dealloc];
}
//end dealloc

-(void) awakeFromNib
{
}
//end awakeFromNib

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
  [someData retain];
  [self->pdfData release];
  self->pdfData = someData;

  [self->imageRep release];
  self->imageRep = !self->pdfData ? nil : [[NSPDFImageRep alloc] initWithData:self->pdfData];
  self->naturalPDFSize = !self->imageRep ? NSZeroSize : [self->imageRep size];
  NSImage* image = cachedImage;
  if (!image && self->imageRep)
  {
    image = [[[NSImage alloc] initWithSize:[self->imageRep size]] autorelease];
    [image setCacheMode:NSImageCacheNever];
    [image setDataRetained:YES];
    [image setScalesWhenResized:YES];
    [image addRepresentation:self->imageRep];
  }
  [self setImage:image];
  [self updateViewSize];
}
//end setPDFData:cachedImage:

-(void) setImage:(NSImage*)image
{
  [image setScalesWhenResized:YES];
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
    [self _writeToPasteboard:[link pasteboard] isLinkBackRefresh:YES lazyDataProvider:self];
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

  [self _writeToPasteboard:pasteboard isLinkBackRefresh:NO lazyDataProvider:self];

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
  //overridden to avoid some strange additional "setImage" that would occur...
}
//end concludeDragOperation:

-(void) dragFilterWindowController:(DragFilterWindowController*)dragFilterWindowController exportFormatDidChange:(export_format_t)exportFormat
{
  [self performProgrammaticDragCancellation:nil];
}
//end dragFilterWindowController:exportFormatDidChange:

-(void) performProgrammaticDragCancellation:(id)context
{
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
}//end performProgrammaticDragCancellation:

-(void) performProgrammaticRedrag:(id)context
{
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
    }

    NSColor*   color = [preferencesController exportJpegBackgroundColor];
    CGFloat  quality = [preferencesController exportJpegQualityPercent];
    NSData* data = [[LaTeXProcessor sharedLaTeXProcessor] dataForType:exportFormat pdfData:self->pdfData jpegColor:color
                                                  jpegQuality:quality scaleAsPercent:[preferencesController exportScalePercent]
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
        fileName = [NSString stringWithFormat:@"%@-%u.%@", filePrefix, i++, extension];
        filePath = [dropPath stringByAppendingPathComponent:fileName];
      } while (i && [fileManager fileExistsAtPath:filePath]);
      
      //if we find such a name, use it
      if (![fileManager fileExistsAtPath:filePath])
      {
        [fileManager createFileAtPath:filePath contents:data attributes:nil];
        [fileManager changeFileAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:'LTXt'] forKey:NSFileHFSCreatorCode]
                                   atPath:filePath];
        NSColor* jpegBackgroundColor = (exportFormat == EXPORT_FORMAT_JPEG) ? color : nil;
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

-(void) _writeToPasteboard:(NSPasteboard*)pasteboard isLinkBackRefresh:(BOOL)isLinkBackRefresh lazyDataProvider:(id)lazyDataProvider
{
  [self->document triggerSmartHistoryFeature];
  LatexitEquation* equation = [document latexitEquationWithCurrentStateTransient:NO];
  [pasteboard addTypes:[NSArray arrayWithObject:LatexitEquationsPboardType] owner:self];
  [pasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:[NSArray arrayWithObjects:equation, nil]] forType:LatexitEquationsPboardType];
  [equation writeToPasteboard:pasteboard isLinkBackRefresh:isLinkBackRefresh lazyDataProvider:lazyDataProvider];
}
//end _writeToPasteboard:isLinkBackRefresh:lazyDataProvider:

//provides lazy data to a pasteboard
-(void) pasteboard:(NSPasteboard *)pasteboard provideDataForType:(NSString*)type
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  export_format_t exportFormat = [preferencesController exportFormatCurrentSession];
  NSData* data = [[LaTeXProcessor sharedLaTeXProcessor]
    dataForType:exportFormat pdfData:self->pdfData jpegColor:[preferencesController exportJpegBackgroundColor]
    jpegQuality:[preferencesController exportJpegQualityPercent] scaleAsPercent:[preferencesController exportScalePercent]
    compositionConfiguration:[preferencesController compositionConfigurationDocument]
    uniqueIdentifier:[NSString stringWithFormat:@"%p", self]];
  [pasteboard setData:data forType:type];
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
    ok = [LatexitEquation latexitEquationPossibleWithUTI:sourceUTI];
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
  return [self _applyDataFromPasteboard:[sender draggingPasteboard]];
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
  int tag = sender ? [sender tag] : -1;
  export_format_t copyExportFormat = ((tag == -1) ? [[PreferencesController sharedController] exportFormatCurrentSession] : (export_format_t) tag);
  [self copyAsFormat:copyExportFormat];
}
//end copy:

-(void) copyAsFormat:(export_format_t)copyExportFormat
{
  NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard declareTypes:[NSArray array] owner:self];
  PreferencesController* preferencesController = [PreferencesController sharedController];
  export_format_t oldExportFormat = [preferencesController exportFormatCurrentSession];
  [preferencesController setExportFormatCurrentSession:copyExportFormat];
  //lazyDataProvider to nil to force immediate computation of the pdf with outlined fonts
  [self _writeToPasteboard:pasteboard isLinkBackRefresh:NO lazyDataProvider:nil];
  [preferencesController setExportFormatCurrentSession:oldExportFormat];
}
//end copyAsFormat:

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
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:LibraryItemsWrappedPboardType]]))
  {
    NSArray* libraryItemsWrappedArray = [pboard propertyListForType:type];
    unsigned int count = [libraryItemsWrappedArray count];
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
  }
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:LibraryItemsArchivedPboardType]]))
  {
    NSArray* libraryItemsArray = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:type]];
    unsigned int count = [libraryItemsArray count];
    LibraryEquation* libraryEquation = nil;
    while(count-- && !libraryEquation)
      libraryEquation = [[libraryItemsArray objectAtIndex:count] isKindOfClass:[LibraryEquation class]] ? [libraryItemsArray objectAtIndex:count] : nil;
    if (libraryEquation)
      [self->document applyLibraryEquation:libraryEquation];
    done = YES;
  }
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:LatexitEquationsPboardType]]))
  {
    NSArray* latexitEquationsArray = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:type]];
    [self->document applyLatexitEquation:[latexitEquationsArray lastObject] isRecentLatexisation:NO];
    done = YES;
  }
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"com.adobe.pdf", NSPDFPboardType, nil]]))
    done = [self->document applyData:[pboard dataForType:type] sourceUTI:@"com.adobe.pdf"];
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFileContentsPboardType]]))
    done = [self->document applyData:[pboard dataForType:type] sourceUTI:@"com.adobe.pdf"];
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]]))
  {
    NSArray* plist = [[pboard propertyListForType:type] dynamicCastToClass:[NSArray class]];
    NSString* filepath = ![plist count] ? nil : [[plist objectAtIndex:0] dynamicCastToClass:[NSString class]];
    NSString* sourceUTI = [[NSFileManager defaultManager] UTIFromPath:filepath];
    NSData* data = !filepath ? nil : [NSData dataWithContentsOfFile:filepath options:NSUncachedRead error:nil];
    done = [self->document applyData:data sourceUTI:sourceUTI];
  }//end if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]]))

  if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:GetWebURLsWithTitlesPboardType(), nil]])))
  {
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
  }
  if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"com.apple.flat-rtfd", NSRTFDPboardType, nil]])))
  {
    NSData* rtfdData = [pboard dataForType:type];
    NSDictionary* docAttributes = nil;
    NSAttributedString* attributedString = [[NSAttributedString alloc] initWithRTFD:rtfdData documentAttributes:&docAttributes];
    NSDictionary* pdfAttachments = [attributedString attachmentsOfType:@"pdf" docAttributes:docAttributes];
    NSData* pdfWrapperData = [pdfAttachments count] ? [[[pdfAttachments objectEnumerator] nextObject] regularFileContents] : nil;
    if (pdfWrapperData)
      done = [self->document applyData:pdfWrapperData sourceUTI:@"com.adobe.pdf"];
    [attributedString release];
  }
  if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"public.rtf", NSRTFPboardType, nil]])))
  {
    NSData* rtfData = [pboard dataForType:type];
    NSDictionary* docAttributes = nil;
    NSAttributedString* attributedString = [[NSAttributedString alloc] initWithRTF:rtfData documentAttributes:&docAttributes];
    [self->document applyString:[attributedString string]];
    [attributedString release];
    done = YES;
  }
  if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"public.text", NSStringPboardType, nil]])))
  {
    [self->document applyString:[pboard stringForType:type]];
    done = YES;
  }
  else if (!done)
    ok = NO;
  return ok;
}
//end _applyDataFromPasteboard:

-(void) _copyCurrentImageNotification:(NSNotification*)notification
{
  [self copy:self];
}
//end _copyCurrentImageNotification:

-(void) drawRect:(NSRect)rect
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
  }
  
  CGContextRef cgContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
  NSClipView* clipView = [[self superview] dynamicCastToClass:[NSClipView class]];
  NSScrollView* scrollView = (NSScrollView*)[clipView superview];
  NSRect borderRect = !clipView ? [self bounds] : [clipView visibleRect];
  NSRect inRoundedRect1 = NSInsetRect(borderRect, 0, 0);
  NSRect inRoundedRect2 = NSInsetRect(borderRect, 2, 2);
  NSRect inRoundedRect3 = NSInsetRect(borderRect, 3, 3);
  CGContextSetRGBFillColor(cgContext, 0.95f, 0.95f, 0.95f, 1.0f);
  CGContextAddRect(cgContext, CGRectFromNSRect([self bounds]));
  CGContextFillPath(cgContext);

  if (self->imageRep)
    [self->imageRep drawInRect:destRect];
  else
    [[self image] drawInRect:destRect fromRect:NSMakeRect(0, 0, self->naturalPDFSize.width, self->naturalPDFSize.height)
            operation:NSCompositeSourceOver fraction:1.];

  NSRect documentRect = [self frame];
  NSRect documentVisibleRect = !clipView ? NSZeroRect : [clipView documentVisibleRect];
  BOOL canScrollLeft  = clipView && (documentVisibleRect.origin.x > documentRect.origin.x);
  BOOL canScrollRight = clipView && (NSMaxX(documentVisibleRect) < NSMaxX(documentRect));
  BOOL canScrollDown  = clipView && (documentVisibleRect.origin.y > documentRect.origin.y);
  BOOL canScrollUp    = clipView && (NSMaxY(documentVisibleRect) < NSMaxY(documentRect));
  BOOL shoulDisplayScrollLeft  = canScrollLeft  && (isMacOS10_7OrAbove() && [[scrollView horizontalScroller] scrollerStyle]);
  BOOL shoulDisplayScrollRight = canScrollRight && (isMacOS10_7OrAbove() && [[scrollView horizontalScroller] scrollerStyle]);
  BOOL shoulDisplayScrollDown  = canScrollDown  && (isMacOS10_7OrAbove() && [[scrollView verticalScroller] scrollerStyle]);
  BOOL shoulDisplayScrollUp    = canScrollUp    && (isMacOS10_7OrAbove() && [[scrollView verticalScroller] scrollerStyle]);
  if ((shoulDisplayScrollLeft || shoulDisplayScrollRight || shoulDisplayScrollDown || shoulDisplayScrollUp))
  {
    CGPoint trianglePoints[] = {CGPointMake(-2, -1), CGPointMake(0, 1), CGPointMake(2, -1)};
    static NSDate* referenceDate = nil;
    if (!referenceDate)
      referenceDate = [[NSDate alloc] init];
    CGFloat seconds = [[NSDate date] timeIntervalSinceDate:referenceDate];
    CGFloat alpha = fabs(sin(seconds*2*M_PI/2));
    if (shoulDisplayScrollLeft)
    {
      CGContextSaveGState(cgContext);
      CGContextSetShadow(cgContext, CGSizeMake(1, -1), 3.);
      CGContextTranslateCTM(cgContext, inRoundedRect3.origin.x+10, inRoundedRect3.origin.y+inRoundedRect3.size.height/2);
      CGContextScaleCTM(cgContext, 4, 4);
      CGContextScaleCTM(cgContext, 1, -1);
      CGContextRotateCTM(cgContext, M_PI/2);
      CGContextAddLines(cgContext, trianglePoints, sizeof(trianglePoints)/sizeof(CGPoint));
      CGContextSetRGBFillColor(cgContext, 1., 0., 0., alpha);
      CGContextFillPath(cgContext);
      CGContextAddLines(cgContext, trianglePoints, sizeof(trianglePoints)/sizeof(CGPoint));
      CGContextSetLineWidth(cgContext, 1./4);
      CGContextSetRGBStrokeColor(cgContext, 1., 1., 1., alpha);
      CGContextStrokePath(cgContext);
      CGContextRestoreGState(cgContext);
    }//end if (shoulDisplayScrollLeft)
    if (shoulDisplayScrollRight)
    {
      CGContextSaveGState(cgContext);
      CGContextSetShadow(cgContext, CGSizeMake(1, -1), 3.);
      CGContextTranslateCTM(cgContext, inRoundedRect3.origin.x+inRoundedRect3.size.width-10, inRoundedRect3.origin.y+inRoundedRect3.size.height/2);
      CGContextScaleCTM(cgContext, 4, 4);
      CGContextScaleCTM(cgContext, 1, -1);
      CGContextRotateCTM(cgContext, -M_PI/2);
      CGContextAddLines(cgContext, trianglePoints, sizeof(trianglePoints)/sizeof(CGPoint));
      CGContextSetRGBFillColor(cgContext, 1., 0., 0., alpha);
      CGContextFillPath(cgContext);
      CGContextAddLines(cgContext, trianglePoints, sizeof(trianglePoints)/sizeof(CGPoint));
      CGContextSetLineWidth(cgContext, 1./4);
      CGContextSetRGBStrokeColor(cgContext, 1., 1., 1., alpha);
      CGContextStrokePath(cgContext);
      CGContextRestoreGState(cgContext);
    }//end if (shoulDisplayScrollRight)
    if (shoulDisplayScrollDown)
    {
      CGContextSaveGState(cgContext);
      CGContextSetShadow(cgContext, CGSizeMake(1, -1), 3.);
      CGContextTranslateCTM(cgContext, inRoundedRect3.origin.x+inRoundedRect3.size.width/2, inRoundedRect3.origin.y+10);
      CGContextScaleCTM(cgContext, 4, 4);
      CGContextScaleCTM(cgContext, 1, -1);
      CGContextAddLines(cgContext, trianglePoints, sizeof(trianglePoints)/sizeof(CGPoint));
      CGContextSetRGBFillColor(cgContext, 1., 0., 0., alpha);
      CGContextFillPath(cgContext);
      CGContextAddLines(cgContext, trianglePoints, sizeof(trianglePoints)/sizeof(CGPoint));
      CGContextSetLineWidth(cgContext, 1./4);
      CGContextSetRGBStrokeColor(cgContext, 1., 1., 1., alpha);
      CGContextStrokePath(cgContext);
      CGContextRestoreGState(cgContext);
    }//end if (shoulDisplayScrollDown)
    if (shoulDisplayScrollUp)
    {
      CGContextSaveGState(cgContext);
      CGContextSetShadow(cgContext, CGSizeMake(1, -1), 3.);
      CGContextTranslateCTM(cgContext, inRoundedRect3.origin.x+inRoundedRect3.size.width/2, NSMaxY(inRoundedRect3)-10);
      CGContextScaleCTM(cgContext, 4, 4);
      CGContextAddLines(cgContext, trianglePoints, sizeof(trianglePoints)/sizeof(CGPoint));
      CGContextSetRGBFillColor(cgContext, 1., 0., 0., alpha);
      CGContextFillPath(cgContext);
      CGContextAddLines(cgContext, trianglePoints, sizeof(trianglePoints)/sizeof(CGPoint));
      CGContextSetLineWidth(cgContext, 1./4);
      CGContextSetRGBStrokeColor(cgContext, 1., 1., 1., alpha);
      CGContextStrokePath(cgContext);
      CGContextRestoreGState(cgContext);
    }//end if (shoulDisplayScrollUp)
    [self performSelector:@selector(setNeedsDisplay:) withObject:[NSNumber numberWithBool:YES] afterDelay:1/25.];
  }//end if ((shoulDisplayScrollDown || shoulDisplayScrollDown))

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
  NSClipView* clipView = [[self superview] dynamicCastToClass:[NSClipView class]];
  if (!clipView)
  {
    NSScrollView* scrollView = [[NSScrollView alloc] initWithFrame:[self frame]];
    [scrollView setAutoresizingMask:[self autoresizingMask]];
    [[self superview] addSubview:scrollView];
    [scrollView release];
    [scrollView setHasHorizontalScroller:NO];
    [scrollView setHasVerticalScroller:NO];
    clipView = (NSClipView*)[scrollView contentView];
    [clipView setCopiesOnScroll:NO];
    [scrollView setDocumentView:self];
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
  [self setFrame:NSMakeRect(0, 0, MAX([scrollView contentSize].width, newSize.width), MAX([scrollView contentSize].height, newSize.height))];
}
//end updateViewSize

@end
