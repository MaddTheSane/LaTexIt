//
//  BodyTemplatesController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 05/08/08.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import "BodyTemplatesController.h"

#import "DeepCopying.h"
#import "NSArrayExtended.h"
#import "NSArrayControllerExtended.h"
#import "NSDictionaryExtended.h"
#import "PreferencesController.h"
#import "Utils.h"

@implementation BodyTemplatesController

static NSDictionary* noneBodyTemplate = nil;

+(void) initialize
{
  [self exposeBinding:@"selection"];
  [self exposeBinding:@"arrangedObjectsNamesWithNone"];
  [self setKeys:[NSArray arrayWithObjects:@"arrangedObjects", nil] triggerChangeNotificationsForDependentKey:@"arrangedObjectsNamesWithNone"];
}
//end initialize

+(NSDictionary*) noneBodyTemplate
{
  NSDictionary* result = noneBodyTemplate;
  if (!result)
  {
    @synchronized(self)
    {
      if (!result)
      {
        noneBodyTemplate = [[NSDictionary alloc] initWithObjectsAndKeys:
           [NSMutableString stringWithString:NSLocalizedString(@"none", @"none")], @"name", nil];
        result = noneBodyTemplate;
      }//end if (!result)
    }//end @synchronized(self)
  }//end if (!result)
  return result;
}
//end noneBodyTemplate

