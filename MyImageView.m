//  MyImageView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.

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
#import "NSManagedObjectContextExtended.h"
#import "NSMenuExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"
#import "Utils.h"

#import "CGExtras.h"

#import <LinkBack/LinkBack.h>
#import <Quartz/Quartz.h>

//responds to a copy event, even if the Command-C was triggered in another view (like the library view)
NSString* CopyCurrentImageNotification = @"CopyCurrentImageNotification";
NSString* ImageDidChangeNotification = @"ImageDidChangeNotification";

@interface MyImageView (PrivateAPI)
-(NSMenu*) lazyCopyAsContextualMenu;
-(void) _writeToPasteboard:(NSPasteboard*)pasteboard isLinkBackRefresh:(BOOL)isLinkBackRefresh lazyDataProvider:(id)lazyDataProvider;
-(void) _copyCurrentImageNotification:(NSNotification*)notification;
-(BOOL) _applyDataFromPasteboard:(NSPasteboard*)pboard;
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
                              NSRTFDPboardType, NSRTFPboardType, GetWebURLsWithTitlesPboardType(), NSStringPboardType, nil]];
  return self;
}
//end initWithCoder:

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self->copyAsContextualMenu release];
  [self->backgroundColor release];
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
    [self setPDFData:[[document latexitEquationWithCurrentStateTransient:NO] annotatedPDFDataUsingPDFKeywords:YES] cachedImage:[self image]];
}

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
      [[document lowerBoxLatexizeButton] performClick:self];
  }
  return handlesEvent;
}
//end performKeyEquivalent:

-(NSData*) pdfData //full pdfdata (that may contain meta-data like keywords, creator...)
{
  return self->pdfData;
}
//end pdfData:

//when you set the pdfData encapsulated by the imageView, it creates an NSImage with this data.
//but if you specify a non-nil cachedImage, it will use this cachedImage to be faster
//the data is full pdfdata (that may contain meta-data like keywords, creator...)
-(void) setPDFData:(NSData*)someData cachedImage:(NSImage*)cachedImage
{
  [someData retain];
  [self->pdfData release];
  self->pdfData = someData;

  NSImage* image = cachedImage;
  if (!image && self->pdfData)
  {
    NSPDFImageRep* pdfImageRep = [[NSPDFImageRep alloc] initWithData:self->pdfData];
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

-(unsigned int) draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  unsigned int result = [self image] ? NSDragOperationCopy : NSDragOperationNone;
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
  }
}
//end keyDown:

//begins a drag operation
-(void) mouseDown:(NSEvent*)theEvent
{
  if ([theEvent modifierFlags] & NSControlKeyMask)
    [super mouseDown:theEvent];
  else
  {
    [super mouseDown:theEvent];
  }
}
//end mouseDown:

-(void) mouseDragged:(NSEvent *)theEvent
{
  if (!self->isDragging && !([theEvent modifierFlags] & NSControlKeyMask))
  {
    NSImage* draggedImage = [self image];
    if (draggedImage)
    {
      self->isDragging = YES;
      [self dragPromisedFilesOfTypes:[NSArray arrayWithObjects:@"pdf", @"eps", @"tiff", @"jpeg", @"png", nil]
                            fromRect:[self frame] source:self slideBack:YES event:theEvent];
      self->isDragging = NO;
    }
  }//end if (!self->isDragging)
  [super mouseDragged:theEvent];
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
  if (self->isDragging)
  {
    [[[AppController appController] dragFilterWindowController] setWindowVisible:NO withAnimation:YES];
    [[[AppController appController] dragFilterWindowController] setDelegate:nil];
  }
  self->isDragging = NO;
}
//end draggedImage:endedAt:operation:

-(void) dragImage:(NSImage*)image at:(NSPoint)at offset:(NSSize)offset event:(NSEvent*)event
       pasteboard:(NSPasteboard*)pasteboard source:(id)object slideBack:(BOOL)slideBack
{
  NSImage* draggedImage = [self image];
  NSImage* iconDragged = draggedImage;
  NSSize   iconSize = [iconDragged size];
  NSPoint p = [self convertPoint:[event locationInWindow] fromView:nil];
  p.x -= iconSize.width/2;
  p.y -= iconSize.height/2;
  
  [[[AppController appController] dragFilterWindowController] setWindowVisible:YES withAnimation:YES atPoint:
    [[self window] convertBaseToScreen:[event locationInWindow]]];
  [[[AppController appController] dragFilterWindowController] setDelegate:self];

  [self _writeToPasteboard:pasteboard isLinkBackRefresh:NO lazyDataProvider:self];

  if (!isMacOS10_5OrAbove())
  {
    NSImage* tiffImage = [[[NSImage alloc] initWithData:[draggedImage TIFFRepresentation]] autorelease];
    draggedImage = tiffImage;
  }
  [super dragImage:draggedImage at:p offset:offset event:event pasteboard:pasteboard source:object slideBack:YES];
}
//end dragImage:at:offset:event:pasteboard:source:slideBack:

