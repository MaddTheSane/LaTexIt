//  LatexPalettesController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 4/04/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.

//The LatexPalettesController controller is responsible for loading and initializing the palette

#import "LatexPalettesController.h"

#import "AppController.h"
#import "NSApplicationExtended.h"
#import "NSPopUpButtonExtended.h"
#import "PaletteCell.h"
#import "PaletteItem.h"
#import "PreferencesController.h"
#import "Utils.h"

@interface LatexPalettesController (PrivateAPI)
-(void) _initMatrices;
-(void) _loadPalettes;
@end

@implementation LatexPalettesController

-(id) init
{
  if (![super initWithWindowNibName:@"LatexPalettes"])
    return nil;
  [self _loadPalettes];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:)
                                               name:NSApplicationWillTerminateNotification object:nil];
  return self;
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [orderedPalettes release];
  [super dealloc];
}
//end dealloc:

-(void) windowDidResize:(NSNotification*)notification
{
  NSDictionary* palette = [orderedPalettes objectAtIndex:[matrixChoicePopUpButton selectedTag]];
  NSNumber* numberOfItemsPerRowNumber = [palette objectForKey:@"numberOfItemsPerRow"];
  unsigned int numberOfItemsPerRow = ([numberOfItemsPerRowNumber intValue] <= 0) || ([numberOfItemsPerRowNumber unsignedIntValue] == 0) ?
                                     4 : [numberOfItemsPerRowNumber unsignedIntValue];
  float clipViewWidth = [[[matrix superview] superview] frame].size.width-[NSScroller scrollerWidth]+1;
  float cellWidth = floor(clipViewWidth/numberOfItemsPerRow);
  [matrix setCellSize:NSMakeSize(cellWidth, cellWidth)];
  [matrix setFrame:NSMakeRect(0, 0,  floor(cellWidth*[matrix numberOfColumns]), cellWidth*[matrix numberOfRows])];
  [matrix setNeedsDisplay:YES];
}
//end windowDidResize:

-(void) awakeFromNib
{
  [matrixChoicePopUpButton setFocusRingType:NSFocusRingTypeNone];
  [matrixChoicePopUpButton removeAllItems];
  NSString* lastDomain = [orderedPalettes count] ? [[orderedPalettes objectAtIndex:0] objectForKey:@"domainName"] : nil;
  unsigned int i = 0;
  for(i = 0 ; i<[orderedPalettes count] ; ++i)
  {
    NSDictionary* paletteAsDictionary = [orderedPalettes objectAtIndex:i];
    NSString* domainName = [Utils localizedPath:[paletteAsDictionary objectForKey:@"domainName"]];
    if (![domainName isEqualToString:lastDomain])
    {
      [[matrixChoicePopUpButton menu] addItem:[NSMenuItem separatorItem]];
      [[matrixChoicePopUpButton lastItem] setToolTip:domainName];
    }
    lastDomain = domainName;
    [matrixChoicePopUpButton addItemWithTitle:[paletteAsDictionary objectForKey:@"localizedName"]];
    [[matrixChoicePopUpButton lastItem] setTag:i];
  }

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResize:)
                                               name:NSWindowDidResizeNotification object:[self window]];
  [matrix setDelegate:self];
  [matrixChoicePopUpButton selectItemWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:LatexPaletteGroupKey]];
  if ([matrixChoicePopUpButton selectedTag] == -1)
    [matrixChoicePopUpButton selectItemWithTag:0];
  [matrix setNextKeyView:matrixChoicePopUpButton];
  [self changeGroup:matrixChoicePopUpButton];
  [self latexPalettesSelect:nil];
}
//end awakeFromNib

