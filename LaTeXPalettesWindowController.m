//  LaTeXPalettesWindowController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 4/04/05.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.

//The LaTeXPalettesWindowController controller is responsible for loading and initializing the palette

#import "LaTeXPalettesWindowController.h"

#import "AppController.h"
#import "ImageCell.h"
#import "NSDictionaryExtended.h"
#import "NSFileManagerExtended.h"
#import "NSObjectExtended.h"
#import "NSUserDefaultsControllerExtended.h"
#import "NSWorkspaceExtended.h"
#import "PaletteCell.h"
#import "PaletteItem.h"
#import "PreferencesController.h"
#import "Utils.h"

@interface LaTeXPalettesWindowController (PrivateAPI)
-(void) _initMatrices;
-(void) _loadPalettes;
-(IBAction) changeGroup:(id)sender;
@end

@implementation LaTeXPalettesWindowController

-(id) init
{
  if ((!(self = [super initWithWindowNibName:@"LaTeXPalettesWindowController"])))
    return nil;
  [self _loadPalettes];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appearanceDidChange:) name:NSAppearanceDidChangeNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:)
                                               name:NSApplicationWillTerminateNotification object:nil];
  return self;
}
//end init

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self->orderedPalettes release];
  [super dealloc];
}
//end dealloc

-(void) appearanceDidChange:(NSNotification*)notification
{
  BOOL isDarkMode = [[self window] isDarkMode];
  if (isDarkMode)
  {
    static const CGFloat gray1 = .45f;
    static const CGFloat rgba1[4] = {gray1, gray1, gray1, 1.f};
    NSColor* color = [NSColor colorWithCalibratedRed:rgba1[0] green:rgba1[1] blue:rgba1[2] alpha:rgba1[3]];
    [self->matrix setBackgroundColor:color];
    [self->matrix setDrawsBackground:YES];
    [self->scrollView setBackgroundColor:color];
    [self->scrollView setDrawsBackground:YES];
  }//end if (isDarkMode)
  else//if (!isDarkMode)
  {
    NSColor* color = [NSColor controlBackgroundColor];
    [self->matrix setBackgroundColor:color];
    [self->matrix setDrawsBackground:NO];
    [self->scrollView setBackgroundColor:color];
    [self->scrollView setDrawsBackground:YES];
  }//end if (!isDarkMode)
}
//end appearanceDidChange:

-(void) windowDidResize:(NSNotification*)notification
{
  NSDictionary* palette = [self->orderedPalettes objectAtIndex:[self->matrixChoicePopUpButton selectedTag]];
  NSNumber* numberOfItemsPerRowNumber = [palette objectForKey:@"numberOfItemsPerRow"];
  NSUInteger numberOfItemsPerRow = ([numberOfItemsPerRowNumber integerValue] <= 0) || ([numberOfItemsPerRowNumber unsignedIntegerValue] == 0) ?
                                     4 : [numberOfItemsPerRowNumber unsignedIntegerValue];
  CGFloat clipViewWidth = [[[self->matrix superview] superview] frame].size.width-[NSScroller scrollerWidthForControlSize:NSControlSizeRegular scrollerStyle:NSScrollerStyleLegacy]+1;
  CGFloat cellWidth = floor(clipViewWidth/numberOfItemsPerRow);
  [self->matrix setCellSize:NSMakeSize(cellWidth, cellWidth)];
  [self->matrix setFrame:NSMakeRect(0, 0,  floor(cellWidth*[matrix numberOfColumns]), cellWidth*[matrix numberOfRows])];
  [self->matrix setNeedsDisplay:YES];
}
//end windowDidResize:

-(void) awakeFromNib
{
  self->smallWindowMinSize = [[self window] minSize];
  [self->matrixChoicePopUpButton setFocusRingType:NSFocusRingTypeNone];
  [self->matrixChoicePopUpButton removeAllItems];
  NSString* lastDomain = [self->orderedPalettes count] ? [[self->orderedPalettes objectAtIndex:0] objectForKey:@"domainName"] : nil;
  NSUInteger i = 0;
  for(i = 0 ; i<[self->orderedPalettes count] ; ++i)
  {
    NSDictionary* paletteAsDictionary = [self->orderedPalettes objectAtIndex:i];
    NSString* domainName = [[NSFileManager defaultManager] localizedPath:[paletteAsDictionary objectForKey:@"domainName"]];
    if (![domainName isEqualToString:lastDomain])
    {
      [[self->matrixChoicePopUpButton menu] addItem:[NSMenuItem separatorItem]];
      [[self->matrixChoicePopUpButton lastItem] setToolTip:domainName];
    }
    lastDomain = domainName;
    [self->matrixChoicePopUpButton addItemWithTitle:[paletteAsDictionary objectForKey:@"localizedName"]];
    [[self->matrixChoicePopUpButton lastItem] setTag:i];
  }

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResize:)
                                               name:NSWindowDidResizeNotification object:[self window]];
  [self->matrix setDelegate:(id)self];
  [self->matrixChoicePopUpButton bind:NSSelectedTagBinding toObject:[NSUserDefaultsController sharedUserDefaultsController]
    withKeyPath:[NSUserDefaultsController adaptedKeyPath:LatexPaletteGroupKey] options:nil];
  [self->matrixChoicePopUpButton setAction:@selector(changeGroup:)];
  [self->matrixChoicePopUpButton setTarget:self];
  [self->matrix setNextKeyView:self->matrixChoicePopUpButton];
  [self changeGroup:matrixChoicePopUpButton];
  [self latexPalettesSelect:nil];
  [self appearanceDidChange:nil];
}
//end awakeFromNib

-(void) windowDidLoad
{
  NSWindow* window = [self window];
  [window setAcceptsMouseMovedEvents:YES];
  NSRect defaultFrame = [[PreferencesController sharedController] paletteLaTeXWindowFrame];
  BOOL   defaultDetails = [[PreferencesController sharedController] paletteLaTeXDetailsOpened];
  if (defaultDetails)
  {
    defaultFrame.size.height -= [self->detailsBox frame].size.height;
    defaultFrame.origin.y    += [self->detailsBox frame].size.height;
  }
  [window setFrame:defaultFrame display:YES];
  [detailsButton setState:defaultDetails ? NSOnState : NSOffState];
  
  [window setTitle:NSLocalizedString(@"LaTeX Palette", @"")];
  [self->detailsLabelTextField setStringValue:NSLocalizedString(@"Details", @"")];
  [self->detailsLabelTextField sizeToFit];

  [self->detailsLatexCodeLabelTextField setStringValue:NSLocalizedString(@"LaTeX Code :", @"")];
  [self->detailsLatexCodeLabelTextField sizeToFit];
  [self->detailsLatexCodeTextField setFrame:NSRectChange([self->detailsLatexCodeLabelTextField frame], YES, NSMaxX([self->detailsLatexCodeLabelTextField frame])+3, NO, 0, NO, 0, NO, 0)];
  
  [self->detailsRequiresLabelTextField setStringValue:NSLocalizedString(@"Requires :", @"")];
  [self->detailsRequiresLabelTextField sizeToFit];
  [self->detailsRequiresTextField setFrame:NSRectChange([self->detailsRequiresLabelTextField frame], YES, NSMaxX([self->detailsRequiresLabelTextField frame])+3,NO, 0, NO, 0, NO, 0)];

  if (defaultDetails)
    [self openOrHideDetails:detailsButton];
}
//end windowDidLoad

