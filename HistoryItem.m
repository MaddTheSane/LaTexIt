//
//  HistoryItem.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/02/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.
//

#import "HistoryItem.h"

#import "LatexitEquation.h"
#import "LatexitEquationWrapper.h"
#import "LaTeXProcessor.h"
#import "NSManagedObjectContextExtended.h"
#import "NSWorkspaceExtended.h"
#import "Utils.h"

#import <LinkBack/LinkBack.h>

@implementation HistoryItem

static NSEntityDescription* cachedEntity = nil;
static NSEntityDescription* cachedWrapperEntity = nil;

+(NSEntityDescription*) entity
{
  if (!cachedEntity)
  {
    @synchronized(self)
    {
      if (!cachedEntity)
        cachedEntity = [[[[[LaTeXProcessor sharedLaTeXProcessor] managedObjectModel] entitiesByName] objectForKey:NSStringFromClass([self class])] retain];
    }//end @synchronized(self)
  }//end if (!cachedEntity)
  return cachedEntity;
}
//end entity

+(NSEntityDescription*) wrapperEntity
{
  if (!cachedWrapperEntity)
  {
    @synchronized(self)
    {
      if (!cachedWrapperEntity)
        cachedWrapperEntity = [[[[[LaTeXProcessor sharedLaTeXProcessor] managedObjectModel] entitiesByName]
          objectForKey:@"HistoryEquationWrapper"] retain];
    }//end @synchronized(self)
  }//end if (!cachedWrapperEntity)
  return cachedWrapperEntity;
}
//end wrapperEntity

-(id) initWithEquation:(LatexitEquation*)equation insertIntoManagedObjectContext:(NSManagedObjectContext*)managedObjectContext
{
  if (!((self = [super initWithEntity:[[self class] entity] insertIntoManagedObjectContext:managedObjectContext])))
    return nil;
  [self setEquation:equation];
  return self;
}
//end initWithEquation:

-(void) dealloc
{
  [self dispose];
  //in didTurnInToFault, a problem occurs with undo, that does not call any awakeFrom... to reactivate the observer
  [super dealloc];
}
//end dealloc

-(void) dispose
{
  @synchronized(self)
  {
    if (self->kvoEnabled)
    {
      [self removeObserver:self forKeyPath:@"equationWrapper.equation.backgroundColor"];
      self->kvoEnabled = NO;
    }
  }//end @synchronized(self)
}
//end dispose

-(void) didTurnIntoFault
{
  [super didTurnIntoFault];
}
//end didTurnIntoFault

-(void) awakeFromFetch
{
  [super awakeFromFetch];
  @synchronized(self)
  {
    [self addObserver:self forKeyPath:@"equationWrapper.equation.backgroundColor" options:0 context:nil];
    self->kvoEnabled = YES;
  }//end @synchronized(self)
}
//end awakeFromFetch

-(void) awakeFromInsert
{
  [super awakeFromInsert];
  @synchronized(self)
  {
    [self addObserver:self forKeyPath:@"equationWrapper.equation.backgroundColor" options:0 context:nil];
    self->kvoEnabled = YES;
  }//end @synchronized(self)
  NSManagedObject* equationWrapper = [self valueForKey:@"equationWrapper"];
  [[self managedObjectContext] safeInsertObject:equationWrapper];
  NSManagedObject* equation = [equationWrapper valueForKey:@"equation"];
  [[self managedObjectContext] safeInsertObject:equation];
}
//end awakeFromInsert

-(BOOL) dummyPropertyToForceUIRefresh
{
  return YES;
}
//end dummyPropertyToForceUIRefresh

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  if ([keyPath isEqualToString:@"equationWrapper.equation.backgroundColor"])
  {
    NSManagedObjectContext* managedObjectContext = [self managedObjectContext];
    [managedObjectContext disableUndoRegistration];
    [self willChangeValueForKey:@"dummyPropertyToForceUIRefresh"];
    [self didChangeValueForKey:@"dummyPropertyToForceUIRefresh"];
    [managedObjectContext enableUndoRegistration];
  }//end if ([keyPath isEqualToString:@"equationWrapper.equation.backgroundColor"])
}
//end observeValueForKeyPath:ofObject:change:context:

-(LatexitEquation*) equation
{
  LatexitEquation* result = nil;
  LatexitEquationWrapper* equationWrapper = [self valueForKey:@"equationWrapper"];
  result = [equationWrapper equation];
  return result;
}
//end equation

