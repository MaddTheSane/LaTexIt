//
//  LibraryEquation.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 16/03/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import "LibraryEquation.h"

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
      if (!cachedEntity)
        cachedEntity = [[[[[LaTeXProcessor sharedLaTeXProcessor] managedObjectModel] entitiesByName]
          objectForKey:NSStringFromClass([self class])] retain];
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
  //in didTurnInToFault, a problem occurs with undo, that does not call any awakeFrom... to reactivate the observer
  [self removeObserver:self forKeyPath:@"equationWrapper.equation.backgroundColor"];
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

-(void) didTurnIntoFault
{
  [super didTurnIntoFault];
}
//end didTurnIntoFault

-(void) awakeFromFetch
{
  [super awakeFromFetch];
  [self addObserver:self forKeyPath:@"equationWrapper.equation.backgroundColor" options:0 context:nil];
}
//end awakeFromFetch

-(void) awakeFromInsert
{
  [super awakeFromInsert];
  [self addObserver:self forKeyPath:@"equationWrapper.equation.backgroundColor" options:0 context:nil];
  LatexitEquationWrapper* equationWrapper = [self valueForKey:@"equationWrapper"];
  [[self managedObjectContext] safeInsertObject:equationWrapper];
  LatexitEquation* equation = [equationWrapper equation];
  [[self managedObjectContext] safeInsertObject:equation];
}
//end awakeFromInsert

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

-(void) setTitle:(NSString*)value
{
  [super setTitle:value];
  [[self equation] setTitle:value];
}
//end setTitle:

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
  [[self managedObjectContext] safeInsertObject:equation];
  if (equation != [self equation])
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
  }//end if (equation != [self equation])
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
    unsigned int endIndex = MIN(17U, [string length]);
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