-(void) concludeDragOperation:(id <NSDraggingInfo>)sender
{
  //overridden to avoid some strange additional "setImage" that would occur...
}
//end concludeDragOperation:

-(void) dragFilterWindowController:(DragFilterWindowController*)dragFilterWindowController exportFormatDidChange:(export_format_t)exportFormat
{
  NSPasteboard* pasteboard = [NSPasteboard pasteboardWithName:NSDragPboard];
  //[pasteboard declareTypes:[NSArray array] owner:self];
  [self _writeToPasteboard:pasteboard isLinkBackRefresh:NO lazyDataProvider:self];
}
//end dragFilterWindowController:exportFormatDidChange:

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
    }

    NSColor*   color = [preferencesController exportJpegBackgroundColor];
    CGFloat  quality = [preferencesController exportJpegQualityPercent];
    NSData* data = [[LaTeXProcessor sharedLaTeXProcessor] dataForType:exportFormat pdfData:self->pdfData jpegColor:color
                                                  jpegQuality:quality scaleAsPercent:[preferencesController exportScalePercent]
                                                  compositionConfiguration:[preferencesController compositionConfigurationDocument]];
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
-(void) pasteboard:(NSPasteboard *)pasteboard provideDataForType:(NSString *)type
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  export_format_t exportFormat = [preferencesController exportFormatCurrentSession];
  NSData* data = [[LaTeXProcessor sharedLaTeXProcessor]
    dataForType:exportFormat pdfData:self->pdfData jpegColor:[preferencesController exportJpegBackgroundColor]
    jpegQuality:[preferencesController exportJpegQualityPercent] scaleAsPercent:[preferencesController exportScalePercent]
    compositionConfiguration:[preferencesController compositionConfigurationDocument]];
  [pasteboard setData:data forType:type];
}
//end pasteboard:provideDataForType:

//We can drop on the imageView only if the PDF has been made by LaTeXiT (as "creator" document attribute)
//So, the keywords of the PDF contain the whole document state
-(NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
  BOOL ok = NO;
  BOOL shouldBePDFData = NO;
  NSData* data = nil;
  NSString* type = nil;
  
  NSPasteboard* pboard = [sender draggingPasteboard];
  if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSColorPboardType]])
    ok = YES;
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSPDFPboardType]])
  {
    shouldBePDFData = YES;
    data = self->isDragging ? self->pdfData : [pboard dataForType:NSPDFPboardType];
  }
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:@"com.adobe.pdf"]])
  {
    shouldBePDFData = YES;
    data = self->isDragging ? self->pdfData : [pboard dataForType:@"com.adobe.pdf"];
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
      data = [NSData dataWithContentsOfFile:filename options:NSUncachedRead error:nil];
    }
  }
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObjects:GetWebURLsWithTitlesPboardType(), nil]])
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
  }
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObjects:NSRTFPboardType, NSStringPboardType, nil]])
    ok = YES;
  
  if (shouldBePDFData)
  {
    ok = (data != nil);
    if (ok)
    {
      PDFDocument* pdfDocument = [[PDFDocument alloc] initWithData:data];
      ok &= (pdfDocument != nil);
      [pdfDocument release];
    }
  }

  return ok ? NSDragOperationCopy : NSDragOperationNone;
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
      [document applyLibraryEquation:libraryEquation];
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
      [document applyLibraryEquation:libraryEquation];
    done = YES;
  }
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:LatexitEquationsPboardType]]))
  {
    NSArray* latexitEquationsArray = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:type]];
    [document applyLatexitEquation:[latexitEquationsArray lastObject] isRecentLatexisation:NO];
    done = YES;
  }
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"com.adobe.pdf", NSPDFPboardType, nil]]))
    done = [document applyPdfData:[pboard dataForType:type]];
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFileContentsPboardType]]))
    done = [document applyPdfData:[pboard dataForType:type]];
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]]))
  {
    NSArray* plist = [pboard propertyListForType:type];
    NSData* data = (plist && [plist count]) ? [NSData dataWithContentsOfFile:[plist objectAtIndex:0] options:NSUncachedRead error:nil] : nil;
    done = [document applyPdfData:data];
  }

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
      }
    }
    if (concats)
      [document applyString:concats];
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
      done = [document applyPdfData:pdfWrapperData];
    [attributedString release];
  }
  if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"public.rtf", NSRTFPboardType, nil]])))
  {
    NSData* rtfData = [pboard dataForType:type];
    NSDictionary* docAttributes = nil;
    NSAttributedString* attributedString = [[NSAttributedString alloc] initWithRTF:rtfData documentAttributes:&docAttributes];
    [document applyString:[attributedString string]];
    [attributedString release];
    done = YES;
  }
  if (!done && ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"public.text", NSStringPboardType, nil]])))
  {
    [document applyString:[pboard stringForType:type]];
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
  if (backgroundColor)
  {
    [backgroundColor set];
    NSRectFill(inRect);
  }
  [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
  [[image bestRepresentationForDevice:nil] drawInRect:destRect];
}
//end drawRect:

@end
