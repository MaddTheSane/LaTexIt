//
//  LibraryEquation.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 16/03/09.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import "LibraryEquation.h"

#import "HistoryItem.h"
#import "LatexitEquation.h"
#import "LatexitEquationWrapper.h"
#import "LaTeXProcessor.h"
#import "LibraryManager.h"
#import "NSManagedObjectContextExtended.h"
#import "Utils.h"

@implementation LibraryEquation

static NSEntityDescription* cachedEntity = nil;
static NSEntityDescription* cachedWrapperEntity = nil;

+(NSEntityDescription*) entity
{
  if (!cachedEntity)
  {
    @synchronized(self)
    {
      #ifdef ARC_ENABLED
      if (!cachedEntity)
        cachedEntity = [[[[LaTeXProcessor sharedLaTeXProcessor] managedObjectModel] entitiesByName] objectForKey:NSStringFromClass([self class])];
      #else
      if (!cachedEntity)
        cachedEntity = [[[[[LaTeXProcessor sharedLaTeXProcessor] managedObjectModel] entitiesByName] objectForKey:NSStringFromClass([self class])] retain];
      #endif
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
          objectForKey:@"LibraryEquationWrapper"] retain];
    }//end @synchronized(self)
  }//end if (!cachedWrapperEntity)
  return cachedWrapperEntity;
}
//end wrapperEntity

+(BOOL) supportsSecureCoding {return YES;}

-(id) initWithParent:(LibraryItem*)aParent equation:(LatexitEquation*)equation insertIntoManagedObjectContext:(NSManagedObjectContext*)managedObjectContext
{
  if (!((self = [super initWithParent:aParent insertIntoManagedObjectContext:managedObjectContext])))
    return nil;
  [self setEquation:equation];
  [super setTitle:[equation title]];
  return self;
}
//end initWithParent:equation:insertIntoManagedObjectContext:

-(void) dealloc
{
  [self dispose];
  //in didTurnInToFault, a problem occurs with undo, that does not call any awakeFrom... to reactivate the observer
  [super dealloc];
}
//end dealloc

-(id) copyWithZone:(NSZone*)zone
{
  id clone = [super copyWithZone:zone];
  id clonedEquation = [[self equation] copy];
  [clone setEquation:clonedEquation];
  [clonedEquation release];
  return clone;
}
//end copyWithZone:

-(void) dispose
{
  [self setCustomKVOEnabled:NO];
  [super dispose];
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
  LatexitEquationWrapper* equationWrapper = [self valueForKey:@"equationWrapper"];
  [[self managedObjectContext] safeInsertObject:equationWrapper];
  NSManagedObject* equation = [equationWrapper valueForKey:@"equation"];
  [[self managedObjectContext] safeInsertObject:equation];
}
//end awakeFromInsert


-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  if ([keyPath isEqualToString:@"equationWrapper.equation.backgroundColor"])
  {
    NSManagedObjectContext* managedObjectContext = [self managedObjectContext];
    if (managedObjectContext)
      [managedObjectContext disableUndoRegistration];
    [self willChangeValueForKey:@"dummyPropertyToForceUIRefresh"];
    [self didChangeValueForKey:@"dummyPropertyToForceUIRefresh"];
    if (managedObjectContext)
      [managedObjectContext enableUndoRegistration];
  }//end if ([keyPath isEqualToString:@"equationWrapper.equation.backgroundColor"])
  else if ([keyPath isEqualToString:@"equationWrapper.equation.pdfData"])
  {
    NSManagedObjectContext* managedObjectContext = [self managedObjectContext];
    if (managedObjectContext)
      [managedObjectContext disableUndoRegistration];
    [[self equation] resetPdfCachedImage];
    [self willChangeValueForKey:@"dummyPropertyToForceUIRefresh"];
    [self didChangeValueForKey:@"dummyPropertyToForceUIRefresh"];
    if (managedObjectContext)
      [managedObjectContext enableUndoRegistration];
  }//end if ([keyPath isEqualToString:@"equationWrapper.equation.pdfData"])
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
        {
          [self removeObserver:self forKeyPath:@"equationWrapper.equation.backgroundColor"];
          [self removeObserver:self forKeyPath:@"equationWrapper.equation.pdfData"];
        }//end if (!value)
        else//if (value)
        {
          [self addObserver:self forKeyPath:@"equationWrapper.equation.backgroundColor" options:0 context:nil];
          [self addObserver:self forKeyPath:@"equationWrapper.equation.pdfData" options:0 context:nil];
        }//if (value)
        self->customKVOEnabled = value;
      }//end if (value != self->customKVOEnabled)
    }//end @synchronized(self)
  }//end if (value != self->customKVOEnabled)
}
//end setCustomKVOEnabled:

