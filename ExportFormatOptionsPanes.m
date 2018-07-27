//
//  ExportFormatOptionsPanes.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 23/04/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#if !__has_feature(objc_arc)
#error This must be built with ARC
#endif

#import "ExportFormatOptionsPanes.h"

#import "BoolTransformer.h"
#import "ComposedTransformer.h"
#import "FileExistsTransformer.h"
#import "Utils.h"

@implementation ExportFormatOptionsPanes
@synthesize exportFormatOptionsTextPanelDelegate;
@synthesize svgPdfToSvgPath;
@synthesize exportFormatOptionsSvgPanelDelegate;
@synthesize textExportPreamble;
@synthesize textExportEnvironment;
@synthesize textExportBody;
@synthesize jpegQualityPercent;
@synthesize jpegBackgroundColor;
@synthesize exportFormatOptionsJpegPanelDelegate;
@synthesize exportFormatOptionsTextBox;
@synthesize exportFormatOptionsSvgPanel;
@synthesize exportFormatOptionsJpegPanel;
@synthesize exportFormatOptionsTextPanel;


-(id) initWithLoadingFromNib
{
  NSBundle* bundle = [NSBundle bundleForClass:[self class]];
  if (!(self = [super initWithNibNamed:@"ExportFormatOptionsPanes" bundle:bundle]))
    return nil;
  [self instantiateNibWithOwner:self topLevelObjects:nil];
  jpegQualityPercent  = 90.f;
  jpegBackgroundColor = [NSColor whiteColor];
  textExportPreamble = YES;
  textExportEnvironment = YES;
  textExportBody = YES;
  pdfWofGSWriteEngine = @"pdfwrite";
  pdfWofGSPDFCompatibilityLevel = @"1.5";
  pdfWofMetaDataInvisibleGraphicsEnabled = YES;
  return self;
}
//end initWithLoadingFromNib:


