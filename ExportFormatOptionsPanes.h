//
//  ExportFormatOptionsPanes.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 23/04/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ExportFormatOptionsPanes : NSNib {
  IBOutlet NSPanel*     exportFormatOptionsJpegPanel;
  IBOutlet NSSlider*    exportFormatOptionsJpegQualitySlider;
  IBOutlet NSTextField* exportFormatOptionsJpegQualityTextField;
  IBOutlet NSColorWell* exportFormatOptionsJpegBackgroundColorWell;
  
  CGFloat  jpegQualityPercent;
  NSColor* jpegBackgroundColor;
  id       exportFormatOptionsJpegPanelDelegate;
}

-(id) initWithLoadingFromNib;

-(NSPanel*) exportFormatOptionsJpegPanel;

-(CGFloat) jpegQualityPercent;
-(void)    setJpegQualityPercent:(CGFloat)value;

-(NSColor*) jpegBackgroundColor;
-(void)     setJpegBackgroundColor:(NSColor*)value;

-(id) exportFormatOptionsJpegPanelDelegate;
-(void) setExportFormatOptionsJpegPanelDelegate:(id)delegate;

-(IBAction) close:(id)sender;

#pragma mark delegate
-(void) exportFormatOptionsJpegPanel:(ExportFormatOptionsPanes*)exportFormatOptionsPanes didCloseWithOK:(BOOL)ok;

@end