-(void) windowDidLoad
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSWindow* window = [self window];
  [window setAcceptsMouseMovedEvents:YES];
  NSRect defaultFrame = NSRectFromString([userDefaults stringForKey:LatexPaletteFrameKey]);
  BOOL   defaultDetails = [userDefaults boolForKey:LatexPaletteDetailsStateKey];
  if (defaultDetails)
  {
    defaultFrame.size.height -= [detailsBox frame].size.height;
    defaultFrame.origin.y    += [detailsBox frame].size.height;
  }
  [window setFrame:defaultFrame display:YES];
  [window setMinSize:NSMakeSize(200, 170)];
  [detailsButton setState:defaultDetails ? NSOnState : NSOffState];
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
    NSArray* pathComponents = [NSArray arrayWithObjects:domainPath, @"Application Support", [NSApp applicationName], @"Palettes", nil];
    NSString* directoryPath = [NSString pathWithComponents:pathComponents];
    NSArray* palettesPaths  = [fileManager directoryContentsAtPath:directoryPath];
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
      NSData*   infoPlistData = [NSData dataWithContentsOfFile:[bundle pathForResource:@"Info" ofType:@"plist"]];
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
        numberOfItemsPerRow = [numberOfItemsPerRow isKindOfClass:[NSNumber class]] ? numberOfItemsPerRow : [NSNumber numberWithUnsignedInt:4];
        NSString* localizedName = paletteName ? [bundle localizedStringForKey:paletteName value:paletteName table:nil] : nil;
        NSArray*  items = [plist objectForKey:@"items"];
        NSEnumerator* itemsEnumerator = [items isKindOfClass:[NSArray class]] ? [items objectEnumerator] : nil;
        NSDictionary* item = nil;
        NSMutableArray* palette = [NSMutableArray arrayWithCapacity:10];
        while((item = [itemsEnumerator nextObject]))
        {
          if ([item isKindOfClass:[NSDictionary class]])
          {
            NSString* itemName      = [item objectForKey:@"name"];
            itemName = [itemName isKindOfClass:[NSString class]] ? itemName : nil;
            NSString* localizedItemName = itemName ? [bundle localizedStringForKey:itemName value:itemName table:nil] : nil;
            NSString* resourceName  = [item objectForKey:@"resourceName"];
            resourceName = [resourceName isKindOfClass:[NSString class]] ? resourceName : itemName;
            NSString* resourcePath  = [bundle pathForImageResource:resourceName];
            resourcePath = [resourcePath isKindOfClass:[NSString class]] ? resourcePath : nil;
            NSString* latexCode     = [item objectForKey:@"latexCode"];
            latexCode = [latexCode isKindOfClass:[NSString class]] ? latexCode : nil;
            NSString* requires      = [item objectForKey:@"requires"];
            requires = [requires isKindOfClass:[NSString class]] ? requires : nil;
            NSNumber* isEnvironment = [item objectForKey:@"isEnvironment"];
            isEnvironment = [isEnvironment isKindOfClass:[NSNumber class]] ? isEnvironment : nil;
            NSNumber* numberOfArguments = [item objectForKey:@"numberOfArguments"];
            numberOfArguments = [numberOfArguments isKindOfClass:[NSNumber class]] ? numberOfArguments : nil;
            PaletteItem* paletteItem =
              [[PaletteItem alloc] initWithName:itemName localizedName:localizedItemName resourcePath:resourcePath
                                           type:(isEnvironment && [isEnvironment boolValue] ? LATEX_ITEM_TYPE_ENVIRONMENT : LATEX_ITEM_TYPE_STANDARD)
                                     numberOfArguments:[numberOfArguments unsignedIntValue] latexCode:latexCode
                                      requires:requires];
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

  [orderedPalettes release];
  orderedPalettes = [[NSMutableArray alloc] init];
  NSEnumerator* enumerator = [palettesAsDictionariesByBundle objectEnumerator];
  NSArray* orderedPalettesInBundle = nil;
  while((orderedPalettesInBundle = [enumerator nextObject]))
    [orderedPalettes addObjectsFromArray:orderedPalettesInBundle];
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
  NSClipView* clipView = (NSClipView*) [matrix superview];
  NSPoint locationInWindow = [event locationInWindow];
  NSPoint location = [clipView convertPoint:locationInWindow fromView:nil];
  NSRect clipBounds = [clipView bounds];
  if (NSPointInRect(location, clipBounds))
  {
    int row = -1;
    int column = 0;
    BOOL ok = [matrix getRow:&row column:&column forPoint:[matrix convertPoint:location fromView:clipView]];
    if (ok)
    {
      [matrix selectCellAtRow:row column:column];
      [self latexPalettesSelect:matrix];
      [clipView setBounds:clipBounds];
      [clipView setNeedsDisplay:YES];
    }
  }
}
//end mouseMoved:

//triggered when the user selects an element on the palette
-(IBAction) latexPalettesSelect:(id)sender
{
  PaletteItem* selectedItem = [[matrix selectedCell] representedObject];
  if (!selectedItem || ![selectedItem requires] || [[selectedItem requires] isEqualToString:@""] )
    [detailsRequiresTextField setStringValue:@"-"];
  else
    [detailsRequiresTextField setStringValue:[NSString stringWithFormat:@"\\usepackage{%@}", [selectedItem requires]]];
  NSImage* image = [selectedItem image];
  if (image) //expands the image to fill the imageView proportionnaly
  {
    NSSize imageSize = [image size];
    NSSize frameSize = [detailsImageView bounds].size;
    float ratio = imageSize.height ? imageSize.width/imageSize.height : 1.f;
    imageSize = frameSize;
    if (ratio <= 1) //width <= height
      imageSize.width *= ratio;
    else
      imageSize.height /= ratio;
    [image setSize:imageSize];
  }
  [detailsImageView setImage:image];
  [detailsLatexCodeTextField setStringValue:selectedItem ? [selectedItem latexCode] : @"-"];
}
//end latexPalettesSelect:

//triggered when the user clicks on a palette; must insert the latex code of the selected symbol in the body of the document
-(IBAction) latexPalettesClick:(id)sender
{
  [self latexPalettesSelect:sender];
  [[AppController appController] latexPalettesClick:sender];
}
//end latexPalettesClick:

-(IBAction) changeGroup:(id)sender
{
  int tag = [sender selectedTag];
  if ((tag >= 0) && ((unsigned int)tag < [orderedPalettes count]))
  {
    NSDictionary* palette = [orderedPalettes objectAtIndex:tag];
    NSString* author = [palette objectForKey:@"author"];
    [authorTextField setStringValue:[NSString stringWithFormat:@"%@ : %@", NSLocalizedString(@"Author", @"Author"), author]];
    NSNumber* numberOfItemsPerRowNumber = [palette objectForKey:@"numberOfItemsPerRow"];
    unsigned int numberOfItemsPerRow = ([numberOfItemsPerRowNumber intValue] <= 0) || ([numberOfItemsPerRowNumber unsignedIntValue] == 0) ?
                                       4 : [numberOfItemsPerRowNumber unsignedIntValue];
    NSArray* items = [palette objectForKey:@"items"];
    unsigned int nbItems = [items count];
    int nbColumns = numberOfItemsPerRow;
    int nbRows    = (nbItems/numberOfItemsPerRow+1)+(nbItems%numberOfItemsPerRow ? 0 : -1);
    PaletteCell* prototype = [[[PaletteCell alloc] initImageCell:nil] autorelease];
    [prototype setImageAlignment:NSImageAlignCenter];
    [prototype setImageScaling:NSScaleToFit];
    while([matrix numberOfRows])
      [matrix removeRow:0];
    [matrix setPrototype:prototype];
    [matrix renewRows:nbRows columns:nbColumns];
    unsigned int i = 0;
    for(i = 0 ; i<nbItems ; ++i)
    {
      int row    = i/numberOfItemsPerRow;
      int column = i%numberOfItemsPerRow;
      NSImageCell* cell = (NSImageCell*) [matrix cellAtRow:row column:column];
      PaletteItem* item = [items objectAtIndex:i];
      [cell setRepresentedObject:item];
      [cell setImage:[item image]];
      [matrix setToolTip:[item toolTip] forCell:cell]; 
    }
    [self windowDidResize:nil];
    [[NSUserDefaults standardUserDefaults] setInteger:tag forKey:LatexPaletteGroupKey];
    [self latexPalettesSelect:nil];
  }
}
//end changeGroup:

-(IBAction) openOrHideDetails:(id)sender
{
  if (!sender)
    sender = detailsButton;

  if ([sender state] == NSOnState)
  {
    unsigned int oldMatrixAutoresizingMask = [matrixBox autoresizingMask];
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
    
    NSSize minSize = [window minSize];
    minSize.height += [detailsBox frame].size.height;
    [window setMinSize:minSize];
    
    [window display];
  }
  else
  {
    unsigned int oldMatrixAutoresizingMask = [matrixBox autoresizingMask];
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

    NSSize minSize = [window minSize];
    minSize.height -= [detailsBox frame].size.height;
    [window setMinSize:minSize];

    [window display];
  }
}
//end openOrHideDetails:

-(void) applicationWillTerminate:(NSNotification*)notification
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [userDefaults setObject:NSStringFromRect([[self window] frame]) forKey:LatexPaletteFrameKey];
  [userDefaults setBool:([detailsButton state] == NSOnState) forKey:LatexPaletteDetailsStateKey];
}
//end applicationWillTerminate:

@end
