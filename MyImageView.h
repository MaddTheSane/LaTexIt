//  MyImageView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.

//The view in which the latex image is displayed is a little tuned. It knows its document
//and stores the full pdfdata (that may contain meta-data like keywords, creator...)
//Moreover, it supports drag'n drop

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

//responds to a copy event, even if the Command-C was triggered in another view (like the library view)
extern NSNotificationName const CopyCurrentImageNotification;
extern NSNotificationName const ImageDidChangeNotification;

@class LatexitEquation;
@class LinkBack;
@class MyDocument;

@interface MyImageView : NSImageView <CALayerDelegate, NSDraggingDestination, NSDraggingSource> {
  IBOutlet    MyDocument* document; //link to the parent document
  CGFloat     zoomLevel;
  NSData*     pdfData; //full pdfdata (that may contain meta-data like keywords, creator...)
  NSSize      naturalPDFSize;
  NSImageRep* imageRep;
  NSColor*    backgroundColor; //useful to prevent image from blending with background. It is different from [self image] background
  NSMenu*     copyAsContextualMenu;
  BOOL        isDragging;
  NSPoint     lastDragStartPointSelfBased;
  BOOL        shouldRedrag;
  export_format_t transientLastExportFormat;
  NSData*         transientDragData;
  NSArray*        transientFilesPromisedFilePaths;
  LatexitEquation* transientDragEquation;
  NSView*  layerView;
  CALayer* layerArrows;
  BOOL     previousArrowsVisible[4];
}

-(void) setImage:(NSImage*)image;

-(IBAction) paste:(id)sender;
-(IBAction) copy:(id)sender;//copy the data into clipboard
-(void)     copyAsFormat:(export_format_t)exportFormat;//copy the data into clipboard

@property (nonatomic) CGFloat zoomLevel;
-(void)    updateViewSize;

//when you set the pdfData encapsulated by the imageView, it creates an NSImage with this data.
//but if you specify a non-nil cachedImage, it will use this cachedImage to be faster
//the data is full pdfdata (that may contain meta-data like keywords, creator...)
-(void) setPDFData:(NSData*)someData cachedImage:(NSImage*)cachedImage;
@property (readonly, copy) NSData *pdfData;
@property (readonly) NSSize naturalPDFSize;

@property (readonly, strong) NSColor *backgroundColor;
-(void) setBackgroundColor:(NSColor*)newColor updateHistoryItem:(BOOL)updateHistoryItem;

//used to update the pasteboard content for a live Linkback link
-(void) updateLinkBackLink:(LinkBack*)link;

@end
