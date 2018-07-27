//  MyImageView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.

//The view in which the latex image is displayed is a little tuned. It knows its document
//and stores the full pdfdata (that may contain meta-data like keywords, creator...)
//Moreover, it supports drag'n drop

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

//responds to a copy event, even if the Command-C was triggered in another view (like the library view)
extern NSString* CopyCurrentImageNotification;
extern NSString* ImageDidChangeNotification;

@class LinkBack;
@class MyDocument;

@interface MyImageView : NSImageView {
  IBOutlet MyDocument* document; //link to the parent document
  CGFloat  zoomLevel;
  NSData*  pdfData; //full pdfdata (that may contain meta-data like keywords, creator...)
  NSColor* backgroundColor; //useful to prevent image from blending with background. It is different from [self image] background
  NSMenu*  copyAsContextualMenu;
  BOOL     isDragging;
}

-(IBAction) copy:(id)sender;//copy the data into clipboard
-(void)     copyAsFormat:(export_format_t)exportFormat;//copy the data into clipboard

-(CGFloat) zoomLevel;
-(void)    setZoomLevel:(CGFloat)value;

//when you set the pdfData encapsulated by the imageView, it creates an NSImage with this data.
//but if you specify a non-nil cachedImage, it will use this cachedImage to be faster
//the data is full pdfdata (that may contain meta-data like keywords, creator...)
-(void) setPDFData:(NSData*)someData cachedImage:(NSImage*)cachedImage;
-(NSData*) pdfData;

-(NSColor*) backgroundColor;
-(void) setBackgroundColor:(NSColor*)newColor updateHistoryItem:(BOOL)updateHistoryItem;

//used to update the pasteboard content for a live Linkback link
-(void) updateLinkBackLink:(LinkBack*)link;

@end