+(NSMutableDictionary*) bodyTemplateDictionaryForEnvironment:(NSString*)environment
{
  NSMutableDictionary* result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
           [NSMutableString stringWithString:environment], @"name",
           [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\\begin{%@}", environment]] autorelease], @"head",
           [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\\end{%@}", environment]] autorelease], @"tail",
           nil];
  return result;
}
//end bodyTemplateDictionaryForEnvironment:

+(NSMutableDictionary*) bodyTemplateDictionaryEncodedForEnvironment:(NSString*)environment
{
  NSMutableDictionary* result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
           [NSMutableString stringWithString:environment], @"name",
           [NSKeyedArchiver archivedDataWithRootObject:
             [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\\begin{%@}", environment]] autorelease]],
           @"head",
           [NSKeyedArchiver archivedDataWithRootObject:
             [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\\end{%@}", environment]] autorelease]],
           @"tail",
           nil];
  return result;
}
//end bodyTemplateDictionaryEncodedForEnvironment:

+(NSMutableDictionary*) defaultLocalizedBodyTemplateDictionary
{
  #ifdef MIGRATE_ALIGN
  NSMutableDictionary* result = [self bodyTemplateDictionaryForEnvironment:@"eqnarray*"];
  #else
  NSMutableDictionary* result = [self bodyTemplateDictionaryForEnvironment:@"align*"];
  #endif
  return result;
}
//end defaultLocalizedBodyTemplateDictionary

+(NSMutableDictionary*) defaultLocalizedBodyTemplateDictionaryEncoded
{
  #ifdef MIGRATE_ALIGN
  NSMutableDictionary* result = [self bodyTemplateDictionaryEncodedForEnvironment:@"eqnarray*"];
  #else
  NSMutableDictionary* result = [self bodyTemplateDictionaryEncodedForEnvironment:@"align*"];
  #endif
  return result;
}
//end defaultLocalizedBodyTemplateDictionaryEncoded

-(id) initWithContent:(id)content
{
  if ((!(self = [super initWithContent:content])))
    return nil;
  [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:LatexisationSelectedBodyTemplateIndexKey options:NSKeyValueObservingOptionNew context:nil];
  [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:ServiceSelectedBodyTemplateIndexKey options:NSKeyValueObservingOptionNew context:nil];
  [self addObserver:self forKeyPath:@"arrangedObjects" options:0 context:nil];
  [self addObserver:self forKeyPath:@"arrangedObjects.name" options:0 context:nil];
  return self;
}
//end initWithContent:

-(void) dealloc
{
  [self removeObserver:self forKeyPath:@"arrangedObjects"];
  [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:LatexisationSelectedBodyTemplateIndexKey];
  [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:ServiceSelectedBodyTemplateIndexKey];
  [super dealloc];
}
//end dealloc

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  if ([keyPath isEqualToString:@"arrangedObjects"])
  {
    [self observeValueForKeyPath:LatexisationSelectedBodyTemplateIndexKey ofObject:nil change:nil context:nil];
    [self observeValueForKeyPath:ServiceSelectedBodyTemplateIndexKey ofObject:nil change:nil context:nil];
    [self willChangeValueForKey:@"arrangedObjectsNamesWithNone"];
    [self didChangeValueForKey:@"arrangedObjectsNamesWithNone"];
  }
  else if ([keyPath isEqualToString:@"arrangedObjects.name"])
  {
    [self willChangeValueForKey:@"arrangedObjectsNamesWithNone"];
    [self didChangeValueForKey:@"arrangedObjectsNamesWithNone"];
  }
  else if ([keyPath isEqualToString:LatexisationSelectedBodyTemplateIndexKey] ||
           [keyPath isEqualToString:ServiceSelectedBodyTemplateIndexKey])
  {
    int curIndex = !change ? [[NSUserDefaults standardUserDefaults] integerForKey:keyPath] : [[change objectForKey:NSKeyValueChangeNewKey] intValue];
    int newIndex = curIndex;
    int count = (signed)[[self arrangedObjects] count];
    if ((curIndex<0) && count)
      newIndex = -1;
    else if (curIndex>=count)
      newIndex = count-1;
    if (newIndex != curIndex)
      [[NSUserDefaults standardUserDefaults] setInteger:newIndex forKey:keyPath];
  }//end if ([keyPath isEqualToString:LatexisationSelectedBodyTemplateIndexKey] ||
   //        [keyPath isEqualToString:ServiceSelectedBodyTemplateIndexKey])
}
//end observeValueForKeyPath:ofObject:change:context:

-(id) arrangedObjectsNamesWithNone
{
  id result = [self valueForKeyPath:@"arrangedObjects.name"];
  if ([result isKindOfClass:[NSArray class]])
    result = [result arrayByAddingObject:[[[self class] noneBodyTemplate] objectForKey:@"name"] atIndex:0];
  return result;
}
//end arrangedObjectsNamesWithNone

-(BOOL) canRemove
{
  BOOL result = [super canRemove];
  return result;
}
//end canRemove:

-(id) newObject
{
  id result = nil;
  NSArray* objects = [self arrangedObjects];
  NSArray* selectedObjects = [self selectedObjects];
  id modelObject = (selectedObjects && [selectedObjects count]) ? [selectedObjects objectAtIndex:0] :
                   (objects && [objects count]) ? [objects objectAtIndex:0] : nil;
  if (!modelObject)
    result = [[[self class] defaultLocalizedBodyTemplateDictionaryEncoded] deepMutableCopy];
  else
  {
    result = [modelObject deepMutableCopy];
    [result setObject:[NSMutableString stringWithFormat:NSLocalizedString(@"Copy of %@", "Copy of %@"), [result objectForKey:@"name"]] forKey:@"name"];
  }
  return result;
}
//end newObject

-(void) add:(id)sender
{
  id newObject = [self newObject];
  [self addObject:newObject];
  [self setSelectedObjects:[NSArray arrayWithObjects:newObject, nil]];
}
//end add:

//redefined from NSArrayControllerExtended
-(void) moveObjectsAtIndices:(NSIndexSet*)indices toIndex:(unsigned int)index
{
  NSInteger bodyTemplateLaTeXisationIndex = [[NSUserDefaults standardUserDefaults] integerForKey:LatexisationSelectedBodyTemplateIndexKey];
  NSInteger bodyTemplateServiceIndex      = [[NSUserDefaults standardUserDefaults] integerForKey:ServiceSelectedBodyTemplateIndexKey];
  id bodyTemplateLaTeXisation = !IsBetween_i(1, bodyTemplateLaTeXisationIndex+1, [[self arrangedObjects] count]) ? nil :
    [[self arrangedObjects] objectAtIndex:bodyTemplateLaTeXisationIndex];
  id bodyTemplateService = !IsBetween_i(1, bodyTemplateServiceIndex+1, [[self arrangedObjects] count]) ? nil :
    [[self arrangedObjects] objectAtIndex:bodyTemplateServiceIndex];
  [super moveObjectsAtIndices:indices toIndex:index];
  NSUInteger newBodyTemplateLaTeXisationIndex = [[self arrangedObjects] indexOfObject:bodyTemplateLaTeXisation];
  NSUInteger newBodyTemplateServiceIndex      = [[self arrangedObjects] indexOfObject:bodyTemplateService];
  [[NSUserDefaults standardUserDefaults]
    setInteger:(newBodyTemplateLaTeXisationIndex == NSNotFound) ? -1 : (signed)newBodyTemplateLaTeXisationIndex
        forKey:LatexisationSelectedBodyTemplateIndexKey];
  [[NSUserDefaults standardUserDefaults]
    setInteger:(newBodyTemplateServiceIndex == NSNotFound) ? -1 : (signed)newBodyTemplateServiceIndex
        forKey:ServiceSelectedBodyTemplateIndexKey];
}
//end moveObjectsAtIndices:toIndex:

@end
