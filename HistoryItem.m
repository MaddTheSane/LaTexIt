//
//  HistoryItem.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/02/09.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.
//

#import "HistoryItem.h"

#import "LatexitEquation.h"
#import "LatexitEquationData.h"
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

-(id) initWithEntity:(NSEntityDescription*)entity insertIntoManagedObjectContext:(NSManagedObjectContext*)context
{
  if (!((self = [super initWithEntity:entity insertIntoManagedObjectContext:context])))
    return nil;
  self->isModelPrior250 = context &&
    ![[[[context persistentStoreCoordinator] managedObjectModel] entitiesByName]
      objectForKey:NSStringFromClass([LatexitEquationData class])];
  return self;
}
//end initWithEntity:insertIntoManagedObjectContext:

-(id) initWithEquation:(LatexitEquation*)equation insertIntoManagedObjectContext:(NSManagedObjectContext*)managedObjectContext
{
  if (!((self = [self initWithEntity:[[self class] entity] insertIntoManagedObjectContext:managedObjectContext])))
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
  [self setCustomKVOEnabled:NO];
}
//end dispose

-(void) willTurnIntoFault
{
  [self setCustomKVOEnabled:NO];
  [super willTurnIntoFault];
}
//end willTurnIntoFault

-(void) didTurnIntoFault
{
  [self setCustomKVOEnabled:NO];
  [super didTurnIntoFault];
}
//end didTurnIntoFault

-(void) awakeFromFetch
{
  [super awakeFromFetch];
  [self setCustomKVOEnabled:YES];
}
//end awakeFromFetch

-(void) awakeFromInsert
{
  [super awakeFromInsert];
  [self setCustomKVOEnabled:YES];
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
    NSUndoManager* undoManager = [managedObjectContext undoManager];
    if (undoManager)
      [managedObjectContext disableUndoRegistration];
    [self willChangeValueForKey:@"dummyPropertyToForceUIRefresh"];
    [self didChangeValueForKey:@"dummyPropertyToForceUIRefresh"];
    if (undoManager)
      [managedObjectContext enableUndoRegistration];
  }//end if ([keyPath isEqualToString:@"equationWrapper.equation.backgroundColor"])
}
//end observeValueForKeyPath:ofObject:change:context:

-(BOOL) customKVOInhibited
{
  return self->customKVOInhibited;
}
//end customKVOEnabled

-(void) setCustomKVOInhibited:(BOOL)value
{
  if (value != self->customKVOInhibited)
  {
    @synchronized(self)
    {
      if (value != self->customKVOInhibited)
      {
        self->customKVOInhibited = value;
        if (self->customKVOInhibited)
          [self setCustomKVOEnabled:NO];
      }//end if (value != self->customKVOEnabled)
    }//end @synchronized(self)
  }//end if (value != self->customKVOEnabled)
}
//end customKVOInhibited:

-(BOOL) customKVOEnabled
{
  return self->customKVOEnabled;
}
//end customKVOEnabled

-(void) setCustomKVOEnabled:(BOOL)value
{
  if (value != self->customKVOEnabled)
  {
    @synchronized(self)
    {
      value &= !self->customKVOInhibited;
      if (value != self->customKVOEnabled)
      {
        if (!value)
          [self removeObserver:self forKeyPath:@"equationWrapper.equation.backgroundColor"];
        else
          [self addObserver:self forKeyPath:@"equationWrapper.equation.backgroundColor" options:0 context:nil];
        self->customKVOEnabled = value;
      }//end if (value != self->customKVOEnabled)
    }//end @synchronized(self)
  }//end if (value != self->customKVOEnabled)
}
//end setCustomKVOEnabled:

-(NSDate*) date
{
  NSDate* result = nil;
  if (!self->isModelPrior250)
  {
    [self willAccessValueForKey:@"date"];
    result = [self primitiveValueForKey:@"date"];
    [self didAccessValueForKey:@"date"];
  }//end if (!self->isModelPrior250)
  return result;
} 
//end date

-(void) setDate:(NSDate*)value
{
  if (!self->isModelPrior250)
  {
    [self willChangeValueForKey:@"date"];
    [self setPrimitiveValue:value forKey:@"date"];
    [self didChangeValueForKey:@"date"];
  }//end if (!self->isModelPrior250)
  [[self equation] setDate:value];
}
//end setDate:

