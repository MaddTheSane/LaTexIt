//
//  ActionViewController.m
//  LaTeXiT_AppExtension
//
//  Created by Pierre Chatelier on 01/10/2020.
//

#import "ActionViewController.h"

#import "NSColorExtended.h"
#import "NSObjectExtended.h"
#import "NSStringExtended.h"
#import "LatexitEquation.h"
#import "PreferencesController.h"

#import "LaTeXiT_XPC_Service_Protocol.h"

@interface ActionViewController ()

@property IBOutlet NSBox* upperBox;
@property IBOutlet NSBox* lowerBox;
@property IBOutlet NSImageView* myImageView;
@property IBOutlet NSSplitView* myEquationSplitView;
@property IBOutlet NSTextView* myPreambleTextView;
@property IBOutlet NSTextView* mySourceTextView;
@property IBOutlet NSNumberFormatter* pointSizeFormatter;
@property IBOutlet NSTextField* fontSizeLabel;
@property IBOutlet NSTextField* fontSizeTextField;
@property IBOutlet NSTextField* fontColorLabel;
@property IBOutlet NSColorWell* fontColorWell;
@property IBOutlet NSProgressIndicator* latexizeProgressIndicator;
@property IBOutlet NSButton* openWithLaTeXiTButton;
@property IBOutlet NSButton* latexizeButton;
@property IBOutlet NSButton* cancelButton;
@property IBOutlet NSButton* sendButton;

-(void) loadExtensionInput;
-(void) connectToService;
-(void) setEquation:(LatexitEquation*)value uti:(NSString*)uti;
-(void) updateImage;

@property(nonatomic,copy) NSData* pdfData;
@property(nonatomic,copy) NSData* exportedData;
@property(nonatomic,copy) NSString* exportedUTI;

@end

@implementation ActionViewController

@dynamic pdfData;
@synthesize exportedData = exportedData;
@synthesize exportedUTI = exportedUTI;

-(void) dealloc
{
  [self->connectionToService invalidate];
  self.exportedData = nil;
}
//end dealloc:

-(NSString*) nibName
{
  return @"ActionViewController";
}

-(void) loadView
{
  [super loadView];

  PreferencesController* preferencesController = [PreferencesController sharedController];
  
  [self.myEquationSplitView setPosition:0 ofDividerAtIndex:0];

  //get rid of formatter localization problems
  [self.pointSizeFormatter setLocale:[NSLocale currentLocale]];
  [self.pointSizeFormatter setGroupingSeparator:[[NSLocale currentLocale] objectForKey:NSLocaleGroupingSeparator]];
  [self.pointSizeFormatter setDecimalSeparator:[[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator]];
  NSString* pointSizeZeroSymbol =
    [NSString stringWithFormat:@"0%@%0*d%@",
       [self.pointSizeFormatter decimalSeparator], 2, 0,
       [self.pointSizeFormatter positiveSuffix]];
  [self.pointSizeFormatter setZeroSymbol:pointSizeZeroSymbol];

  [self.fontSizeLabel setStringValue:NSLocalizedString(@"Font size :", @"")];
  [self.fontSizeTextField setDoubleValue:[preferencesController latexisationFontSize]];
  [self.fontColorLabel setStringValue:NSLocalizedString(@"Color :", @"")];
  [self.fontColorWell setColor:[NSColor blackColor]];

  [[self.fontSizeLabel cell] setControlSize:NSControlSizeRegular];
  [self.fontSizeLabel setFont:[NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSControlSizeRegular]]];
  [self.fontSizeLabel sizeToFit];
  [[self.fontSizeTextField cell] setControlSize:NSControlSizeRegular];
  [self.fontSizeTextField setFont:[NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSControlSizeRegular]]];
  [self.fontSizeTextField sizeToFit];
  [self.fontSizeLabel setFrameOrigin:NSMakePoint(20, self.fontSizeLabel.frame.origin.y)];
  [self.fontSizeTextField setFrameOrigin:NSMakePoint(NSMaxX([self.fontSizeLabel frame])+4, self.fontSizeTextField.frame.origin.y)];
  [[self.fontColorLabel cell] setControlSize:NSControlSizeRegular];
  [self.fontColorLabel setFont:[NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSControlSizeRegular]]];
  [self.fontColorLabel sizeToFit];
  [[self.fontColorWell cell] setControlSize:NSControlSizeRegular];
  [self.fontColorLabel setFrameOrigin:NSMakePoint(NSMaxX([self.fontSizeTextField frame])+10, self.fontColorLabel.frame.origin.y)];
  [self.fontColorWell setFrame:NSMakeRect(NSMaxX([self.fontColorLabel frame])+4, self.fontColorWell.frame.origin.y, 52, 26)];

  [self.latexizeButton setTitle:NSLocalizedString(@"LaTeX it!", @"")];
  [self.latexizeButton sizeToFit];
  NSRect superviewFrame = [[self.latexizeButton superview] frame];
  NSRect latexizeButtonFrame = [self.latexizeButton frame];
  [self.latexizeButton setFrame:NSMakeRect(MAX(superviewFrame.size.width-18-latexizeButtonFrame.size.width,
                                                        NSMaxX(self.lowerBox.frame)-
                                                        latexizeButtonFrame.size.width), self.latexizeButton.frame.origin.y,
                                                    latexizeButtonFrame.size.width, latexizeButtonFrame.size.height)];
  [self.latexizeProgressIndicator setFrameOrigin:NSMakePoint(NSMinX(self.latexizeButton.frame)-8-self.latexizeProgressIndicator.frame.size.width,
                        self.latexizeProgressIndicator.frame.origin.y)];

  [self.openWithLaTeXiTButton setTitle:NSLocalizedString(@"Open with LaTeXiT", @"")];
  [self.openWithLaTeXiTButton sizeToFit];

  [self.sendButton setTitle:NSLocalizedString(@"Send", @"")];
  [self.sendButton sizeToFit];
  [self.sendButton setFrameOrigin:NSMakePoint(NSMaxX(self.lowerBox.frame)-self.sendButton.frame.size.width,
                        self.sendButton.frame.origin.y)];

  [self.cancelButton setTitle:NSLocalizedString(@"Cancel", @"")];
  [self.cancelButton sizeToFit];
  [self.cancelButton setFrameOrigin:NSMakePoint(NSMinX(self.sendButton.frame)-8-self.cancelButton.frame.size.width,
                        self.cancelButton.frame.origin.y)];
                      
  [self loadExtensionInput];
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{[self connectToService];});
}
//end loadView

