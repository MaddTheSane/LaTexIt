//
//  AdditionalFilesController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/08/08.
//  Copyright 2008 LAIC. All rights reserved.
//

#import "AdditionalFilesController.h"

#import "AppController.h"

@interface AdditionalFilesController (PrivateAPI)
-(void) removeFilePaths:(NSArray*)filePaths;
@end

@implementation AdditionalFilesController

-(id) init
{
  if (![super initWithWindowNibName:@"AdditionalFiles"])
    return nil;
  filesArray = [[NSMutableArray alloc] init];
  filesArrayController = [[NSArrayController alloc] init];
  [filesArrayController bind:@"contentArray" toObject:self withKeyPath:@"filesArray" options:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
  return self;
}
//end init

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [filesArrayController release];
  [filesArray release];
  [super dealloc];
}
//end dealloc

-(void) windowDidLoad
{
  NSPanel* window = (NSPanel*)[self window];
  [window setHidesOnDeactivate:NO];//prevents from disappearing when LaTeXiT is not active
  [window setFloatingPanel:NO];//prevents from floating always above
  [window setFrameAutosaveName:@"AdditionalFiles"];
  [window setTitle:NSLocalizedString(@"Additional files", @"Additional files")];
  [filesTableView setDataSource:self];
  [[filesTableView tableColumnWithIdentifier:@"file"] bind:@"value" toObject:filesArrayController withKeyPath:@"arrangedObjects.lastPathComponent" options:nil];
  [removeFilesButton bind:@"enabled" toObject:filesArrayController withKeyPath:@"canRemove" options:nil];
  [filesTableView setTarget:self];
  [filesTableView setDoubleAction:@selector(openSelection:)];
}
//end windowDidLoad

-(NSArray*) filepaths
{
  return [NSArray arrayWithArray:filesArray];
}
//end filepaths

-(IBAction) addFiles:(id)sender
{
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  [openPanel setAllowsMultipleSelection:YES];
  [openPanel setCanChooseDirectories:YES];
  [openPanel setCanChooseFiles:YES];
  [openPanel setCanCreateDirectories:NO];
  [openPanel setCanHide:YES];
  [openPanel setCanSelectHiddenExtension:YES];
  [openPanel setResolvesAliases:YES];
  [openPanel beginSheetForDirectory:nil file:nil types:nil modalForWindow:[self window] modalDelegate:self
                     didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}
//end addFiles:

-(IBAction) removeFiles:(id)sender
{
  [self removeFilePaths:[[filesArrayController arrangedObjects] objectsAtIndexes:[filesTableView selectedRowIndexes]]];
}
//end removeFiles:

-(IBAction) help:(id)sender
{
  [[AppController appController] showHelp:self section:[NSString stringWithFormat:@"\"%@\"\n\n", NSLocalizedString(@"Additional files", @"Additional files")]];
}
//end help:

-(IBAction) openSelection:(id)sender
{
  NSArray* selection = [[filesArrayController arrangedObjects] objectsAtIndexes:[filesTableView selectedRowIndexes]];
  NSMutableArray* urls = [NSMutableArray arrayWithCapacity:[selection count]];
  NSEnumerator* enumerator = [selection objectEnumerator];
  NSString* filepath = nil;
  while((filepath = [enumerator nextObject]))
    [urls addObject:[NSURL fileURLWithPath:filepath]];
  [[NSWorkspace sharedWorkspace] openURLs:urls withAppBundleIdentifier:nil options:NSWorkspaceLaunchDefault
           additionalEventParamDescriptor:nil launchIdentifiers:nil];
}
//end openSelection:

-(void) removeFilePaths:(NSArray*)filePaths
{
  NSString* directory      = [AppController latexitTemporaryPath];
  NSEnumerator* enumerator = [filePaths objectEnumerator];
  NSString* filepath = nil;
  while((filepath = [enumerator nextObject]))
    [[NSFileManager defaultManager] removeFileAtPath:[directory stringByAppendingPathComponent:[filepath lastPathComponent]] handler:NULL];
  [filesArrayController removeObjects:filePaths];
}
//end removeFilePaths:

-(void) openPanelDidEnd:(NSOpenPanel*)panel returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
  if (returnCode == NSOKButton)
  {
    [filesArrayController addObjects:[panel filenames]];
    [filesTableView reloadData];
  }
}
//end openPanelDidEnd:returnCode:contextInfo:

-(int) numberOfRowsInTableView:(NSTableView *)aTableView {return 0;} //end numberOfRowsInTableView:
-(id) tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {return nil;}

-(NSDragOperation) tableView:(NSTableView*)tableView validateDrop:(id<NSDraggingInfo>)info
                 proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
  NSPasteboard* pboard = [info draggingPasteboard];
  BOOL ok = ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]] != nil);
  return ok ? NSDragOperationLink : NSDragOperationNone;
}
//end tableView:validateDrop:proposedRow:proposedDropOperation:

-(BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
  NSArray* filepaths = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
  [filesArrayController insertObjects:filepaths
              atArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(row, [filepaths count])]];
  return YES;
}
//end tableView:acceptDrop:row:dropOperation:

-(void) applicationWillTerminate:(NSNotification *)aNotification
{
  [self removeFilePaths:[[filesArray copy] autorelease]];
}
//end applicationWillTerminate:

@end
