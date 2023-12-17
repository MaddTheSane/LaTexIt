//
//  ExportFormatOptionsPanes.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 23/04/09.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.
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
  [self instantiateWithOwner:self topLevelObjects:&self->nibTopLevelObjects];
  #ifdef ARC_ENABLED
  #else
  [self->nibTopLevelObjects retain];
  #endif

  self->jpegQualityPercent  = 90.f;
  #ifdef ARC_ENABLED
  self->jpegBackgroundColor = [NSColor whiteColor];
  #else
  self->jpegBackgroundColor = [[NSColor whiteColor] retain];
  #endif

  self->textExportPreamble = YES;
  self->textExportEnvironment = YES;
  self->textExportBody = YES;
  
  #ifdef ARC_ENABLED
  self->pdfWofGSWriteEngine = @"pdfwrite";
  self->pdfWofGSPDFCompatibilityLevel = @"1.5";
  #else
  self->pdfWofGSWriteEngine = [@"pdfwrite" copy];
  self->pdfWofGSPDFCompatibilityLevel = [@"1.5" copy];
  #endif
  self->pdfWofMetaDataInvisibleGraphicsEnabled = YES;
  
  self->pdfMetaDataInvisibleGraphicsEnabled = YES;
  
  return self;
}
//end initWithLoadingFromNib:

-(void) dealloc
{
  #ifdef ARC_ENABLED
  #else
  [self->jpegBackgroundColor release];
  [self->pdfWofGSWriteEngine release];
  [self->pdfWofGSPDFCompatibilityLevel release];
  [self->nibTopLevelObjects release];
  [super dealloc];
  #endif
}
//end dealloc

-(NSString*) debugDescription
{
  return [NSString stringWithFormat:@"ExportFormatOptionsPanes:\n{exportFormatOptionsSvgPanel=%@, exportFormatOptionsSvgPanelDelegate=%@}", self->exportFormatOptionsSvgPanel, self->exportFormatOptionsSvgPanelDelegate];
}
-(NSString*) description
{
  return [self debugDescription];
}
-(NSString*) descriptionWithLocale:(id)aLocale
{
  return [self description];
}