-(void) _loadPalettes
{
  NSFileManager* fileManager =  [NSFileManager defaultManager];                           
  NSMutableArray* allPalettes = [NSMutableArray array];
  [allPalettes addObject:
    [NSDictionary dictionaryWithObjectsAndKeys:@"built-in", @"domainName", 
                                              [[NSBundle mainBundle] pathsForResourcesOfType:@"latexpalette" inDirectory:@"palettes"], @"paths",
                                              nil]];
  NSEnumerator* domainPathsEnumerator = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask , YES) objectEnumerator];
  NSString* domainPath = nil;
  while((domainPath = [domainPathsEnumerator nextObject]))
  {
    NSString* domainName = domainPath;
    NSArray* pathComponents = [NSArray arrayWithObjects:domainPath, @"Application Support", [[NSWorkspace sharedWorkspace] applicationName], @"Palettes", nil];
    NSString* directoryPath = [NSString pathWithComponents:pathComponents];
    NSArray* palettesPaths  = [fileManager contentsOfDirectoryAtPath:directoryPath error:0];
    NSMutableArray* palettesFullPaths = [NSMutableArray arrayWithCapacity:[palettesPaths count]];
    NSEnumerator* latexPalettesEnumerator = [palettesPaths objectEnumerator];
    NSString* file = nil;
    while((file = [latexPalettesEnumerator nextObject]))
    {
      file = [directoryPath stringByAppendingPathComponent:file];
      BOOL isDirectory = NO;
      if ([fileManager fileExistsAtPath:file isDirectory:&isDirectory] && isDirectory &&
          ([[file pathExtension] caseInsensitiveCompare:@"latexpalette"] == NSOrderedSame))
        [palettesFullPaths addObject:file];
    }//end for each latexpalette subfolder
    
    if (domainName)
      [allPalettes addObject:
        [NSDictionary dictionaryWithObjectsAndKeys:domainName, @"domainName", palettesFullPaths, @"paths", nil]];
  }//end for each domain
  
  //we got all the palettes
  NSMutableArray* palettesAsDictionariesByBundle = [NSMutableArray array];
  NSEnumerator* palettesEnumerator = [allPalettes objectEnumerator];
  NSDictionary* paletteInBundle = nil;
  while((paletteInBundle = [palettesEnumerator nextObject]))
  {
    NSString* domainName = [paletteInBundle objectForKey:@"domainName"];
    NSMutableArray* palettesAsDictionaries = [NSMutableArray array];
    NSEnumerator* palettesPathEnumerator = [[paletteInBundle objectForKey:@"paths"] objectEnumerator];
    NSString* paletteFilePath = nil;
    while((paletteFilePath = [palettesPathEnumerator nextObject]))
    {
      NSBundle* bundle = [NSBundle bundleWithPath:paletteFilePath];
      NSData*   infoPlistData = [NSData dataWithContentsOfFile:[bundle pathForResource:@"Info" ofType:@"plist"] options:NSUncachedRead error:nil];
      NSPropertyListFormat format;
      id plist = !infoPlistData ? nil :
        [NSPropertyListSerialization propertyListFromData:infoPlistData mutabilityOption:NSPropertyListImmutable format:&format errorDescription:nil];
      if ([plist isKindOfClass:[NSDictionary class]])
      {
        NSString* paletteName = [plist objectForKey:@"name"];
        paletteName = [paletteName isKindOfClass:[NSString class]] ? paletteName : nil;
        NSString* paletteAuthor = [plist objectForKey:@"author"];
        paletteAuthor = [paletteAuthor isKindOfClass:[NSString class]] ? paletteAuthor : @"";
        NSNumber* numberOfItemsPerRow = [plist objectForKey:@"numberOfItemsPerRow"];
        numberOfItemsPerRow = [numberOfItemsPerRow isKindOfClass:[NSNumber class]] ? numberOfItemsPerRow : @(4);
        NSString* localizedName = paletteName ? [bundle localizedStringForKey:paletteName value:paletteName table:nil] : nil;

        NSDictionary* itemDefault = [plist objectForKey:@"itemDefault"];
        itemDefault = [itemDefault isKindOfClass:[NSDictionary class]] ? itemDefault : nil;

        NSArray*  items = [plist objectForKey:@"items"];
        NSEnumerator* itemsEnumerator = [items isKindOfClass:[NSArray class]] ? [items objectEnumerator] : nil;
        NSDictionary* item = nil;
        NSMutableArray* palette = [NSMutableArray arrayWithCapacity:10];
        while((item = [itemsEnumerator nextObject]))
        {
          if ([item isKindOfClass:[NSDictionary class]])
          {
            NSString* itemName = [item objectForKey:@"name" withClass:[NSString class]];
            NSString* localizedItemName = itemName ? [bundle localizedStringForKey:itemName value:itemName table:nil] : nil;
            NSString* resourceName  = [item objectForKey:@"resourceName" withClass:[NSString class]];
            resourceName = resourceName ? resourceName : itemName;
            NSString* resourcePath  = [bundle pathForImageResource:resourceName];
            NSString* latexCode     = [item objectForKey:@"latexCode" withClass:[NSString class]];
            NSString* requires      = [item objectForKey:@"requires" withClass:[NSString class]];
            NSNumber* isEnvironment = [item objectForKey:@"isEnvironment" withClass:[NSNumber class]];
            NSNumber* numberOfArguments = [item objectForKey:@"numberOfArguments" withClass:[NSNumber class]];
            numberOfArguments = numberOfArguments ? numberOfArguments :
                                [itemDefault objectForKey:@"numberOfArguments" withClass:[NSNumber class]];
            NSString* argumentToken = [item objectForKey:@"argumentToken" withClass:[NSString class]];
            argumentToken = argumentToken ? argumentToken :
                            [itemDefault objectForKey:@"argumentToken" withClass:[NSString class]];
            NSString* argumentTokenDefaultReplace = [item objectForKey:@"argumentTokenDefaultReplace" withClass:[NSString class]];
            argumentTokenDefaultReplace = argumentTokenDefaultReplace ? argumentTokenDefaultReplace :
                            [itemDefault objectForKey:@"argumentTokenDefaultReplace" withClass:[NSString class]];
            NSNumber* argumentTokenRemoveBraces = [item objectForKey:@"argumentTokenRemoveBraces" withClass:[NSNumber class]];
            PaletteItem* paletteItem =
              [[PaletteItem alloc] initWithName:itemName localizedName:localizedItemName resourcePath:resourcePath
                                           type:(isEnvironment && [isEnvironment boolValue] ? LATEX_ITEM_TYPE_ENVIRONMENT : LATEX_ITEM_TYPE_STANDARD)
                                     numberOfArguments:[numberOfArguments unsignedIntegerValue]
                                     latexCode:latexCode requires:requires
                                     argumentToken:argumentToken
                                     argumentTokenDefaultReplace:argumentTokenDefaultReplace
                                     argumentTokenRemoveBraces:[argumentTokenRemoveBraces boolValue]
                                     ];
            if (paletteItem)
              [palette addObject:paletteItem];
            [paletteItem release];
          }//end if item is a dictionary
        }//end for each item
        
        if (palette)
          [palettesAsDictionaries addObject:
            [NSDictionary dictionaryWithObjectsAndKeys:
              paletteName, @"name",
              localizedName, @"localizedName",
              paletteAuthor, @"author",
              numberOfItemsPerRow, @"numberOfItemsPerRow",
              domainName, @"domainName",
              palette, @"items", nil]];
      }//end if plist is dictionary
    }//end for each palette path
    [palettesAsDictionariesByBundle addObject:palettesAsDictionaries];
  }//end for each bundle
  
  [palettesAsDictionariesByBundle makeObjectsPerformSelector:@selector(sortUsingDescriptors:)
     withObject:[NSArray arrayWithObjects:[[[NSSortDescriptor alloc] initWithKey:@"localizedName" ascending:YES] autorelease],
                                          [[[NSSortDescriptor alloc] initWithKey:@"index"         ascending:YES] autorelease], nil]];

  [self->orderedPalettes release];
  self->orderedPalettes = [[NSMutableArray alloc] init];
  NSEnumerator* enumerator = [palettesAsDictionariesByBundle objectEnumerator];
  NSArray* orderedPalettesInBundle = nil;
  while((orderedPalettesInBundle = [enumerator nextObject]))
    [self->orderedPalettes addObjectsFromArray:orderedPalettesInBundle];
}
//end _loadPalettes