-(void) viewDidAppear
{
  [super viewDidAppear];
  id window = self.mySourceTextView.window;
  [window makeFirstResponder:self.mySourceTextView];
}
//end viewDidAppear

-(void) loadExtensionInput
{
  NSExtensionItem* lastExtensionItem = [[self.extensionContext.inputItems lastObject] dynamicCastToClass:[NSExtensionItem class]];
  NSDictionary* userInfo = lastExtensionItem.userInfo;
  NSArray* attachements = [[userInfo objectForKey:NSExtensionItemAttachmentsKey] dynamicCastToClass:[NSArray class]];
  NSItemProvider* attachment = [attachements.lastObject dynamicCastToClass:[NSItemProvider class]];
  NSArray* identifiers = @[@"com.adobe.pdf", @"public.png", @"public.tiff", @"public.jpeg", @"public.svg-image"];
  for(NSString* uti in identifiers)
  {
    if ([attachment hasItemConformingToTypeIdentifier:uti])
    {
      [attachment loadItemForTypeIdentifier:uti options:nil completionHandler:^(id<NSSecureCoding>  _Nullable item, NSError * _Null_unspecified error) {
          NSData* data = [(id)item dynamicCastToClass:[NSData class]];
          self->originalData = [data copy];
          self->originalUTI = [uti copy];
          [self updateImage];
          LatexitEquation* newEquation = !data ? nil : [LatexitEquation latexitEquationWithData:data sourceUTI:uti useDefaults:YES];
          if (newEquation)
            [self setEquation:newEquation uti:uti];
        }];
      break;
    }//end if ([attachment hasItemConformingToTypeIdentifier:uti])
  }//end for each uti
}
//end loadExtensionInput

-(void) updateImage
{
  NSData* data =
    (self->pdfData != nil) ? self->pdfData :
    (self->originalData != nil) ? self->originalData :
    nil;
  NSImage* newImage = !data ? nil : [[NSImage alloc] initWithData:data];
  self.myImageView.image = newImage;
}
//end updateImage

-(void) connectToService
{
  if (!self->connectionToService)
  {
    @synchronized(self)
    {
      if (!self->connectionToService)
      {
        self->connectionToService = [[NSXPCConnection alloc] initWithServiceName:@"fr.chachatelier.pierre.LaTeXiT.appex.xpc"];
        @try{
          self->connectionToService.remoteObjectInterface =
            [NSXPCInterface interfaceWithProtocol:@protocol(LaTeXiT_XPC_Service_Protocol)];
          [self->connectionToService resume];
        }
        @catch(NSException* e){
          NSLog(@"exception <%@>", e);
          self->connectionToService = nil;
        }
      }//end if (!self->connectionToService)
    }//end @synchronized(self)
  }//end if (!self->connectionToService)
}
//end connectToService