-(void) awakeFromNib
{
  [self->exportFormatOptionsJpegBox setTitle:LocalLocalizedString(@"JPEG Quality", @"")];
  [self->exportFormatOptionsJpegQualityLeastLabel  setStringValue:LocalLocalizedString(@"least", @"")];
  [self->exportFormatOptionsJpegQualityLowLabel    setStringValue:LocalLocalizedString(@"low", @"")];
  [self->exportFormatOptionsJpegQualityMediumLabel setStringValue:LocalLocalizedString(@"medium", @"")];
  [self->exportFormatOptionsJpegQualityHighLabel   setStringValue:LocalLocalizedString(@"high", @"")];
  [self->exportFormatOptionsJpegQualityMaxiLabel   setStringValue:LocalLocalizedString(@"maxi", @"")];
  [self->exportFormatOptionsJpegQualityLabel setStringValue:[NSString stringWithFormat:@"%@ :", LocalLocalizedString(@"Quality", @"")]];
  [self->exportFormatOptionsJpegBackgroundColorLabel setStringValue:[NSString stringWithFormat:@"%@ :", LocalLocalizedString(@"Background color", @"")]];
  [self->exportFormatOptionsJpegOKButton setTitle:LocalLocalizedString(@"OK", @"")];
  [self->exportFormatOptionsJpegCancelButton setTitle:LocalLocalizedString(@"Cancel", @"")];
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

  [self->exportFormatOptionsSvgPdfToSvgBox setTitle:LocalLocalizedString(@"Path to pdf2svg", @"")];
  [self->exportFormatOptionsSvgPdfToSvgPathModifyButton setTitle:[NSString stringWithFormat:@"%@...", LocalLocalizedString(@"Change", @"")]];
  [self->exportFormatOptionsSvgPdfToSvgPathModifyButton sizeToFit];
  [self->exportFormatOptionsSvgPdfToSvgPathModifyButton setFrameOrigin:
    NSMakePoint([self->exportFormatOptionsSvgPdfToSvgBox frame].size.width-16-
                [self->exportFormatOptionsSvgPdfToSvgPathModifyButton frame].size.width,
                [self->exportFormatOptionsSvgPdfToSvgPathModifyButton frame].origin.y)];
  [self->exportFormatOptionsSvgPdfToSvgPathTextField setFrameSize:
    NSMakeSize([self->exportFormatOptionsSvgPdfToSvgPathModifyButton frame].origin.x-8-10,
               [self->exportFormatOptionsSvgPdfToSvgPathTextField frame].size.height)];
  [self->exportFormatOptionsSvgPdfToCairoBox setTitle:LocalLocalizedString(@"Path to pdftocairo", @"")];
  [self->exportFormatOptionsSvgPdfToCairoPathModifyButton setTitle:[NSString stringWithFormat:@"%@...", LocalLocalizedString(@"Change", @"")]];
  [self->exportFormatOptionsSvgPdfToCairoPathModifyButton sizeToFit];
  [self->exportFormatOptionsSvgPdfToCairoPathModifyButton setFrameOrigin:
    NSMakePoint([self->exportFormatOptionsSvgPdfToCairoBox frame].size.width-16-
                [self->exportFormatOptionsSvgPdfToCairoPathModifyButton frame].size.width,
                [self->exportFormatOptionsSvgPdfToCairoPathModifyButton frame].origin.y)];
  [self->exportFormatOptionsSvgPdfToCairoPathTextField setFrameSize:
    NSMakeSize([self->exportFormatOptionsSvgPdfToCairoPathModifyButton frame].origin.x-8-10,
               [self->exportFormatOptionsSvgPdfToCairoPathTextField frame].size.height)];
  [self->exportFormatOptionsSvgOKButton setTitle:LocalLocalizedString(@"OK", @"")];
  [self->exportFormatOptionsSvgCancelButton setTitle:LocalLocalizedString(@"Cancel", @"")];
  [self->exportFormatOptionsSvgOKButton sizeToFit];
  [self->exportFormatOptionsSvgCancelButton sizeToFit];
  [self->exportFormatOptionsSvgCancelButton setFrameSize:
    NSMakeSize(MAX(90, [self->exportFormatOptionsSvgCancelButton frame].size.width),
               [self->exportFormatOptionsSvgCancelButton frame].size.height)];
  [self->exportFormatOptionsSvgOKButton setFrameSize:[self->exportFormatOptionsSvgCancelButton frame].size];
  [self->exportFormatOptionsSvgOKButton setFrameOrigin:
    NSMakePoint(MAX(
      NSMaxX([self->exportFormatOptionsSvgPdfToSvgBox frame])-[self->exportFormatOptionsSvgOKButton frame].size.width,
      NSMaxX([self->exportFormatOptionsSvgPdfToCairoBox frame])-[self->exportFormatOptionsSvgOKButton frame].size.width),
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

  [self->exportFormatOptionsTextExportPreambleButton setTitle:LocalLocalizedString(@"Export preamble", @"")];
  [self->exportFormatOptionsTextExportPreambleButton sizeToFit];
  [self->exportFormatOptionsTextExportEnvironmentButton setTitle:LocalLocalizedString(@"Export environment", @"")];
  [self->exportFormatOptionsTextExportEnvironmentButton sizeToFit];
  [self->exportFormatOptionsTextExportBodyButton setTitle:LocalLocalizedString(@"Export body", @"Export")];
  [self->exportFormatOptionsTextExportBodyButton sizeToFit];
  [self->exportFormatOptionsTextOKButton setTitle:LocalLocalizedString(@"OK", @"")];
  [self->exportFormatOptionsTextCancelButton setTitle:LocalLocalizedString(@"Cancel", @"")];
  [self->exportFormatOptionsTextOKButton sizeToFit];
  [self->exportFormatOptionsTextCancelButton sizeToFit];
  [self->exportFormatOptionsTextCancelButton setFrameSize:
   NSMakeSize(MAX(90, [self->exportFormatOptionsTextCancelButton frame].size.width),
              [self->exportFormatOptionsTextCancelButton frame].size.height)];
  [self->exportFormatOptionsTextOKButton setFrameSize:[self->exportFormatOptionsTextCancelButton frame].size];
  [self->exportFormatOptionsTextOKButton setFrameOrigin:
   NSMakePoint(NSMaxX([self->exportFormatOptionsTextBox frame])-[self->exportFormatOptionsTextOKButton frame].size.width,
               [self->exportFormatOptionsTextOKButton frame].origin.y)];
  [self->exportFormatOptionsTextCancelButton setFrameOrigin:
   NSMakePoint([self->exportFormatOptionsTextOKButton frame].origin.x-12-[self->exportFormatOptionsTextCancelButton frame].size.width,
               [self->exportFormatOptionsTextCancelButton frame].origin.y)];
  
  [self->exportFormatOptionsPDFWofGSBox setTitle:LocalLocalizedString(@"Ghostscript options", @"")];
  [self->exportFormatOptionsPDFWofGSWriteEngineLabel setStringValue:[NSString stringWithFormat:@"%@:",LocalLocalizedString(@"Write engine", @"e")]];
  [self->exportFormatOptionsPDFWofGSPDFCompatibilityLevelLabel setStringValue:[NSString stringWithFormat:@"%@:",LocalLocalizedString(@"PDF Compatibility level", @"")]];
  [self->exportFormatOptionsPDFWofMetaDataInvisibleGraphicsEnabledCheckBox setTitle:NSLocalizedString(@"Add invisible graphic commands", @"")];
  [self->exportFormatOptionsPDFWofGSWriteEngineLabel sizeToFit];
  [self->exportFormatOptionsPDFWofGSPDFCompatibilityLevelLabel sizeToFit];
  [self->exportFormatOptionsPDFWofGSWriteEnginePopUpButton sizeToFit];
  [self->exportFormatOptionsPDFWofGSPDFCompatibilityLevelPopUpButton sizeToFit];
  [self->exportFormatOptionsPDFWofMetadataBox setTitle:LocalLocalizedString(@"LaTeXiT medata", @"")];
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
  
  [self->exportFormatOptionsPDFMetadataBox setTitle:LocalLocalizedString(@"LaTeXiT medata", @"")];
  [self->exportFormatOptionsPDFMetaDataInvisibleGraphicsEnabledCheckBox setTitle:NSLocalizedString(@"Add invisible graphic commands", @"")];
  [self->exportFormatOptionsPDFMetaDataInvisibleGraphicsEnabledCheckBox sizeToFit];
  [self->exportFormatOptionsPDFOKButton sizeToFit];
  [self->exportFormatOptionsPDFCancelButton sizeToFit];
  
  [self->exportFormatOptionsPDFCancelButton setFrameSize:
   NSMakeSize(MAX(90, [self->exportFormatOptionsPDFCancelButton frame].size.width),
              [self->exportFormatOptionsPDFCancelButton frame].size.height)];
  [self->exportFormatOptionsPDFOKButton setFrameSize:[self->exportFormatOptionsPDFCancelButton frame].size];
  [self->exportFormatOptionsPDFOKButton setFrameOrigin:
   NSMakePoint(NSMaxX([self->exportFormatOptionsPDFMetadataBox frame])-[self->exportFormatOptionsPDFOKButton frame].size.width,
               [self->exportFormatOptionsPDFOKButton frame].origin.y)];
  [self->exportFormatOptionsPDFCancelButton setFrameOrigin:
   NSMakePoint([self->exportFormatOptionsPDFOKButton frame].origin.x-12-[self->exportFormatOptionsPDFCancelButton frame].size.width,
               [self->exportFormatOptionsPDFCancelButton frame].origin.y)];

  [self->exportFormatOptionsJpegQualitySlider bind:NSValueBinding toObject:self withKeyPath:@"jpegQualityPercent"
    options:[NSDictionary dictionaryWithObjectsAndKeys:@(YES), NSContinuouslyUpdatesValueBindingOption, nil]];
  [self->exportFormatOptionsJpegQualityTextField bind:NSValueBinding toObject:self withKeyPath:@"jpegQualityPercent"
    options:[NSDictionary dictionaryWithObjectsAndKeys:@(YES), NSContinuouslyUpdatesValueBindingOption, nil]];
  [self->exportFormatOptionsJpegBackgroundColorWell bind:NSValueBinding toObject:self withKeyPath:@"jpegBackgroundColor" options:nil];
  
  [self->exportFormatOptionsSvgPdfToSvgPathTextField bind:NSValueBinding toObject:self withKeyPath:@"svgPdfToSvgPath" options:nil];
  [self->exportFormatOptionsSvgPdfToSvgPathTextField bind:NSTextColorBinding toObject:self withKeyPath:@"svgPdfToSvgPath"
    options:colorForFileExistsBindingOptions];

  [self->exportFormatOptionsSvgPdfToCairoPathTextField bind:NSValueBinding toObject:self withKeyPath:@"svgPdfToCairoPath" options:nil];
  [self->exportFormatOptionsSvgPdfToCairoPathTextField bind:NSTextColorBinding toObject:self withKeyPath:@"svgPdfToCairoPath"
    options:colorForFileExistsBindingOptions];

  [self->exportFormatOptionsTextExportPreambleButton bind:NSValueBinding toObject:self withKeyPath:@"textExportPreamble" options:nil];
  [self->exportFormatOptionsTextExportEnvironmentButton bind:NSValueBinding toObject:self withKeyPath:@"textExportEnvironment" options:nil];
  [self->exportFormatOptionsTextExportBodyButton bind:NSValueBinding toObject:self withKeyPath:@"textExportBody" options:nil];

  [self->exportFormatOptionsPDFWofGSWriteEnginePopUpButton bind:NSSelectedValueBinding toObject:self withKeyPath:@"pdfWofGSWriteEngine" options:nil];
  [self->exportFormatOptionsPDFWofGSPDFCompatibilityLevelPopUpButton bind:NSSelectedValueBinding toObject:self withKeyPath:@"pdfWofGSPDFCompatibilityLevel" options:nil];
  
  [self->exportFormatOptionsPDFWofMetaDataInvisibleGraphicsEnabledCheckBox bind:NSValueBinding toObject:self withKeyPath:@"pdfWofMetaDataInvisibleGraphicsEnabled" options:nil];

  [self->exportFormatOptionsPDFMetaDataInvisibleGraphicsEnabledCheckBox bind:NSValueBinding toObject:self withKeyPath:@"pdfMetaDataInvisibleGraphicsEnabled" options:nil];
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
  #ifdef ARC_ENABLED
  #else
  [value retain];
  #endif
  [self willChangeValueForKey:@"jpegBackgroundColor"];
  #ifdef ARC_ENABLED
  #else
  [self->jpegBackgroundColor release];
  #endif
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
  #ifdef ARC_ENABLED
  #else
  [value retain];
  #endif
  [self willChangeValueForKey:@"svgPdfToSvgPath"];
  #ifdef ARC_ENABLED
  #else
  [self->svgPdfToSvgPath release];
  #endif
  self->svgPdfToSvgPath = value;
  [self didChangeValueForKey:@"svgPdfToSvgPath"];
}
//end setSvgPdfToSvgPath:

-(NSString*) svgPdfToCairoPath
{
  return self->svgPdfToCairoPath;
}
//end svgPdfToCairoPath

-(void) setSvgPdfToCairoPath:(NSString*)value
{
  #ifdef ARC_ENABLED
  #else
  [value retain];
  #endif
  [self willChangeValueForKey:@"svgPdfToCairoPath"];
  #ifdef ARC_ENABLED
  #else
  [self->svgPdfToCairoPath release];
  #endif
  self->svgPdfToCairoPath = value;
  [self didChangeValueForKey:@"svgPdfToCairoPath"];
}
//end setSvgPdfToCairoPath:

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
  if (sender == self->exportFormatOptionsSvgPdfToSvgPathTextField)
    [self setSvgPdfToSvgPath:self->exportFormatOptionsSvgPdfToSvgPathTextField.stringValue];
  else
  {
    NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    [openPanel setResolvesAliases:YES];
    NSString* filePath = [self svgPdfToSvgPath];
    NSString* filename = [filePath lastPathComponent];
    NSString* directory = [filePath stringByDeletingLastPathComponent];
    [openPanel setDirectoryURL:(!directory ? nil : [NSURL fileURLWithPath:directory isDirectory:YES])];
    [openPanel setNameFieldStringValue:filename];
    NSModalResponse result = [openPanel runModal];
    if (result == NSModalResponseOK)
    {
      filePath = [[openPanel URL] path];
      [self setSvgPdfToSvgPath:filePath];
    }//end if (result == NSModalResponseOK)
  }
}
//end svgPdfToSvgPathModify:

-(IBAction) svgPdfToCairoPathModify:(id)sender
{
  if (sender == self->exportFormatOptionsSvgPdfToCairoPathTextField)
    [self setSvgPdfToCairoPath:self->exportFormatOptionsSvgPdfToCairoPathTextField.stringValue];
  else
  {
    NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    [openPanel setResolvesAliases:YES];
    NSString* filePath = [self svgPdfToCairoPath];
    NSString* filename = [filePath lastPathComponent];
    NSString* directory = [filePath stringByDeletingLastPathComponent];
    [openPanel setDirectoryURL:(!directory ? nil : [NSURL fileURLWithPath:directory isDirectory:YES])];
    [openPanel setNameFieldStringValue:filename];
    NSModalResponse result = [openPanel runModal];
    if (result == NSModalResponseOK)
    {
      filePath = [[openPanel URL] path];
      [self setSvgPdfToCairoPath:filePath];
    }//end if (result == NSModalResponseOK)
  }
}
//end svgPdfToCairoPathModify:

#pragma mark TEXT

-(NSPanel*) exportFormatOptionsTextPanel
{
  return self->exportFormatOptionsTextPanel;
}
//end exportFormatOptionsTextPanel

-(NSBox*) exportFormatOptionsTextBox
{
  return self->exportFormatOptionsTextBox;
}
//end exportFormatOptionsTextBox

-(BOOL) textExportPreamble
{
  return self->textExportPreamble;
}
//end textExportPreamble

-(void) setTextExportPreamble:(BOOL)value
{
  [self willChangeValueForKey:@"textExportPreamble"];
  self->textExportPreamble = value;
  [self didChangeValueForKey:@"textExportPreamble"];
}
//end setTextExportPreamble:

-(BOOL) textExportEnvironment
{
  return self->textExportEnvironment;
}
//end textExportEnvironment

-(void) setTextExportEnvironment:(BOOL)value
{
  [self willChangeValueForKey:@"textExportEnvironment"];
  self->textExportEnvironment = value;
  [self didChangeValueForKey:@"textExportEnvironment"];
}
//end setTextExportEnvironment:

-(BOOL) textExportBody
{
  return self->textExportBody;
}
//end textExportBody

-(void) setTextExportBody:(BOOL)value
{
  [self willChangeValueForKey:@"textExportBody"];
  self->textExportBody = value;
  [self didChangeValueForKey:@"textExportBody"];
}
//end setTextExportBody:

-(id) exportFormatOptionsTextPanelDelegate
{
  return self->exportFormatOptionsTextPanelDelegate;
}
//end exportFormatOptionsTextPanelDelegate

-(void) setExportFormatOptionsTextPanelDelegate:(id)delegate
{
  self->exportFormatOptionsTextPanelDelegate = delegate;
}
//end setExportFormatOptionsTextPanelDelegate:

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

#pragma mark PDF

-(NSPanel*) exportFormatOptionsPDFPanel
{
  return self->exportFormatOptionsPDFPanel;
}
//end exportFormatOptionsPDFPanel

-(BOOL) pdfMetaDataInvisibleGraphicsEnabled
{
  return self->pdfMetaDataInvisibleGraphicsEnabled;
}
//end pdfMetaDataInvisibleGraphicsEnabled

-(void) setPdfMetaDataInvisibleGraphicsEnabled:(BOOL)value
{
  [self willChangeValueForKey:@"pdfMetaDataInvisibleGraphicsEnabled"];
  self->pdfMetaDataInvisibleGraphicsEnabled = value;
  [self didChangeValueForKey:@"pdfMetaDataInvisibleGraphicsEnabled"];
}
//end setPdfMetaDataInvisibleGraphicsEnabled

-(id) exportFormatOptionsPDFPanelDelegate
{
  return self->exportFormatOptionsPDFPanelDelegate;
}
//end exportFormatOptionsPDFfPanelDelegate

-(void) setExportFormatOptionsPDFPanelDelegate:(id)delegate
{
  self->exportFormatOptionsPDFPanelDelegate = delegate;
}
//end setExportFormatOptionsPDFPanelDelegate:

#pragma mark ALL

-(IBAction) close:(id)sender
{
  NSInteger senderTag = [sender tag];
  if ((senderTag == 0) || (senderTag == 1))
    [self exportFormatOptionsPanel:self->exportFormatOptionsJpegPanel didCloseWithOK:(senderTag == 0)];
  else if ((senderTag == 2) || (senderTag == 3))
    [self exportFormatOptionsPanel:self->exportFormatOptionsSvgPanel didCloseWithOK:(senderTag == 2)];
  else if ((senderTag == 4) || (senderTag == 5))
    [self exportFormatOptionsPanel:self->exportFormatOptionsTextPanel didCloseWithOK:(senderTag == 4)];
  else if ((senderTag == 6) || (senderTag == 7))
    [self exportFormatOptionsPanel:self->exportFormatOptionsPDFWofPanel didCloseWithOK:(senderTag == 6)];
  else if ((senderTag == 8) || (senderTag == 9))
    [self exportFormatOptionsPanel:self->exportFormatOptionsPDFPanel didCloseWithOK:(senderTag == 8)];
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
  else if ((exportFormatOptionsPanel == self->exportFormatOptionsTextPanel) &&
           [self->exportFormatOptionsTextPanelDelegate respondsToSelector:@selector(exportFormatOptionsPanel:didCloseWithOK:)])
    [self->exportFormatOptionsTextPanelDelegate exportFormatOptionsPanel:exportFormatOptionsPanel didCloseWithOK:ok];
  else if ((exportFormatOptionsPanel == self->exportFormatOptionsPDFWofPanel) &&
           [self->exportFormatOptionsPDFWofPanelDelegate respondsToSelector:@selector(exportFormatOptionsPanel:didCloseWithOK:)])
    [self->exportFormatOptionsPDFWofPanelDelegate exportFormatOptionsPanel:exportFormatOptionsPanel didCloseWithOK:ok];
  else if ((exportFormatOptionsPanel == self->exportFormatOptionsPDFPanel) &&
           [self->exportFormatOptionsPDFPanelDelegate respondsToSelector:@selector(exportFormatOptionsPanel:didCloseWithOK:)])
    [self->exportFormatOptionsPDFPanelDelegate exportFormatOptionsPanel:exportFormatOptionsPanel didCloseWithOK:ok];
}
//end exportFormatOptionsPanel:didCloseWithOK:

@end