-(void) reloadPalettes
{
  [self _loadPalettes];
  [self awakeFromNib];
}
//end reloadPalettes

-(void) mouseMoved:(NSEvent*)event
{
  NSClipView* clipView = (NSClipView*) [self->matrix superview];
  NSPoint locationInWindow = [event locationInWindow];
  NSPoint location = [clipView convertPoint:locationInWindow fromView:nil];
  NSRect clipBounds = [clipView bounds];
  if (NSPointInRect(location, clipBounds))
  {
    NSInteger row = -1;
    NSInteger column = 0;
    BOOL ok = [self->matrix getRow:&row column:&column forPoint:[self->matrix convertPoint:location fromView:clipView]];
    if (ok)
    {
      [self->matrix selectCellAtRow:row column:column];
      [self latexPalettesSelect:self->matrix];
      [clipView setBounds:clipBounds];
      [clipView setNeedsDisplay:YES];
    }
  }
}
//end mouseMoved:

//triggered when the user selects an element on the palette
-(IBAction) latexPalettesSelect:(id)sender
{
  PaletteItem* selectedItem = [[self->matrix selectedCell] representedObject];
  if (!selectedItem || ![selectedItem requires] || [[selectedItem requires] isEqualToString:@""] )
    [self->detailsRequiresTextField setStringValue:@"-"];
  else
    [self->detailsRequiresTextField setStringValue:[NSString stringWithFormat:@"\\usepackage{%@}", [selectedItem requires]]];
  [self->detailsRequiresTextField sizeToFit];
  NSImage* image = [selectedItem image];
  if (image) //expands the image to fill the imageView proportionnaly
  {
    NSSize imageSize = [image size];
    NSSize frameSize = [detailsImageView bounds].size;
    CGFloat ratio = imageSize.height ? imageSize.width/imageSize.height : 1.f;
    imageSize = frameSize;
    if (ratio <= 1) //width <= height
      imageSize.width *= ratio;
    else
      imageSize.height /= ratio;
    [image setSize:imageSize];
  }
  [self->detailsImageView setImage:image];
  [self->detailsLatexCodeTextField setStringValue:selectedItem ? [selectedItem latexCode] : @"-"];
  [self->detailsLatexCodeTextField sizeToFit];
}
//end latexPalettesSelect:

//triggered when the user clicks on a palette; must insert the latex code of the selected symbol in the body of the document
-(IBAction) latexPalettesDoubleClick:(id)sender
{
  [self latexPalettesSelect:sender];
  [[AppController appController] latexPalettesDoubleClick:sender];
}
//end latexPalettesDoubleClick:

-(IBAction) changeGroup:(id)sender
{
  NSInteger tag = [sender selectedTag];
  if ((tag >= 0) && ((unsigned int)tag < [orderedPalettes count]))
  {
    NSDictionary* palette = [orderedPalettes objectAtIndex:tag];
    NSString* author = [palette objectForKey:@"author"];
    [authorTextField setStringValue:[NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Author", @""), author]];
    NSNumber* numberOfItemsPerRowNumber = [palette objectForKey:@"numberOfItemsPerRow"];
    NSUInteger numberOfItemsPerRow = ([numberOfItemsPerRowNumber integerValue] <= 0) || ([numberOfItemsPerRowNumber unsignedIntegerValue] == 0) ?
                                       4 : [numberOfItemsPerRowNumber unsignedIntegerValue];
    NSArray* items = [palette objectForKey:@"items"];
    NSUInteger nbItems = [items count];
    NSInteger nbColumns = numberOfItemsPerRow;
    NSInteger nbRows    = (nbItems/numberOfItemsPerRow+1)+(nbItems%numberOfItemsPerRow ? 0 : -1);
    PaletteCell* prototype = [[[PaletteCell alloc] initImageCell:nil] autorelease];
    [prototype setImageAlignment:NSImageAlignCenter];
    [prototype setImageScaling:NSScaleToFit];
    while([matrix numberOfRows])
      [matrix removeRow:0];
    [matrix setPrototype:prototype];
    [matrix renewRows:nbRows columns:nbColumns];
    NSUInteger i = 0;
    for(i = 0 ; i<nbItems ; ++i)
    {
      NSInteger row    = i/numberOfItemsPerRow;
      NSInteger column = i%numberOfItemsPerRow;
      NSImageCell* cell = (NSImageCell*) [matrix cellAtRow:row column:column];
      PaletteItem* item = [items objectAtIndex:i];
      [cell setRepresentedObject:item];
      [cell setImage:[item image]];
      [matrix setToolTip:[item toolTip] forCell:cell]; 
    }//end for each item
    [self windowDidResize:nil];
    [self latexPalettesSelect:nil];
  }//end if ((tag >= 0) && ((unsigned int)tag < [orderedPalettes count]))
}
//end changeGroup:

-(IBAction) openOrHideDetails:(id)sender
{
  if (!sender)
    sender = detailsButton;

  if ([sender state] == NSOnState)
  {
    NSUInteger oldMatrixAutoresizingMask = [matrixBox autoresizingMask];
    [matrixBox setAutoresizingMask:NSViewMinXMargin|NSViewMaxXMargin|NSViewMinYMargin];

    [detailsBox retain];
    [detailsBox removeFromSuperviewWithoutNeedingDisplay];
    
    NSWindow* window = [self window];
    NSRect windowFrame = [window frame];
    NSRect detailsBoxFrame = [detailsBox frame];
    windowFrame.size.height += detailsBoxFrame.size.height;
    windowFrame.origin.y    -= detailsBoxFrame.size.height;
    [window setFrame:windowFrame display:YES animate:YES];
    
    NSView* contentView = [window contentView];
    NSRect contentViewFrame = [contentView frame];
    [contentView addSubview:detailsBox];
    [detailsBox setFrame:NSMakeRect(0, 0, contentViewFrame.size.width, [detailsBox frame].size.height)];
    
    [matrixBox setAutoresizingMask:oldMatrixAutoresizingMask];
    
    NSSize minSize = self->smallWindowMinSize;
    minSize.height += [detailsBox frame].size.height;
    [window setMinSize:minSize];
    
    [window display];
  }
  else
  {
    NSUInteger oldMatrixAutoresizingMask = [matrixBox autoresizingMask];
    [matrixBox setAutoresizingMask:NSViewMinXMargin|NSViewMaxXMargin|NSViewMinYMargin];

    [detailsBox retain];
    [detailsBox removeFromSuperviewWithoutNeedingDisplay];
    
    NSWindow* window = [self window];
    NSRect windowFrame = [window frame];
    NSRect detailsBoxFrame = [detailsBox frame];
    windowFrame.size.height -= detailsBoxFrame.size.height;
    windowFrame.origin.y    += detailsBoxFrame.size.height;
    [window setFrame:windowFrame display:YES animate:YES];

    [matrixBox setAutoresizingMask:oldMatrixAutoresizingMask];

    [window setMinSize:self->smallWindowMinSize];
    [window display];
  }
}
//end openOrHideDetails:

-(void) applicationWillTerminate:(NSNotification*)notification
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  [preferencesController setPaletteLaTeXWindowFrame:[[self window] frame]];
  [preferencesController setPaletteLaTeXDetailsOpened:([detailsButton state] == NSOnState)];
}
//end applicationWillTerminate:

@end