-(void) setEquation:(LatexitEquation*)equation
{
  if (equation != [self equation])
  {
    [[self managedObjectContext] safeInsertObject:equation];
    LatexitEquationWrapper* equationWrapper = [self valueForKey:@"equationWrapper"];
    if (!equationWrapper)
    {
      equationWrapper = [[LatexitEquationWrapper alloc]
        initWithEntity:[[self class] wrapperEntity] insertIntoManagedObjectContext:[self managedObjectContext]];
      [equationWrapper setValue:self forKey:@"historyItem"]; //if current managedObjectContext is nil, this is necessary
      [self setValue:equationWrapper forKey:@"equationWrapper"];
      [equationWrapper release];
    }//end if (!equationWrapper)
    else
      [[self managedObjectContext] safeInsertObject:equationWrapper];
    [equationWrapper setEquation:equation];
    [equation setValue:equationWrapper forKey:@"wrapper"]; //if current managedObjectContext is nil, this is necessary
  }//end if (equation != [self equation])
}
//end setEquation:

//to feed a pasteboard. It needs a document, because there may be some temporary files needed for certain kind of data
//the lazyDataProvider, if not nil, is the one who will call [pasteboard:provideDataForType] *as needed* (to save time)
-(void) writeToPasteboard:(NSPasteboard *)pboard isLinkBackRefresh:(BOOL)isLinkBackRefresh lazyDataProvider:(id)lazyDataProvider
{
  //first, feed with equation
  [[self equation] writeToPasteboard:pboard isLinkBackRefresh:isLinkBackRefresh lazyDataProvider:lazyDataProvider];

  //overwrite linkBack pasteboard
  NSArray* historyItemArray = [NSArray arrayWithObject:self];
  NSData*  historyItemData  = [NSKeyedArchiver archivedDataWithRootObject:historyItemArray];
  NSDictionary* linkBackPlist =
    isLinkBackRefresh ? [NSDictionary linkBackDataWithServerName:[[NSWorkspace sharedWorkspace] applicationName] appData:historyItemData
                                      actionName:LinkBackRefreshActionName suggestedRefreshRate:0]
                     : [NSDictionary linkBackDataWithServerName:[[NSWorkspace sharedWorkspace] applicationName] appData:historyItemData]; 
  
  if (isLinkBackRefresh)
    [pboard declareTypes:[NSArray arrayWithObject:LinkBackPboardType] owner:self];
  else
    [pboard addTypes:[NSArray arrayWithObject:LinkBackPboardType] owner:self];
  [pboard setPropertyList:linkBackPlist forType:LinkBackPboardType];
}
//end writeToPasteboard:isLinkBackRefresh:lazyDataProvider:

-(id) plistDescription
{
  NSMutableDictionary* plist = 
    [NSMutableDictionary dictionaryWithObjectsAndKeys:
       @"2.1.0", @"version",
       [[self equation] plistDescription], @"equation",
       nil];
  return plist;
}
//end plistDescription

-(id) initWithDescription:(id)description
{
  NSManagedObjectContext* managedObjectContext = [LatexitEquation currentManagedObjectContext];
  if (!((self = [super initWithEntity:[[self class] entity] insertIntoManagedObjectContext:managedObjectContext])))
    return nil;
  NSString* version = [description objectForKey:@"version"];
  BOOL isOldLibraryItem = ([version compare:@"2.0.0" options:NSNumericSearch] == NSOrderedAscending);
  id equationDescription = !isOldLibraryItem ? [description objectForKey:@"equation"] : description;
  LatexitEquation* latexitEquation = [[LatexitEquation alloc] initWithDescription:equationDescription];
  [self setEquation:latexitEquation];
  [latexitEquation release];
  return self;
}
//end initWithDescription:

+(HistoryItem*) historyItemWithDescription:(id)description
{
  HistoryItem* result = nil;
  BOOL ok = [description isKindOfClass:[NSDictionary class]];
  NSString* version = !ok ? nil : [description objectForKey:@"version"];
  BOOL isOldLibraryItem = (ok && ([version compare:@"2.0.0" options:NSNumericSearch] == NSOrderedAscending));
  BOOL isGroupItem = ok && ((!isOldLibraryItem && [description objectForKey:@"children"]) || (isOldLibraryItem && [description objectForKey:@"content"]));
  BOOL isEquation  = ok && ((isOldLibraryItem && !isGroupItem) || (!isOldLibraryItem && [description objectForKey:@"equation"]));
  Class instanceClass = isEquation ? [HistoryItem class] : 0;
  result = !instanceClass ? nil : [[instanceClass alloc] initWithDescription:description];
  return [result autorelease];
}
//end libraryItemWithDescription:

-(void) encodeWithCoder:(NSCoder*)coder
{
  [coder encodeObject:@"2.1.0" forKey:@"version"];
  [coder encodeObject:[self equation] forKey:@"equation"];
}
//end encodeWithCoder:

#pragma mark legacy code
-(id) initWithCoder:(NSCoder*)coder
{
  NSString* version = [coder decodeObjectForKey:@"version"];
  NSManagedObjectContext* managedObjectContext = ([@"2.0.0" compare:version options:NSCaseInsensitiveSearch|NSNumericSearch] == NSOrderedDescending) ? nil :
    [LatexitEquation currentManagedObjectContext];
  #warning currentManagedObjectContext ???
  if (!((self = [super initWithEntity:[[self class] entity] insertIntoManagedObjectContext:managedObjectContext])))
    return nil;
  LatexitEquation* equation = nil;

  if ([version compare:@"2.0.0" options:NSCaseInsensitiveSearch|NSNumericSearch] != NSOrderedAscending)
    equation = [[coder decodeObjectForKey:@"equation"] retain];
  else //if version < 2.0.0
  {
    NSData* pdfData = nil;
    NSAttributedString* preamble = nil;
    NSAttributedString* sourceText = nil;
    NSColor* color = nil;
    double pointSize = 0.;
    NSDate* date = nil;
    #ifdef MIGRATE_ALIGN
    latex_mode_t mode = LATEX_MODE_ALIGN;
    #else
    latex_mode_t mode = LATEX_MODE_EQNARRAY;
    #endif
    NSColor* backgroundColor = nil;
    NSString* title = nil;
    if (!version || [version compare:@"1.2" options:NSCaseInsensitiveSearch|NSNumericSearch] == NSOrderedAscending)
    {
      pdfData     = [[coder decodeObjectForKey:@"pdfData"]    retain];
      NSMutableString* tempPreamble = [NSMutableString stringWithString:[coder decodeObjectForKey:@"preamble"]];
      [tempPreamble replaceOccurrencesOfString:@"\\usepackage[dvips]{color}" withString:@"\\usepackage{color}"
                                       options:0 range:NSMakeRange(0, [tempPreamble length])];
      preamble    = [[NSAttributedString alloc] initWithString:tempPreamble];
      sourceText  = [[NSAttributedString alloc] initWithString:[coder decodeObjectForKey:@"sourceText"]];
      color       = [[coder decodeObjectForKey:@"color"]      retain];
      pointSize   = [[coder decodeObjectForKey:@"pointSize"] doubleValue];
      date        = [[coder decodeObjectForKey:@"date"]       retain];
      mode        = validateLatexMode((latex_mode_t) [coder decodeIntForKey:@"mode"]);
    }
    else
    {
      pdfData     = [[coder decodeObjectForKey:@"pdfData"]    retain];
      preamble    = [[coder decodeObjectForKey:@"preamble"]   retain];
      sourceText  = [[coder decodeObjectForKey:@"sourceText"] retain];
      color       = [[coder decodeObjectForKey:@"color"]      retain];
      pointSize   = [coder decodeDoubleForKey:@"pointSize"];
      date        = [[coder decodeObjectForKey:@"date"]       retain];
      mode        = validateLatexMode((latex_mode_t) [coder decodeIntForKey:@"mode"]);
      //we need to reduce the history size and load time, so we can safely not save the cached images, since they are lazily
      //initialized in the "image" methods, using the pdfData
      backgroundColor = [[coder decodeObjectForKey:@"backgroundColor"] retain];
      title       = [[coder decodeObjectForKey:@"title"]       retain];//may be nil
    }
    //old versions of LaTeXiT would use \usepackage[pdftex]{color} in the preamble. [pdftex] is useless, in fact
    NSRange rangeOfColorPackage = [[preamble string] rangeOfString:@"\\usepackage[pdftex]{color}"];
    if (rangeOfColorPackage.location != NSNotFound)
    {
      NSMutableAttributedString* newPreamble = [[NSMutableAttributedString alloc] initWithAttributedString:preamble];
      [newPreamble replaceCharactersInRange:rangeOfColorPackage withString:@"\\usepackage{color}"];
      [preamble release];
      preamble = newPreamble;
    }
    
    equation = [[LatexitEquation alloc] initWithPDFData:pdfData preamble:preamble sourceText:sourceText color:color pointSize:pointSize date:date mode:mode backgroundColor:backgroundColor];

    [preamble release];
    [sourceText release];

    [equation setTitle:title];

    //for versions < 1.5.4, we must reannotate the pdfData to retreive the diacritic characters
    if (!version || [version compare:@"1.5.4" options:NSCaseInsensitiveSearch|NSNumericSearch] == NSOrderedAscending)
      [equation reannotatePDFDataUsingPDFKeywords:NO];
  }//end if version < 2.0.0

  if (!equation)
  {
    [self release];
    return nil;
  }
  
  [self setEquation:equation];
  [equation release];
    
  return self;
}
//end initWithCoder:

@end