-(void) awakeFromNib
{
  [exportFormatOptionsJpegBox setTitle:LocalLocalizedString(@"JPEG Quality", @"JPEG Quality")];
  [exportFormatOptionsJpegQualityLeastLabel  setStringValue:LocalLocalizedString(@"least", @"least")];
  [exportFormatOptionsJpegQualityLowLabel    setStringValue:LocalLocalizedString(@"low", @"low")];
  [exportFormatOptionsJpegQualityMediumLabel setStringValue:LocalLocalizedString(@"medium", @"medium")];
  [exportFormatOptionsJpegQualityHighLabel   setStringValue:LocalLocalizedString(@"high", @"high")];
  [exportFormatOptionsJpegQualityMaxiLabel   setStringValue:LocalLocalizedString(@"maxi", @"maxi")];
  [exportFormatOptionsJpegQualityLabel setStringValue:[NSString stringWithFormat:@"%@ :", LocalLocalizedString(@"Quality", @"Quality")]];
  [exportFormatOptionsJpegBackgroundColorLabel setStringValue:[NSString stringWithFormat:@"%@ :", LocalLocalizedString(@"Background color", @"Background color")]];
  [exportFormatOptionsJpegOKButton setTitle:LocalLocalizedString(@"OK", @"OK")];
  [exportFormatOptionsJpegCancelButton setTitle:LocalLocalizedString(@"Cancel", @"Cancel")];
  [exportFormatOptionsJpegQualityLeastLabel  sizeToFit];
  [exportFormatOptionsJpegQualityLowLabel    sizeToFit];
  [exportFormatOptionsJpegQualityMediumLabel sizeToFit];
  [exportFormatOptionsJpegQualityHighLabel   sizeToFit];
  [exportFormatOptionsJpegQualityMaxiLabel   sizeToFit];
  [exportFormatOptionsJpegQualityLabel sizeToFit];
  [exportFormatOptionsJpegBackgroundColorLabel sizeToFit];
  [exportFormatOptionsJpegOKButton sizeToFit];
  [exportFormatOptionsJpegCancelButton sizeToFit];

  [exportFormatOptionsJpegQualityLeastLabel setFrameOrigin:
    NSMakePoint([exportFormatOptionsJpegQualitySlider frame].origin.x,
                [exportFormatOptionsJpegQualityLeastLabel frame].origin.y)];
  [exportFormatOptionsJpegQualityLowLabel setFrameOrigin:
    NSMakePoint([exportFormatOptionsJpegQualitySlider frame].origin.x+
                1*[exportFormatOptionsJpegQualitySlider frame].size.width/4-[exportFormatOptionsJpegQualityLowLabel frame].size.width/2,
                [exportFormatOptionsJpegQualityLowLabel frame].origin.y)];
  [exportFormatOptionsJpegQualityMediumLabel setFrameOrigin:
    NSMakePoint([exportFormatOptionsJpegQualitySlider frame].origin.x+
                2*[exportFormatOptionsJpegQualitySlider frame].size.width/4-[exportFormatOptionsJpegQualityMediumLabel frame].size.width/2,
                [exportFormatOptionsJpegQualityMediumLabel frame].origin.y)];
  [exportFormatOptionsJpegQualityHighLabel setFrameOrigin:
    NSMakePoint([exportFormatOptionsJpegQualitySlider frame].origin.x+
                3*[exportFormatOptionsJpegQualitySlider frame].size.width/4-[exportFormatOptionsJpegQualityHighLabel frame].size.width/2,
                [exportFormatOptionsJpegQualityHighLabel frame].origin.y)];
  [exportFormatOptionsJpegQualityMaxiLabel setFrameOrigin:
    NSMakePoint([exportFormatOptionsJpegQualitySlider frame].origin.x+
                [exportFormatOptionsJpegQualitySlider frame].size.width-[exportFormatOptionsJpegQualityMaxiLabel frame].size.width,
                [exportFormatOptionsJpegQualityMaxiLabel frame].origin.y)];
  [exportFormatOptionsJpegQualityLabel setFrameOrigin:
    NSMakePoint(([exportFormatOptionsJpegBox frame].size.width-
                 [exportFormatOptionsJpegQualityLabel frame].size.width-
                 8-
                 [exportFormatOptionsJpegQualityTextField frame].size.width)/2,
                [exportFormatOptionsJpegQualityLabel frame].origin.y)];
  [exportFormatOptionsJpegQualityTextField setFrameOrigin:
    NSMakePoint(NSMaxX([exportFormatOptionsJpegQualityLabel frame])+8,
                [exportFormatOptionsJpegQualityTextField frame].origin.y)];
  [exportFormatOptionsJpegBackgroundColorLabel setFrameOrigin:
    NSMakePoint(([exportFormatOptionsJpegBox frame].size.width-
                 [exportFormatOptionsJpegBackgroundColorLabel frame].size.width-
                 8-
                 [exportFormatOptionsJpegBackgroundColorWell frame].size.width)/2,
                [exportFormatOptionsJpegBackgroundColorLabel frame].origin.y)];
  [exportFormatOptionsJpegBackgroundColorWell setFrameOrigin:
    NSMakePoint(NSMaxX([exportFormatOptionsJpegBackgroundColorLabel frame])+8,
                [exportFormatOptionsJpegBackgroundColorWell frame].origin.y)];
  [exportFormatOptionsJpegCancelButton setFrameSize:
    NSMakeSize(MAX(90, [exportFormatOptionsJpegCancelButton frame].size.width),
               [exportFormatOptionsJpegCancelButton frame].size.height)];
  [exportFormatOptionsJpegOKButton setFrameSize:[exportFormatOptionsJpegCancelButton frame].size];
  [exportFormatOptionsJpegOKButton setFrameOrigin:
    NSMakePoint(NSMaxX([exportFormatOptionsJpegBox frame])-[exportFormatOptionsJpegOKButton frame].size.width,
                [exportFormatOptionsJpegOKButton frame].origin.y)];
  [exportFormatOptionsJpegCancelButton setFrameOrigin:
    NSMakePoint([exportFormatOptionsJpegOKButton frame].origin.x-12-[exportFormatOptionsJpegCancelButton frame].size.width,
                [exportFormatOptionsJpegCancelButton frame].origin.y)];

  [exportFormatOptionsSvgBox setTitle:LocalLocalizedString(@"Path to pdf2svg", @"Path to pdf2svg")];
  [exportFormatOptionsSvgPdfToSvgPathModifyButton setTitle:[NSString stringWithFormat:@"%@...", LocalLocalizedString(@"Change", @"Change")]];
  [exportFormatOptionsSvgOKButton setTitle:LocalLocalizedString(@"OK", @"OK")];
  [exportFormatOptionsSvgCancelButton setTitle:LocalLocalizedString(@"Cancel", @"Cancel")];
  [exportFormatOptionsSvgPdfToSvgPathModifyButton sizeToFit];
  [exportFormatOptionsSvgOKButton sizeToFit];
  [exportFormatOptionsSvgCancelButton sizeToFit];
  [exportFormatOptionsSvgPdfToSvgPathModifyButton setFrameOrigin:
    NSMakePoint([exportFormatOptionsSvgBox frame].size.width-16-
                [exportFormatOptionsSvgPdfToSvgPathModifyButton frame].size.width,
                [exportFormatOptionsSvgPdfToSvgPathModifyButton frame].origin.y)];
  [exportFormatOptionsSvgPdfToSvgPathTextField setFrameSize:
    NSMakeSize([exportFormatOptionsSvgPdfToSvgPathModifyButton frame].origin.x-8-10,
               [exportFormatOptionsSvgPdfToSvgPathTextField frame].size.height)];
  [exportFormatOptionsSvgCancelButton setFrameSize:
    NSMakeSize(MAX(90, [exportFormatOptionsSvgCancelButton frame].size.width),
               [exportFormatOptionsSvgCancelButton frame].size.height)];
  [exportFormatOptionsSvgOKButton setFrameSize:[exportFormatOptionsSvgCancelButton frame].size];
  [exportFormatOptionsSvgOKButton setFrameOrigin:
    NSMakePoint(NSMaxX([exportFormatOptionsSvgBox frame])-[exportFormatOptionsSvgOKButton frame].size.width,
                [exportFormatOptionsSvgOKButton frame].origin.y)];
  [exportFormatOptionsSvgCancelButton setFrameOrigin:
    NSMakePoint([exportFormatOptionsSvgOKButton frame].origin.x-12-[exportFormatOptionsSvgCancelButton frame].size.width,
                [exportFormatOptionsSvgCancelButton frame].origin.y)];

  NSDictionary* colorForFileExistsBindingOptions =
    [NSDictionary dictionaryWithObjectsAndKeys:
      [ComposedTransformer
        transformerWithValueTransformer:[FileExistsTransformer transformerWithDirectoryAllowed:NO]
             additionalValueTransformer:[BoolTransformer transformerWithFalseValue:[NSColor redColor] trueValue:[NSColor controlTextColor]]
             additionalKeyPath:nil], NSValueTransformerBindingOption, nil];

  [exportFormatOptionsTextExportPreambleButton setTitle:LocalLocalizedString(@"Export preamble", @"Export preamble")];
  [exportFormatOptionsTextExportPreambleButton sizeToFit];
  [exportFormatOptionsTextExportEnvironmentButton setTitle:LocalLocalizedString(@"Export environment", @"Export environment")];
  [exportFormatOptionsTextExportEnvironmentButton sizeToFit];
  [exportFormatOptionsTextExportBodyButton setTitle:LocalLocalizedString(@"Export body", @"Export body")];
  [exportFormatOptionsTextExportBodyButton sizeToFit];
  [exportFormatOptionsTextOKButton setTitle:LocalLocalizedString(@"OK", @"OK")];
  [exportFormatOptionsTextCancelButton setTitle:LocalLocalizedString(@"Cancel", @"Cancel")];
  [exportFormatOptionsTextOKButton sizeToFit];
  [exportFormatOptionsTextCancelButton sizeToFit];
  [exportFormatOptionsTextCancelButton setFrameSize:
   NSMakeSize(MAX(90, [exportFormatOptionsTextCancelButton frame].size.width),
              [exportFormatOptionsTextCancelButton frame].size.height)];
  [exportFormatOptionsTextOKButton setFrameSize:[exportFormatOptionsTextCancelButton frame].size];
  [exportFormatOptionsTextOKButton setFrameOrigin:
   NSMakePoint(NSMaxX([exportFormatOptionsTextBox frame])-[exportFormatOptionsTextOKButton frame].size.width,
               [exportFormatOptionsTextOKButton frame].origin.y)];
  [exportFormatOptionsTextCancelButton setFrameOrigin:
   NSMakePoint([exportFormatOptionsTextOKButton frame].origin.x-12-[exportFormatOptionsTextCancelButton frame].size.width,
               [exportFormatOptionsTextCancelButton frame].origin.y)];
  
  [self->exportFormatOptionsPDFWofGSBox setTitle:LocalLocalizedString(@"Ghostscript options", @"Ghostscript options")];
  [self->exportFormatOptionsPDFWofGSWriteEngineLabel setStringValue:[NSString stringWithFormat:@"%@:",LocalLocalizedString(@"Write engine", @"Write engine")]];
  [self->exportFormatOptionsPDFWofGSPDFCompatibilityLevelLabel setStringValue:[NSString stringWithFormat:@"%@:",LocalLocalizedString(@"PDF Compatibility level", @"PDF Compatibility level")]];
  [self->exportFormatOptionsPDFWofMetaDataInvisibleGraphicsEnabledCheckBox setTitle:NSLocalizedString(@"Add invisible graphic commands", @"Add invisible graphic commands")];
  [self->exportFormatOptionsPDFWofGSWriteEngineLabel sizeToFit];
  [self->exportFormatOptionsPDFWofGSPDFCompatibilityLevelLabel sizeToFit];
  [self->exportFormatOptionsPDFWofGSWriteEnginePopUpButton sizeToFit];
  [self->exportFormatOptionsPDFWofGSPDFCompatibilityLevelPopUpButton sizeToFit];
  [self->exportFormatOptionsPDFWofMetadataBox setTitle:LocalLocalizedString(@"LaTeXiT medata", @"LaTeXiT medata")];  
  [self->exportFormatOptionsPDFWofMetaDataInvisibleGraphicsEnabledCheckBox sizeToFit];
  [self->exportFormatOptionsPDFWofOKButton sizeToFit];
  [self->exportFormatOptionsPDFWofCancelButton sizeToFit];
  
  [self->exportFormatOptionsPDFWofGSWriteEnginePopUpButton setFrame:
   NSMakeRect(MAX(CGRectGetMaxX(NSRectToCGRect([self->exportFormatOptionsPDFWofGSWriteEngineLabel frame])),
                  CGRectGetMaxX(NSRectToCGRect([self->exportFormatOptionsPDFWofGSPDFCompatibilityLevelLabel frame]))),
              [self->exportFormatOptionsPDFWofGSWriteEnginePopUpButton frame].origin.y,
              MAX([self->exportFormatOptionsPDFWofGSWriteEnginePopUpButton frame].size.width,
                  [self->exportFormatOptionsPDFWofGSPDFCompatibilityLevelPopUpButton frame].size.width),
              [self->exportFormatOptionsPDFWofGSWriteEnginePopUpButton frame].size.height)];
  [self->exportFormatOptionsPDFWofGSPDFCompatibilityLevelPopUpButton setFrame:
   NSMakeRect(MAX(CGRectGetMaxX(NSRectToCGRect([self->exportFormatOptionsPDFWofGSWriteEngineLabel frame])),
                   CGRectGetMaxX(NSRectToCGRect([self->exportFormatOptionsPDFWofGSPDFCompatibilityLevelLabel frame]))),
              [self->exportFormatOptionsPDFWofGSPDFCompatibilityLevelPopUpButton frame].origin.y,
              MAX([self->exportFormatOptionsPDFWofGSWriteEnginePopUpButton frame].size.width,
                  [self->exportFormatOptionsPDFWofGSPDFCompatibilityLevelPopUpButton frame].size.width),
              [self->exportFormatOptionsPDFWofGSPDFCompatibilityLevelPopUpButton frame].size.height)];
  
  [self->exportFormatOptionsPDFWofCancelButton setFrameSize:
   NSMakeSize(MAX(90, [self->exportFormatOptionsPDFWofCancelButton frame].size.width),
              [self->exportFormatOptionsPDFWofCancelButton frame].size.height)];
  [self->exportFormatOptionsPDFWofOKButton setFrameSize:[self->exportFormatOptionsPDFWofCancelButton frame].size];
  [self->exportFormatOptionsPDFWofOKButton setFrameOrigin:
   NSMakePoint(NSMaxX([self->exportFormatOptionsPDFWofGSBox frame])-[self->exportFormatOptionsPDFWofOKButton frame].size.width,
               [self->exportFormatOptionsPDFWofOKButton frame].origin.y)];
  [self->exportFormatOptionsPDFWofCancelButton setFrameOrigin:
   NSMakePoint([self->exportFormatOptionsPDFWofOKButton frame].origin.x-12-[self->exportFormatOptionsPDFWofCancelButton frame].size.width,
               [self->exportFormatOptionsPDFWofCancelButton frame].origin.y)];

  [exportFormatOptionsJpegQualitySlider bind:NSValueBinding toObject:self withKeyPath:@"jpegQualityPercent"
    options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
  [exportFormatOptionsJpegQualityTextField bind:NSValueBinding toObject:self withKeyPath:@"jpegQualityPercent"
    options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
  [exportFormatOptionsJpegBackgroundColorWell bind:NSValueBinding toObject:self withKeyPath:@"jpegBackgroundColor" options:nil];
  [exportFormatOptionsSvgPdfToSvgPathTextField bind:NSValueBinding toObject:self withKeyPath:@"svgPdfToSvgPath" options:nil];
  [exportFormatOptionsSvgPdfToSvgPathTextField bind:NSTextColorBinding toObject:self withKeyPath:@"svgPdfToSvgPath"
    options:colorForFileExistsBindingOptions];
  [exportFormatOptionsTextExportPreambleButton bind:NSValueBinding toObject:self withKeyPath:@"textExportPreamble" options:nil];
  [exportFormatOptionsTextExportEnvironmentButton bind:NSValueBinding toObject:self withKeyPath:@"textExportEnvironment" options:nil];
  [exportFormatOptionsTextExportBodyButton bind:NSValueBinding toObject:self withKeyPath:@"textExportBody" options:nil];

  [self->exportFormatOptionsPDFWofGSWriteEnginePopUpButton bind:NSSelectedValueBinding toObject:self withKeyPath:@"pdfWofGSWriteEngine" options:nil];
  [self->exportFormatOptionsPDFWofGSPDFCompatibilityLevelPopUpButton bind:NSSelectedValueBinding toObject:self withKeyPath:@"pdfWofGSPDFCompatibilityLevel" options:nil];
  
  [self->exportFormatOptionsPDFWofMetaDataInvisibleGraphicsEnabledCheckBox bind:NSValueBinding toObject:self withKeyPath:@"pdfWofMetaDataInvisibleGraphicsEnabled" options:nil];
}
//end awakeFromNib

#pragma mark JPEG

-(IBAction) svgPdfToSvgPathModify:(id)sender
{
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  [openPanel setResolvesAliases:YES];
  NSString* filePath = [self svgPdfToSvgPath];
  NSString* filename =[filePath lastPathComponent];
  NSString* directory = [filePath stringByDeletingLastPathComponent];
  openPanel.directoryURL = [NSURL fileURLWithPath:directory];
  openPanel.nameFieldStringValue = filename;
  NSInteger result = [openPanel runModal];
  if (result == NSFileHandlingPanelOKButton)
  {
    filePath = [[openPanel URL] path];
    [self setSvgPdfToSvgPath:filePath];
  }//end if (result == NSFileHandlingPanelOKButton)
}
//end svgPdfToSvgPathModify:

#pragma mark TEXT

#pragma mark PDF Wof

-(NSPanel*) exportFormatOptionsPDFWofPanel
{
  return self->exportFormatOptionsPDFWofPanel;
}
//end exportFormatOptionsPDFWofPanel

-(NSString*) pdfWofGSWriteEngine
{
  return self->pdfWofGSWriteEngine;
}
//end pdfWofGSWriteEngine

-(void) setPdfWofGSWriteEngine:(NSString*)value
{
#ifdef ARC_ENABLED
#else
  [value retain];
#endif
  [self willChangeValueForKey:@"pdfWofGSWriteEngine"];
#ifdef ARC_ENABLED
#else
  [self->pdfWofGSWriteEngine release];
#endif
  self->pdfWofGSWriteEngine = value;
  [self didChangeValueForKey:@"pdfWofGSWriteEngine"];
}
//end setPdfWofGSWriteEngine:

-(NSString*) pdfWofGSPDFCompatibilityLevel
{
  return self->pdfWofGSPDFCompatibilityLevel;
}
//end pdfWofGSPDFCompatibilityLevel

-(void) setPdfWofGSPDFCompatibilityLevel:(NSString*)value
{
  #ifdef ARC_ENABLED
  #else
  [value retain];
  #endif
  [self willChangeValueForKey:@"pdfWofGSPDFCompatibilityLevel"];
  #ifdef ARC_ENABLED
  #else
  [self->pdfWofGSPDFCompatibilityLevel release];
  #endif
  self->pdfWofGSPDFCompatibilityLevel = value;
  [self didChangeValueForKey:@"pdfWofGSPDFCompatibilityLevel"];
}
//end setPdfWofGSPDFCompatibilityLevel:

-(BOOL) pdfWofMetaDataInvisibleGraphicsEnabled
{
  return self->pdfWofMetaDataInvisibleGraphicsEnabled;
}
//end pdfWofMetaDataInvisibleGraphicsEnabled

-(void) setPdfWofMetaDataInvisibleGraphicsEnabled:(BOOL)value
{
  [self willChangeValueForKey:@"pdfWofMetaDataInvisibleGraphicsEnabled"];
  self->pdfWofMetaDataInvisibleGraphicsEnabled = value;
  [self didChangeValueForKey:@"pdfWofMetaDataInvisibleGraphicsEnabled"];
}
//end setPdfWofMetaDataInvisibleGraphicsEnabled

-(id) exportFormatOptionsPDFWofPanelDelegate
{
  return self->exportFormatOptionsPDFWofPanelDelegate;
}
//end exportFormatOptionsPDFWofPanelDelegate

-(void) setExportFormatOptionsPDFWofPanelDelegate:(id)delegate
{
  self->exportFormatOptionsPDFWofPanelDelegate = delegate;
}
//end setExportFormatOptionsPDFWofPanelDelegate:

#pragma mark ALL

-(IBAction) close:(id)sender
{
  NSInteger senderTag = [sender tag];
  if ((senderTag == 0) || (senderTag == 1))
    [self exportFormatOptionsPanel:exportFormatOptionsJpegPanel didCloseWithOK:(senderTag == 0)];
  else if ((senderTag == 2) || (senderTag == 3))
    [self exportFormatOptionsPanel:exportFormatOptionsSvgPanel didCloseWithOK:(senderTag == 2)];
  else if ((senderTag == 4) || (senderTag == 5))
    [self exportFormatOptionsPanel:exportFormatOptionsTextPanel didCloseWithOK:(senderTag == 4)];
  else if ((senderTag == 6) || (senderTag == 7))
    [self exportFormatOptionsPanel:self->exportFormatOptionsPDFWofPanel didCloseWithOK:(senderTag == 6)];
}
//end close:

#pragma mark delegate
-(void) exportFormatOptionsPanel:(NSPanel*)exportFormatOptionsPanel didCloseWithOK:(BOOL)ok
{
  if ((exportFormatOptionsPanel == exportFormatOptionsJpegPanel) &&
      [exportFormatOptionsJpegPanelDelegate respondsToSelector:@selector(exportFormatOptionsPanel:didCloseWithOK:)])
    [exportFormatOptionsJpegPanelDelegate exportFormatOptionsPanel:exportFormatOptionsPanel didCloseWithOK:ok];
  else if ((exportFormatOptionsPanel == exportFormatOptionsSvgPanel) &&
      [exportFormatOptionsSvgPanelDelegate respondsToSelector:@selector(exportFormatOptionsPanel:didCloseWithOK:)])
    [exportFormatOptionsSvgPanelDelegate exportFormatOptionsPanel:exportFormatOptionsPanel didCloseWithOK:ok];
  else if ((exportFormatOptionsPanel == exportFormatOptionsTextPanel) &&
           [exportFormatOptionsTextPanelDelegate respondsToSelector:@selector(exportFormatOptionsPanel:didCloseWithOK:)])
    [exportFormatOptionsTextPanelDelegate exportFormatOptionsPanel:exportFormatOptionsPanel didCloseWithOK:ok];
  else if ((exportFormatOptionsPanel == self->exportFormatOptionsPDFWofPanel) &&
           [self->exportFormatOptionsPDFWofPanelDelegate respondsToSelector:@selector(exportFormatOptionsPanel:didCloseWithOK:)])
    [self->exportFormatOptionsPDFWofPanelDelegate exportFormatOptionsPanel:exportFormatOptionsPanel didCloseWithOK:ok];
}
//end exportFormatOptionsPanel:didCloseWithOK:

@end
