//
//  ExportFormatOptionsPanes.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 23/04/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.
//

#import "ExportFormatOptionsPanes.h"

@implementation ExportFormatOptionsPanes

-(id) initWithLoadingFromNib
{
  if ((!(self = [super initWithNibNamed:@"ExportFormatOptionsPanes" bundle:nil])))
    return nil;
  [self instantiateNibWithOwner:self topLevelObjects:nil];
  self->jpegQualityPercent  = 90.f;
  self->jpegBackgroundColor = [[NSColor whiteColor] retain];
  return self;
}
//end initWithLoadingFromNib:

-(void) dealloc
{
  [self->jpegBackgroundColor release];
  [super dealloc];
}
//end dealloc

-(void) awakeFromNib
{
  [self->exportFormatOptionsJpegQualitySlider bind:NSValueBinding toObject:self withKeyPath:@"jpegQualityPercent"
    options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
  [self->exportFormatOptionsJpegQualityTextField bind:NSValueBinding toObject:self withKeyPath:@"jpegQualityPercent"
    options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
  [self->exportFormatOptionsJpegBackgroundColorWell bind:NSValueBinding toObject:self withKeyPath:@"jpegBackgroundColor" options:nil];
}
//end awakeFromNib

-(NSPanel*) exportFormatOptionsJpegPanel {return self->exportFormatOptionsJpegPanel;}

-(CGFloat) jpegQualityPercent {return self->jpegQualityPercent;}
-(void)    setJpegQualityPercent:(CGFloat)value
{
  [self willChangeValueForKey:@"jpegQualityPercent"];
  self->jpegQualityPercent = value;
  [self didChangeValueForKey:@"jpegQualityPercent"];
}
//end setJpegQualityPercent:

-(NSColor*) jpegBackgroundColor {return self->jpegBackgroundColor;}
-(void)     setJpegBackgroundColor:(NSColor*)value
{
  [value retain];
  [self willChangeValueForKey:@"jpegBackgroundColor"];
  [self->jpegBackgroundColor release];
  self->jpegBackgroundColor = value;
  [self didChangeValueForKey:@"jpegBackgroundColor"];
}
//end setJpegBackgroundColor:

-(id) exportFormatOptionsJpegPanelDelegate {return self->exportFormatOptionsJpegPanelDelegate;}
-(void) setExportFormatOptionsJpegPanelDelegate:(id)delegate {self->exportFormatOptionsJpegPanelDelegate = delegate;}

-(IBAction) close:(id)sender
{
  [self exportFormatOptionsJpegPanel:self didCloseWithOK:([sender tag] == 0)];
}
//end close:

#pragma mark delegate
-(void) exportFormatOptionsJpegPanel:(ExportFormatOptionsPanes*)exportFormatOptionsPanes didCloseWithOK:(BOOL)ok
{
  if ([self->exportFormatOptionsJpegPanelDelegate respondsToSelector:@selector(exportFormatOptionsJpegPanel:didCloseWithOK:)])
    [self->exportFormatOptionsJpegPanelDelegate exportFormatOptionsJpegPanel:self didCloseWithOK:ok];
}
//end exportFormatOptionsJpegPanel:didCloseWithOK:

@end
