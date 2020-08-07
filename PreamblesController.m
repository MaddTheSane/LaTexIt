//
//  PreamblesController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 05/08/08.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "PreamblesController.h"

#import "DeepCopying.h"
#import "NSArrayControllerExtended.h"
#import "NSDictionaryExtended.h"
#import "PreferencesController.h"
#import "Utils.h"

@implementation PreamblesController

static NSAttributedString* defaultLocalizedPreambleValueAttributedString = nil;

+(void) initialize
{
  [self exposeBinding:@"selection"];
}
//end initialize

+(NSAttributedString*) defaultLocalizedPreambleValueAttributedString
{
  NSAttributedString* result = defaultLocalizedPreambleValueAttributedString;
  if (!result)
  {
    @synchronized(self)
    {
      if (!result)
      {
        NSString* path = [[NSBundle bundleForClass:[self class]] pathForResource:@"defaultPreamble" ofType:@"rtf"];
        defaultLocalizedPreambleValueAttributedString = !path ? nil : [[NSAttributedString alloc] initWithPath:path documentAttributes:nil];
        result = defaultLocalizedPreambleValueAttributedString;
      }//end if (!result)
    }//end @synchronized(self)
  }//end if (!result)
  return result;
}
//end defaultLocalizedPreambleValueAttributedString

+(NSMutableDictionary*) defaultLocalizedPreambleDictionary
{
  NSMutableDictionary* result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
           [NSMutableString stringWithString:NSLocalizedString(@"default", @"")], @"name",
           [self defaultLocalizedPreambleValueAttributedString], @"value", nil];
  return result;
}
//end defaultLocalizedPreambleDictionary

+(NSMutableDictionary*) defaultLocalizedPreambleDictionaryEncoded
{
  NSMutableDictionary* result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
           [NSMutableString stringWithString:NSLocalizedString(@"default", @"")], @"name",
           [NSKeyedArchiver archivedDataWithRootObject:[self defaultLocalizedPreambleValueAttributedString]], @"value", nil];
  return result;
}
//end defaultLocalizedPreambleDictionaryEncoded

-(id) initWithContent:(id)content
{
  if ((!(self = [super initWithContent:content])))
    return nil;
  [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:LatexisationSelectedPreambleIndexKey options:NSKeyValueObservingOptionNew context:nil];
  [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:ServiceSelectedPreambleIndexKey options:NSKeyValueObservingOptionNew context:nil];
  [self addObserver:self forKeyPath:@"arrangedObjects" options:0 context:nil];
  return self;
}
//end initWithContent:

-(void) dealloc
{
  [self removeObserver:self forKeyPath:@"arrangedObjects"];
  [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:LatexisationSelectedPreambleIndexKey];
  [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:ServiceSelectedPreambleIndexKey];
  #ifdef ARC_ENABLED
  #else
  [super dealloc];
  #endif
}
//end dealloc

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  if ([keyPath isEqualToString:@"arrangedObjects"])
  {
    [self observeValueForKeyPath:LatexisationSelectedPreambleIndexKey ofObject:nil change:nil context:nil];
    [self observeValueForKeyPath:ServiceSelectedPreambleIndexKey ofObject:nil change:nil context:nil];
  }
  else if ([keyPath isEqualToString:LatexisationSelectedPreambleIndexKey] ||
           [keyPath isEqualToString:ServiceSelectedPreambleIndexKey])
  {
    NSInteger curIndex = !change ? [[NSUserDefaults standardUserDefaults] integerForKey:keyPath] : [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
    NSInteger newIndex = curIndex;
    NSInteger count = (signed)[[self arrangedObjects] count];
    if ((curIndex<0) && count)
      newIndex = 0;
    else if (curIndex>=count)
      newIndex = count-1;
    if (newIndex != curIndex)
      [[NSUserDefaults standardUserDefaults] setInteger:newIndex forKey:keyPath];
  }//end if ([keyPath isEqualToString:LatexisationSelectedPreambleIndexKey] ||
   //        [keyPath isEqualToString:ServiceSelectedPreambleIndexKey])
}
//end observeValueForKeyPath:ofObject:change:context:

-(void) ensureDefaultPreamble
{
  #ifdef ARC_ENABLED
  if (![[self arrangedObjects] count])
    [self addObject:[[[self class] defaultLocalizedPreambleDictionaryEncoded] deepMutableCopy]];
  #else
  if (![[self arrangedObjects] count])
    [self addObject:[[[[self class] defaultLocalizedPreambleDictionaryEncoded] deepMutableCopy] autorelease]];
  #endif
}
//end ensureDefaultPreamble

-(BOOL) canRemove
{
  BOOL result = [super canRemove] && ([[self arrangedObjects] count] > 1);//at least one preamble !
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
    result = [[[self class] defaultLocalizedPreambleDictionary] deepMutableCopy];
  else
  {
    result = [modelObject deepMutableCopy];
    [result setObject:[NSMutableString stringWithFormat:NSLocalizedString(@"Copy of %@", @""), [result objectForKey:@"name"]] forKey:@"name"];
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
-(void) moveObjectsAtIndices:(NSIndexSet*)indices toIndex:(NSUInteger)index
{
  NSInteger preambleLaTeXisationIndex = [[NSUserDefaults standardUserDefaults] integerForKey:LatexisationSelectedPreambleIndexKey];
  NSInteger preambleServiceIndex      = [[NSUserDefaults standardUserDefaults] integerForKey:ServiceSelectedPreambleIndexKey];
  id preambleLaTeXisation = !IsBetween_nsui(1U, (unsigned)preambleLaTeXisationIndex+1, [[self arrangedObjects] count]) ? nil :
    [[self arrangedObjects] objectAtIndex:preambleLaTeXisationIndex];
  id preambleService = !IsBetween_nsi(1, preambleServiceIndex+1, [[self arrangedObjects] count]) ? nil :
    [[self arrangedObjects] objectAtIndex:preambleServiceIndex];
  [super moveObjectsAtIndices:indices toIndex:index];
  NSUInteger newPreambleLaTeXisationIndex = [[self arrangedObjects] indexOfObject:preambleLaTeXisation];
  NSUInteger newPreambleServiceIndex      = [[self arrangedObjects] indexOfObject:preambleService];
  [[NSUserDefaults standardUserDefaults]
    setInteger:(newPreambleLaTeXisationIndex == NSNotFound) ? -1 : (signed)newPreambleLaTeXisationIndex
        forKey:LatexisationSelectedPreambleIndexKey];
  [[NSUserDefaults standardUserDefaults]
    setInteger:(newPreambleServiceIndex == NSNotFound) ? -1 : (signed)newPreambleServiceIndex
        forKey:ServiceSelectedPreambleIndexKey];
}
//end moveObjectsAtIndices:toIndex:

@end
