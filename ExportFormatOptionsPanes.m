//
//  ExportFormatOptionsPanes.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 23/04/09.
//  Copyright 2005-2013 Pierre Chatelier. All rights reserved.
//

#import "ExportFormatOptionsPanes.h"

#import "BoolTransformer.h"
#import "ComposedTransformer.h"
#import "FileExistsTransformer.h"
#import "Utils.h"

@implementation ExportFormatOptionsPanes

-(id) initWithLoadingFromNib
{
  NSBundle* bundle = [NSBundle bundleForClass:[self class]];
  if (!(self = [super initWithNibNamed:@"ExportFormatOptionsPanes" bundle:bundle]))
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
  [self->exportFormatOptionsJpegBox setTitle:LocalLocalizedString(@"JPEG Quality", @"JPEG Quality")];
  [self->exportFormatOptionsJpegQualityLeastLabel  setStringValue:LocalLocalizedString(@"least", @"least")];
  [self->exportFormatOptionsJpegQualityLowLabel    setStringValue:LocalLocalizedString(@"low", @"low")];
  [self->exportFormatOptionsJpegQualityMediumLabel setStringValue:LocalLocalizedString(@"medium", @"medium")];
  [self->exportFormatOptionsJpegQualityHighLabel   setStringValue:LocalLocalizedString(@"high", @"high")];
  [self->exportFormatOptionsJpegQualityMaxiLabel   setStringValue:LocalLocalizedString(@"maxi", @"maxi")];
  [self->exportFormatOptionsJpegQualityLabel setStringValue:[NSString stringWithFormat:@"%@ :", LocalLocalizedString(@"Quality", @"Quality")]];
  [self->exportFormatOptionsJpegBackgroundColorLabel setStringValue:[NSString stringWithFormat:@"%@ :", LocalLocalizedString(@"Background color", @"Background color")]];
  [self->exportFormatOptionsJpegOKButton setTitle:LocalLocalizedString(@"OK", @"OK")];
  [self->exportFormatOptionsJpegCancelButton setTitle:LocalLocalizedString(@"Cancel", @"Cancel")];
  [self->exportFormatOptionsJpegQualityLeastLabel  sizeToFit];
  [self->exportFormatOptionsJpegQualityLowLabel    sizeToFit];
  [self->exportFormatOptionsJpegQualityMediumLabel sizeToFit];
  [self->exportFormatOptionsJpegQualityHighLabel   sizeToFit];
  [self->exportFormatOptionsJpegQualityMaxiLabel   sizeToFit];
  [self->exportFormatOptionsJpegQualityLabel sizeToFit];
  [self->exportFormatOptionsJpegBackgroundColorLabel sizeToFit];
  [self->exportFormatOptionsJpegOKButton sizeToFit];
  [self->exportFormatOptionsJpegCancelButton sizeToFit];
  
  [self->exportFormatOptionsJpegQualityLeastLabel setFrameOrigin:
    NSMakePoint([self->exportFormatOptionsJpegQualitySlider frame].origin.x,
                [self->exportFormatOptionsJpegQualityLeastLabel frame].origin.y)];
  [self->exportFormatOptionsJpegQualityLowLabel setFrameOrigin:
    NSMakePoint([self->exportFormatOptionsJpegQualitySlider frame].origin.x+
                1*[self->exportFormatOptionsJpegQualitySlider frame].size.width/4-[self->exportFormatOptionsJpegQualityLowLabel frame].size.width/2,
                [self->exportFormatOptionsJpegQualityLowLabel frame].origin.y)];
  [self->exportFormatOptionsJpegQualityMediumLabel setFrameOrigin:
    NSMakePoint([self->exportFormatOptionsJpegQualitySlider frame].origin.x+
                2*[self->exportFormatOptionsJpegQualitySlider frame].size.width/4-[self->exportFormatOptionsJpegQualityMediumLabel frame].size.width/2,
                [self->exportFormatOptionsJpegQualityMediumLabel frame].origin.y)];
  [self->exportFormatOptionsJpegQualityHighLabel setFrameOrigin:
    NSMakePoint([self->exportFormatOptionsJpegQualitySlider frame].origin.x+
                3*[self->exportFormatOptionsJpegQualitySlider frame].size.width/4-[self->exportFormatOptionsJpegQualityHighLabel frame].size.width/2,
                [self->exportFormatOptionsJpegQualityHighLabel frame].origin.y)];
  [self->exportFormatOptionsJpegQualityMaxiLabel setFrameOrigin:
    NSMakePoint([self->exportFormatOptionsJpegQualitySlider frame].origin.x+
                [self->exportFormatOptionsJpegQualitySlider frame].size.width-[self->exportFormatOptionsJpegQualityMaxiLabel frame].size.width,
                [self->exportFormatOptionsJpegQualityMaxiLabel frame].origin.y)];
  [self->exportFormatOptionsJpegQualityLabel setFrameOrigin:
    NSMakePoint(([self->exportFormatOptionsJpegBox frame].size.width-
                 [self->exportFormatOptionsJpegQualityLabel frame].size.width-
                 8-
                 [self->exportFormatOptionsJpegQualityTextField frame].size.width)/2,
                [self->exportFormatOptionsJpegQualityLabel frame].origin.y)];
  [self->exportFormatOptionsJpegQualityTextField setFrameOrigin:
    NSMakePoint(NSMaxX([self->exportFormatOptionsJpegQualityLabel frame])+8,
                [self->exportFormatOptionsJpegQualityTextField frame].origin.y)];
  [self->exportFormatOptionsJpegBackgroundColorLabel setFrameOrigin:
    NSMakePoint(([self->exportFormatOptionsJpegBox frame].size.width-
                 [self->exportFormatOptionsJpegBackgroundColorLabel frame].size.width-
                 8-
                 [self->exportFormatOptionsJpegBackgroundColorWell frame].size.width)/2,
                [self->exportFormatOptionsJpegBackgroundColorLabel frame].origin.y)];
  [self->exportFormatOptionsJpegBackgroundColorWell setFrameOrigin:
    NSMakePoint(NSMaxX([self->exportFormatOptionsJpegBackgroundColorLabel frame])+8,
                [self->exportFormatOptionsJpegBackgroundColorWell frame].origin.y)];
  [self->exportFormatOptionsJpegCancelButton setFrameSize:
    NSMakeSize(MAX(90, [self->exportFormatOptionsJpegCancelButton frame].size.width),
               [self->exportFormatOptionsJpegCancelButton frame].size.height)];
  [self->exportFormatOptionsJpegOKButton setFrameSize:[self->exportFormatOptionsJpegCancelButton frame].size];
  [self->exportFormatOptionsJpegOKButton setFrameOrigin:
    NSMakePoint(NSMaxX([self->exportFormatOptionsJpegBox frame])-[self->exportFormatOptionsJpegOKButton frame].size.width,
                [self->exportFormatOptionsJpegOKButton frame].origin.y)];
  [self->exportFormatOptionsJpegCancelButton setFrameOrigin:
    NSMakePoint([self->exportFormatOptionsJpegOKButton frame].origin.x-12-[self->exportFormatOptionsJpegCancelButton frame].size.width,
                [self->exportFormatOptionsJpegCancelButton frame].origin.y)];

  [self->exportFormatOptionsSvgBox setTitle:LocalLocalizedString(@"Path to pdf2svg", @"Path to pdf2svg")];
  [self->exportFormatOptionsSvgPdfToSvgPathModifyButton setTitle:[NSString stringWithFormat:@"%@...", LocalLocalizedString(@"Change", @"Change")]];
  [self->exportFormatOptionsSvgOKButton setTitle:LocalLocalizedString(@"OK", @"OK")];
  [self->exportFormatOptionsSvgCancelButton setTitle:LocalLocalizedString(@"Cancel", @"Cancel")];
  [self->exportFormatOptionsSvgPdfToSvgPathModifyButton sizeToFit];
  [self->exportFormatOptionsSvgOKButton sizeToFit];
  [self->exportFormatOptionsSvgCancelButton sizeToFit];
  [self->exportFormatOptionsSvgPdfToSvgPathModifyButton setFrameOrigin:
    NSMakePoint([self->exportFormatOptionsSvgBox frame].size.width-16-
                [self->exportFormatOptionsSvgPdfToSvgPathModifyButton frame].size.width,
                [self->exportFormatOptionsSvgPdfToSvgPathModifyButton frame].origin.y)];
  [self->exportFormatOptionsSvgPdfToSvgPathTextField setFrameSize:
    NSMakeSize([self->exportFormatOptionsSvgPdfToSvgPathModifyButton frame].origin.x-8-10,
               [self->exportFormatOptionsSvgPdfToSvgPathTextField frame].size.height)];
  [self->exportFormatOptionsSvgCancelButton setFrameSize:
    NSMakeSize(MAX(90, [self->exportFormatOptionsSvgCancelButton frame].size.width),
               [self->exportFormatOptionsSvgCancelButton frame].size.height)];
  [self->exportFormatOptionsSvgOKButton setFrameSize:[self->exportFormatOptionsSvgCancelButton frame].size];
  [self->exportFormatOptionsSvgOKButton setFrameOrigin:
    NSMakePoint(NSMaxX([self->exportFormatOptionsSvgBox frame])-[self->exportFormatOptionsSvgOKButton frame].size.width,
                [self->exportFormatOptionsSvgOKButton frame].origin.y)];
  [self->exportFormatOptionsSvgCancelButton setFrameOrigin:
    NSMakePoint([self->exportFormatOptionsSvgOKButton frame].origin.x-12-[self->exportFormatOptionsSvgCancelButton frame].size.width,
                [self->exportFormatOptionsSvgCancelButton frame].origin.y)];

  NSDictionary* colorForFileExistsBindingOptions =
    [NSDictionary dictionaryWithObjectsAndKeys:
      [ComposedTransformer
        transformerWithValueTransformer:[FileExistsTransformer transformerWithDirectoryAllowed:NO]
             additionalValueTransformer:[BoolTransformer transformerWithFalseValue:[NSColor redColor] trueValue:[NSColor controlTextColor]]
             additionalKeyPath:nil], NSValueTransformerBindingOption, nil];

  [self->exportFormatOptionsJpegQualitySlider bind:NSValueBinding toObject:self withKeyPath:@"jpegQualityPercent"
    options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
  [self->exportFormatOptionsJpegQualityTextField bind:NSValueBinding toObject:self withKeyPath:@"jpegQualityPercent"
    options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
  [self->exportFormatOptionsJpegBackgroundColorWell bind:NSValueBinding toObject:self withKeyPath:@"jpegBackgroundColor" options:nil];
  [self->exportFormatOptionsSvgPdfToSvgPathTextField bind:NSValueBinding toObject:self withKeyPath:@"svgPdfToSvgPath" options:nil];
  [self->exportFormatOptionsSvgPdfToSvgPathTextField bind:NSTextColorBinding toObject:self withKeyPath:@"svgPdfToSvgPath"
    options:colorForFileExistsBindingOptions];
}
//end awakeFromNib

#pragma mark JPEG

-(NSPanel*) exportFormatOptionsJpegPanel
{
  return self->exportFormatOptionsJpegPanel;
}
//end exportFormatOptionsJpegPanel

-(CGFloat) jpegQualityPercent
{
  return self->jpegQualityPercent;
}
//end jpegQualityPercent

-(void) setJpegQualityPercent:(CGFloat)value
{
  [self willChangeValueForKey:@"jpegQualityPercent"];
  self->jpegQualityPercent = value;
  [self didChangeValueForKey:@"jpegQualityPercent"];
}
//end setJpegQualityPercent:

-(NSColor*) jpegBackgroundColor
{
  return self->jpegBackgroundColor;
}
//end jpegBackgroundColor

-(void) setJpegBackgroundColor:(NSColor*)value
{
  [value retain];
  [self willChangeValueForKey:@"jpegBackgroundColor"];
  [self->jpegBackgroundColor release];
  self->jpegBackgroundColor = value;
  [self didChangeValueForKey:@"jpegBackgroundColor"];
}
//end setJpegBackgroundColor:

-(id) exportFormatOptionsJpegPanelDelegate
{
  return self->exportFormatOptionsJpegPanelDelegate;
}
//end exportFormatOptionsJpegPanelDelegate

-(void) setExportFormatOptionsJpegPanelDelegate:(id)delegate
{
  self->exportFormatOptionsJpegPanelDelegate = delegate;
}
//end setExportFormatOptionsJpegPanelDelegate:

#pragma mark SVG

-(NSPanel*) exportFormatOptionsSvgPanel
{
  return self->exportFormatOptionsSvgPanel;
}
//end exportFormatOptionsSvgPanel

-(NSString*) svgPdfToSvgPath
{
  return self->svgPdfToSvgPath;
}
//end svgPdfToSvgPath

-(void) setSvgPdfToSvgPath:(NSString*)value
{
  [value retain];
  [self willChangeValueForKey:@"svgPdfToSvgPath"];
  [self->svgPdfToSvgPath release];
  self->svgPdfToSvgPath = value;
  [self didChangeValueForKey:@"svgPdfToSvgPath"];
}
//end setSvgPdfToSvgPath:

-(id) exportFormatOptionsSvgPanelDelegate
{
  return self->exportFormatOptionsSvgPanelDelegate;
}
//end exportFormatOptionsSvgPanelDelegate

-(void) setExportFormatOptionsSvgPanelDelegate:(id)delegate
{
  self->exportFormatOptionsSvgPanelDelegate = delegate;
}
//end setExportFormatOptionsSvgPanelDelegate:

-(IBAction) svgPdfToSvgPathModify:(id)sender
{
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  [openPanel setResolvesAliases:YES];
  NSString* filePath = [self svgPdfToSvgPath];
  NSString* filename =[filePath lastPathComponent];
  NSString* directory = [filePath stringByDeletingLastPathComponent];
  int result = [openPanel runModalForDirectory:directory file:filename];
  if (result == NSFileHandlingPanelOKButton)
  {
    filePath = [[openPanel URL] path];
    [self setSvgPdfToSvgPath:filePath];
  }//end if (result == NSFileHandlingPanelOKButton)
}
//end svgPdfToSvgPathModify:

#pragma mark BOTH

-(IBAction) close:(id)sender
{
  int senderTag = [sender tag];
  if ((senderTag == 0) || (senderTag == 1))
    [self exportFormatOptionsPanel:self->exportFormatOptionsJpegPanel didCloseWithOK:(senderTag == 0)];
  else if ((senderTag == 2) || (senderTag == 3))
    [self exportFormatOptionsPanel:self->exportFormatOptionsSvgPanel didCloseWithOK:(senderTag == 2)];
}
//end close:

#pragma mark delegate
-(void) exportFormatOptionsPanel:(NSPanel*)exportFormatOptionsPanel didCloseWithOK:(BOOL)ok
{
  if ((exportFormatOptionsPanel == self->exportFormatOptionsJpegPanel) &&
      [self->exportFormatOptionsJpegPanelDelegate respondsToSelector:@selector(exportFormatOptionsPanel:didCloseWithOK:)])
    [self->exportFormatOptionsJpegPanelDelegate exportFormatOptionsPanel:exportFormatOptionsPanel didCloseWithOK:ok];
  else if ((exportFormatOptionsPanel == self->exportFormatOptionsSvgPanel) &&
      [self->exportFormatOptionsSvgPanelDelegate respondsToSelector:@selector(exportFormatOptionsPanel:didCloseWithOK:)])
    [self->exportFormatOptionsSvgPanelDelegate exportFormatOptionsPanel:exportFormatOptionsPanel didCloseWithOK:ok];
}
//end exportFormatOptionsPanel:didCloseWithOK:

@end