-(void) setTitle:(NSString*)value
{
  [super setTitle:value];
  [[self equation] setTitle:value];
}
//end setTitle:

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
      [equationWrapper willChangeValueForKey:@"libraryEquation"];
      [equationWrapper setPrimitiveValue:self forKey:@"libraryEquation"]; //if current managedObjectContext is nil, this is necessary
      [equationWrapper didChangeValueForKey:@"libraryEquation"];
      [self willChangeValueForKey:@"equationWrapper"];
      [self setPrimitiveValue:equationWrapper forKey:@"equationWrapper"];
      [self didChangeValueForKey:@"equationWrapper"];
      #ifdef ARC_ENABLED
      #else
      [equationWrapper release];
      #endif
    }//end if (!equationWrapper)
    else
      [[self managedObjectContext] safeInsertObject:equationWrapper];
    [equationWrapper setEquation:equation];
    [equation willChangeValueForKey:@"wrapper"];
    [equation setPrimitiveValue:equationWrapper forKey:@"wrapper"]; //if current managedObjectContext is nil, this is necessary
    [equation didChangeValueForKey:@"wrapper"];
  }//end if (equation != [self equation])
  
  /*[[self managedObjectContext] safeInsertObject:equation];
  LatexitEquation* oldEquation = [self equation];
  if (equation != oldEquation)
  {
    LatexitEquationWrapper* equationWrapper = [self valueForKey:@"equationWrapper"];
    if (equationWrapper)
      [[self managedObjectContext] safeInsertObject:equationWrapper];
    else
    {
      equationWrapper = [[LatexitEquationWrapper alloc] initWithEntity:[[self class] wrapperEntity]
                                 insertIntoManagedObjectContext:[self managedObjectContext]];
      [equationWrapper setValue:self forKey:@"libraryEquation"]; //if current managedObjectContext is nil, this is necessary
      [self setValue:equationWrapper forKey:@"equationWrapper"];
      [equationWrapper release];
    }//end if (!equationWrapper)
    [equationWrapper setEquation:equation];
    [equation setValue:equationWrapper forKey:@"wrapper"]; //if current managedObjectContext is nil, this is necessary
    [[self managedObjectContext] safeDeleteObject:oldEquation];
  }//end if (equation != oldEquation)*/
}
//end setEquation:

-(void) setEquation:(LatexitEquation*)equation setAutomaticTitle:(BOOL)setAutomaticTitle
{
  [self setEquation:equation];
  if (!setAutomaticTitle || ([equation title] && ![[equation title] isEqualToString:@""]))
    [self setTitle:[equation title]];
  else
  {
    NSString* string =
      [[[equation sourceText] string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSUInteger endIndex = MIN(17U, [string length]);
    [self setTitle:[string substringToIndex:endIndex]];
  }
}
//end setEquation:setAutomaticTitle:

-(void) setBestTitle//computes best title in current context
{
  NSString* equationTitle = [self title];
  LatexitEquation* equation = [(LibraryEquation*)self equation]; 
  equationTitle = [equation title];
  if (!equationTitle || [equationTitle isEqualToString:@""])
    equationTitle = [equation titleAuto];
  NSArray* brothers = [self brothersIncludingMe:NO];
  NSMutableArray* brothersTitles = [[NSMutableArray alloc] initWithCapacity:[brothers count]];
  NSEnumerator* enumerator = [brothers objectEnumerator];
  LibraryItem* brother = nil;
  while((brother = [enumerator nextObject]))
  {
    NSString* brotherTitle = [brother title];
    if (brotherTitle)
      [brothersTitles addObject:brotherTitle];
  }//end for each brother
  NSString* libraryEquationTitle = makeStringDifferent(equationTitle, brothersTitles, 0);
  if (!equationTitle)
    [self setTitle:libraryEquationTitle];//sets current and equation
  else
    [super setTitle:libraryEquationTitle];//sets only current item title, does not touch equation
  [brothersTitles release];
}
//end setBestTitle

-(void) encodeWithCoder:(NSCoder*)coder
{
  [super encodeWithCoder:coder];
  [coder encodeObject:[self equation] forKey:@"equation"];
}
//end encodeWithCoder:

-(id) initWithCoder:(NSCoder*)coder
{
  if (!((self = [super initWithCoder:coder])))
    return nil;
  if ([coder containsValueForKey:@"value"])//legacy
  {
    NSManagedObjectContext* managedObjectContext = [LatexitEquation currentManagedObjectContext];
    HistoryItem* historyItem = [coder decodeObjectForKey:@"value"];
    LatexitEquation* latexitEquation = [[historyItem equation] retain];
    [historyItem setEquation:nil];
    [managedObjectContext safeInsertObject:latexitEquation];
    [latexitEquation release];
    [self setEquation:latexitEquation];
    if (![self title])
      [self setBestTitle];
    [managedObjectContext safeDeleteObject:historyItem];
  }//end if ([coder containsValueForKey:@"value"])//legacy
  else
    [self setEquation:[coder decodeObjectForKey:@"equation"]];
  return self;
}
//end initWithCoder:

-(id) plistDescription
{
  NSMutableDictionary* plist = [super plistDescription];
    [plist addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
       [[self equation] plistDescription], @"equation",
       nil]];
  return plist;
}
//end plistDescription

-(id) initWithDescription:(id)description
{
  if (!((self = [super initWithDescription:description])))
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

@end