-(void) setEquation:(LatexitEquation*)value uti:(NSString*)uti
{
  if (value != self->equation)
  {
    self->equation = value;
  }//end if (value != self->equation)
  if (self->equation)
  {
    NSString* string = self->equation.preamble.string;
    if (!string)
      [self.myPreambleTextView setString:@""];
    else//if (string)
      [self.myPreambleTextView setString:string];
    string = self->equation.sourceText.string;
    if (!string)
      [self.mySourceTextView setString:@""];
    else//if (string)
      [self.mySourceTextView setString:string];
    [self.mySourceTextView setSelectedRange:self.mySourceTextView.string.range];
    self.fontSizeTextField.doubleValue = self->equation.pointSize;
    self.fontColorWell.color = self->equation.color;
    self.sendButton.enabled = (self->equation != nil);
  }//end if (self->equation)
}
//end setEquation:uti:

-(NSData*) pdfData
{
  NSData* result = [self->pdfData copy];
  return result;
}
//end pdfData

-(void) setPdfData:(NSData*)value
{
  if (value != self->pdfData)
  {
    self->pdfData = [value copy];
  }//end if (value != self->pdfData)
}
//end setPdfData:

-(IBAction) latexize:(id)sender
{
  if (self->equation)
  {
    [self connectToService];
    if (self->connectionToService)
    {
      @try{
        NSMutableDictionary* plist = [self->equation plistDescription];
        [plist setObject:self.myPreambleTextView.string forKey:@"preamble"];
        [plist setObject:self.mySourceTextView.string forKey:@"sourceText"];
        [plist setObject:[NSNumber numberWithDouble:self.fontSizeTextField.doubleValue] forKey:@"pointSize"];
        [plist setObject:[self.fontColorWell.color colorAsData] forKey:@"color"];
        self.latexizeButton.enabled = NO;
        [self.latexizeProgressIndicator startAnimation:nil];
        [[self->connectionToService remoteObjectProxy] processLaTeX:plist exportUTI:self->originalUTI withReply:^(id plist) {
           NSDictionary* dict = [plist dynamicCastToClass:[NSDictionary class]];
           NSData* newPdfData = [[dict objectForKey:@"pdfData"] dynamicCastToClass:[NSData class]];
           NSData* newExportedData = [[dict objectForKey:@"exportedData"] dynamicCastToClass:[NSData class]];
           if (newPdfData)
             dispatch_sync(dispatch_get_main_queue(), ^(void){
               [self.latexizeProgressIndicator stopAnimation:nil];
               self.latexizeButton.enabled = YES;
               self.exportedData = newExportedData;
               self.exportedUTI = self->originalUTI;
               self.pdfData = newPdfData;
               [self updateImage];
             });
         }];
      }
      @catch(NSException* e){
        NSLog(@"exception <%@>", e);
      }
    }//end if (self->connectionToService)
  }//end if (self->equation)
}
//end latexize:

-(IBAction) send:(id)sender
{
  if (self->exportedData || self->pdfData)
  {
    NSData* dataToExport = (self->exportedData != nil) ? self->exportedData : self->pdfData;
    NSString* utiToExport = (self->exportedData != nil) ? self->exportedUTI : self->originalUTI;
    NSItemProvider* itemProvider = !dataToExport  || !utiToExport ? nil :
      [[NSItemProvider alloc] initWithItem:dataToExport typeIdentifier:utiToExport];
    NSExtensionItem* outputItem = !itemProvider ? nil : [[NSExtensionItem alloc] init];
    outputItem.userInfo = !outputItem ? nil : @{NSExtensionItemAttachmentsKey:@[itemProvider]};
    NSArray* outputItems = !outputItem ? nil : @[outputItem];
    if (outputItems != nil)
      [self.extensionContext completeRequestReturningItems:outputItems completionHandler:nil];
  }//end if (self->exportedData || self->pdfData)
}
//end send:

-(IBAction) cancel:(id)sender
{
  NSError* cancelError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
  [self.extensionContext cancelRequestWithError:cancelError];
}
//end cancel:

-(IBAction) openWithLaTeXiT:(id)sender
{
  if (self->originalData && self->originalUTI)
  {
    [self connectToService];
    if (self->connectionToService)
    {
      @try{
        [[self->connectionToService remoteObjectProxy] openWithLaTeXiT:self->originalData uti:self->originalUTI];
      }
      @catch(NSException* e){
        NSLog(@"exception <%@>", e);
      }
    }//end if (self->connectionToService)
  }//end if (self->originalData && self->originalUTI)
}
//end openWithLaTeXiT:

@end