-(LatexitEquation*) equation
{
  LatexitEquation* result = nil;
  [self willAccessValueForKey:@"equationWrapper"];
  LatexitEquationWrapper* equationWrapper = [self primitiveValueForKey:@"equationWrapper"];
  [equationWrapper willAccessValueForKey:@"equation"];
  result = [equationWrapper equation];
  [equationWrapper didAccessValueForKey:@"equation"];
  [self didAccessValueForKey:@"equationWrapper"];
  return result;
}
//end equation

-(void) setEquation:(LatexitEquation*)equation
{
  if (equation != [self equation])
  {
    [[self managedObjectContext] safeInsertObject:equation];
    [self willAccessValueForKey:@"equationWrapper"];
    LatexitEquationWrapper* equationWrapper = [self primitiveValueForKey:@"equationWrapper"];
    [self didAccessValueForKey:@"equationWrapper"];
    if (!equationWrapper)
    {
      equationWrapper = [[LatexitEquationWrapper alloc]
        initWithEntity:[[self class] wrapperEntity] insertIntoManagedObjectContext:[self managedObjectContext]];
      [equationWrapper willChangeValueForKey:@"historyItem"];
      [equationWrapper setPrimitiveValue:self forKey:@"historyItem"]; //if current managedObjectContext is nil, this is necessary
      [equationWrapper didChangeValueForKey:@"historyItem"];
      [self willChangeValueForKey:@"equationWrapper"];
      [self setPrimitiveValue:equationWrapper forKey:@"equationWrapper"];
      [self didChangeValueForKey:@"equationWrapper"];
      [equationWrapper release];
    }//end if (!equationWrapper)
    else
      [[self managedObjectContext] safeInsertObject:equationWrapper];
    [equationWrapper setEquation:equation];
    [self setDate:[equation date]];
    [equation willChangeValueForKey:@"wrapper"];
    [equation setPrimitiveValue:equationWrapper forKey:@"wrapper"]; //if current managedObjectContext is nil, this is necessary
    [equation didChangeValueForKey:@"wrapper"];
  }//end if (equation != [self equation])
}
//end setEquation:

//to feed a pasteboard. It needs a document, because there may be some temporary files needed for certain kind of data
//the lazyDataProvider, if not nil, is the one who will call [pasteboard:provideDataForType] *as needed* (to save time)
-(void) writeToPasteboard:(NSPasteboard*)pboard exportFormat:(export_format_t)exportFormat isLinkBackRefresh:(BOOL)isLinkBackRefresh lazyDataProvider:(id)lazyDataProvider
{
  //first, feed with equation
  [[self equation] writeToPasteboard:pboard exportFormat:exportFormat isLinkBackRefresh:isLinkBackRefresh lazyDataProvider:lazyDataProvider];

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
       @"2.7.0", @"version",
       [[self equation] plistDescription], @"equation",
       nil];
  return plist;
}
//end plistDescription

-(id) initWithDescription:(id)description
{
  NSManagedObjectContext* managedObjectContext = [LatexitEquation currentManagedObjectContext];
  if (!((self = [self initWithEntity:[[self class] entity] insertIntoManagedObjectContext:managedObjectContext])))
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
  [coder encodeObject:@"2.7.0" forKey:@"version"];
  [coder encodeObject:[self equation] forKey:@"equation"];
}
//end encodeWithCoder:

#pragma mark legacy code
-(id) initWithCoder:(NSCoder*)coder
{
  NSString* version = [coder decodeObjectForKey:@"version"];
  NSManagedObjectContext* managedObjectContext = ([@"2.0.0" compare:version options:NSCaseInsensitiveSearch|NSNumericSearch] == NSOrderedDescending) ? nil :
    [LatexitEquation currentManagedObjectContext];
  if (!((self = [self initWithEntity:[[self class] entity] insertIntoManagedObjectContext:managedObjectContext])))
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
    latex_mode_t mode = LATEX_MODE_ALIGN;
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

    [backgroundColor release];
    [color release];
    [date release];
    [pdfData release];
    [preamble release];
    [sourceText release];

    [equation setTitle:title];
    [title release];

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
