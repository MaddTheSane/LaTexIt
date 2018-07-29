//
//  CompositionConfigurationsController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "CompositionConfigurationsController.h"

#import "CompositionConfigurationsAdditionalScriptsController.h"
#import "CompositionConfigurationsProgramArgumentsController.h"
#import "DeepCopying.h"
#import "DictionaryToArrayTransformer.h"
#import "MutableTransformer.h"
#import "NSArrayControllerExtended.h"
#import "NSDictionaryExtended.h"
#import "PreferencesController.h"
#import "Utils.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation CompositionConfigurationsController

+(void) initialize
{
  [self exposeBinding:@"selection"];
}
//end initialize

+(NSMutableDictionary*) defaultCompositionConfigurationDictionary
{
  NSMutableDictionary* result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
           [NSMutableString stringWithString:NSLocalizedString(@"default", @"default")], CompositionConfigurationNameKey,
           @YES, CompositionConfigurationIsDefaultKey,
           @(COMPOSITION_MODE_PDFLATEX), CompositionConfigurationCompositionModeKey,
           @YES, CompositionConfigurationUseLoginShellKey,
           @{}, CompositionConfigurationProgramArgumentsKey,
           @{@(SCRIPT_PLACE_PREPROCESSING).stringValue: @{CompositionConfigurationAdditionalProcessingScriptEnabledKey: @NO,
               CompositionConfigurationAdditionalProcessingScriptTypeKey: @(SCRIPT_SOURCE_STRING),
               CompositionConfigurationAdditionalProcessingScriptPathKey: @"",
               CompositionConfigurationAdditionalProcessingScriptShellKey: @"/bin/sh",
               CompositionConfigurationAdditionalProcessingScriptContentKey: @""},
             @(SCRIPT_PLACE_MIDDLEPROCESSING).stringValue: @{CompositionConfigurationAdditionalProcessingScriptEnabledKey: @NO,
               CompositionConfigurationAdditionalProcessingScriptTypeKey: @(SCRIPT_SOURCE_STRING),
               CompositionConfigurationAdditionalProcessingScriptPathKey: @"",
               CompositionConfigurationAdditionalProcessingScriptShellKey: @"/bin/sh",
               CompositionConfigurationAdditionalProcessingScriptContentKey: @""},
             @(SCRIPT_PLACE_POSTPROCESSING).stringValue: @{CompositionConfigurationAdditionalProcessingScriptEnabledKey: @NO,
               CompositionConfigurationAdditionalProcessingScriptTypeKey: @(SCRIPT_SOURCE_STRING),
               CompositionConfigurationAdditionalProcessingScriptPathKey: @"",
               CompositionConfigurationAdditionalProcessingScriptShellKey: @"/bin/sh",
               CompositionConfigurationAdditionalProcessingScriptContentKey: @""}}, CompositionConfigurationAdditionalProcessingScriptsKey,
           nil];
  return result;
}
//end defaultLocalizedPreambleDictionary

-(instancetype) initWithContent:(id)content
{
  if ((!(self = [super initWithContent:content])))
    return nil;
  [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:CompositionConfigurationDocumentIndexKey options:NSKeyValueObservingOptionNew context:nil];
  return self;
}
//end initWithContent:

-(void) dealloc
{
  [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:CompositionConfigurationDocumentIndexKey];
}
//end dealloc

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  if ([keyPath isEqualToString:@"arrangedObjects"])
    [self observeValueForKeyPath:CompositionConfigurationDocumentIndexKey ofObject:nil change:nil context:nil];
  else if ([keyPath isEqualToString:CompositionConfigurationDocumentIndexKey])
  {
    NSInteger curIndex = !change ? [[NSUserDefaults standardUserDefaults] integerForKey:keyPath] : [change[NSKeyValueChangeNewKey] intValue];
    NSInteger newIndex = curIndex;
    NSInteger count = (NSInteger)[self.arrangedObjects count];
    if ((curIndex<0) && count)
      newIndex = 0;
    else if (curIndex>=count)
      newIndex = count-1;
    if (newIndex != curIndex)
    {
      [[NSUserDefaults standardUserDefaults] setInteger:newIndex forKey:keyPath];
      [self setSelectionIndex:newIndex];
    }//end if (newIndex != curIndex)
  }//end if ([keyPath isEqualToString:LatexisationSelectedPreambleIndexKey])
}
//end observeValueForKeyPath:ofObject:change:context:

-(void) ensureDefaultCompositionConfiguration
{
  if (![self.arrangedObjects count])
    [self addObject:[[self class] defaultCompositionConfigurationDictionary]];
}
//end ensureDefaultPreamble

-(BOOL) canRemove
{
  BOOL result = super.canRemove && ([self.arrangedObjects count] > 1) &&//at least one preamble !
                ![[self.selection valueForKey:CompositionConfigurationIsDefaultKey] boolValue];
  return result;
}
//end canRemove:

-(id) newObject
{
  id result = nil;
  NSArray* objects = self.arrangedObjects;
  NSArray* selectedObjects = self.selectedObjects;
  id modelObject = (selectedObjects && selectedObjects.count) ? selectedObjects[0] :
                   (objects && objects.count) ? objects[0] : nil;
  if (!modelObject)
    result = [[[self class] defaultCompositionConfigurationDictionary] deepMutableCopy];
  else
  {
    result = [modelObject deepMutableCopy];
    result[CompositionConfigurationNameKey] = [NSMutableString stringWithFormat:NSLocalizedString(@"Copy of %@", "Copy of %@"), result[CompositionConfigurationNameKey]];
    result[CompositionConfigurationIsDefaultKey] = @NO;
  }
  return result;
}
//end newObject

-(void) add:(id)sender
{
  id newObject = [self newObject];
  [self addObject:newObject];
  [self setSelectedObjects:@[newObject]];
}
//end add:

-(CompositionConfigurationsAdditionalScriptsController*) currentConfigurationScriptsController
{
  if (!self->currentConfigurationScriptsController)
  {
    self->currentConfigurationScriptsController =
      [[CompositionConfigurationsAdditionalScriptsController alloc] initWithContent:nil];
    [self->currentConfigurationScriptsController setAvoidsEmptySelection:NO];
    [self->currentConfigurationScriptsController setAutomaticallyPreparesContent:YES];
    [self->currentConfigurationScriptsController setPreservesSelection:YES];
    [self->currentConfigurationScriptsController bind:NSContentArrayBinding toObject:self
      withKeyPath:[NSString stringWithFormat:@"selection.%@", CompositionConfigurationAdditionalProcessingScriptsKey]
      options:@{NSValueTransformerBindingOption: [DictionaryToArrayTransformer transformerWithDescriptors:nil],
        NSHandlesContentAsCompoundValueBindingOption: @YES}];
  }//end if (!self->currentConfigurationScriptsController)
  return self->currentConfigurationScriptsController;
}
//end currentConfigurationScriptsController

-(CompositionConfigurationsProgramArgumentsController*)  currentConfigurationProgramArgumentsPdfLaTeXController
{return [self currentConfigurationProgramArgumentsControllerForKey:CompositionConfigurationPdfLatexPathKey];}
-(CompositionConfigurationsProgramArgumentsController*)  currentConfigurationProgramArgumentsXeLaTeXController
{return [self currentConfigurationProgramArgumentsControllerForKey:CompositionConfigurationXeLatexPathKey];}
-(CompositionConfigurationsProgramArgumentsController*)  currentConfigurationProgramArgumentsLuaLaTeXController
{return [self currentConfigurationProgramArgumentsControllerForKey:CompositionConfigurationLuaLatexPathKey];}
-(CompositionConfigurationsProgramArgumentsController*)  currentConfigurationProgramArgumentsLaTeXController
{return [self currentConfigurationProgramArgumentsControllerForKey:CompositionConfigurationLatexPathKey];}
-(CompositionConfigurationsProgramArgumentsController*)  currentConfigurationProgramArgumentsDviPdfController
{return [self currentConfigurationProgramArgumentsControllerForKey:CompositionConfigurationDviPdfPathKey];}
-(CompositionConfigurationsProgramArgumentsController*)  currentConfigurationProgramArgumentsGsController
{return [self currentConfigurationProgramArgumentsControllerForKey:CompositionConfigurationGsPathKey];}
-(CompositionConfigurationsProgramArgumentsController*)  currentConfigurationProgramArgumentsPsToPdfController
{return [self currentConfigurationProgramArgumentsControllerForKey:CompositionConfigurationPsToPdfPathKey];}

-(NSArray*)  currentConfigurationProgramArgumentsPdfLaTeX
{return [self currentConfigurationProgramArgumentsForKey:CompositionConfigurationPdfLatexPathKey];}
-(NSArray*)  currentConfigurationProgramArgumentsXeLaTeX
{return [self currentConfigurationProgramArgumentsForKey:CompositionConfigurationXeLatexPathKey];}
-(NSArray*)  currentConfigurationProgramArgumentsLuaLaTeX
{return [self currentConfigurationProgramArgumentsForKey:CompositionConfigurationLuaLatexPathKey];}
-(NSArray*)  currentConfigurationProgramArgumentsLaTeX
{return [self currentConfigurationProgramArgumentsForKey:CompositionConfigurationLatexPathKey];}
-(NSArray*)  currentConfigurationProgramArgumentsDviPdf
{return [self currentConfigurationProgramArgumentsForKey:CompositionConfigurationDviPdfPathKey];}
-(NSArray*)  currentConfigurationProgramArgumentsGs
{return [self currentConfigurationProgramArgumentsForKey:CompositionConfigurationGsPathKey];}
-(NSArray*)  currentConfigurationProgramArgumentsPsToPdf
{return [self currentConfigurationProgramArgumentsForKey:CompositionConfigurationPsToPdfPathKey];}

-(CompositionConfigurationsProgramArgumentsController*)  currentConfigurationProgramArgumentsControllerForKey:(NSString*)key
{
  CompositionConfigurationsProgramArgumentsController* result = nil;
  if (!self->currentConfigurationProgramArgumentsControllerDictionary)
    self->currentConfigurationProgramArgumentsControllerDictionary = [[NSMutableDictionary alloc] initWithCapacity:6];
  result = !key ? nil : self->currentConfigurationProgramArgumentsControllerDictionary[key];
  if (!result && key)
  {
    CompositionConfigurationsProgramArgumentsController* controller = [[CompositionConfigurationsProgramArgumentsController alloc] initWithContent:nil];
    NSMutableDictionary* programArgumentsDictionary =
      [self valueForKeyPath:[NSString stringWithFormat:@"selection.%@", CompositionConfigurationProgramArgumentsKey]];
    NSArray* programArguments = programArgumentsDictionary[key];
    if (!programArguments)
    {
      if (!programArgumentsDictionary)
        programArgumentsDictionary = [NSMutableDictionary dictionaryWithObject:[NSMutableArray array] forKey:key];
      else
        programArgumentsDictionary[key] = [NSMutableArray array];
      [self setValue:programArgumentsDictionary forKeyPath:[NSString stringWithFormat:@"selection.%@", CompositionConfigurationProgramArgumentsKey]];
    }//end if (!programArguments)
    controller.objectClass = [NSMutableString class];
    [controller setAvoidsEmptySelection:NO];
    [controller setAutomaticallyPreparesContent:YES];
    [controller setPreservesSelection:YES];
    [controller bind:NSContentArrayBinding toObject:self
      withKeyPath:[NSString stringWithFormat:@"selection.%@.%@", CompositionConfigurationProgramArgumentsKey, key]
      options:@{NSValueTransformerNameBindingOption: [MutableTransformer name],
        NSHandlesContentAsCompoundValueBindingOption: @YES}];
    result = controller;
    self->currentConfigurationProgramArgumentsControllerDictionary[key] = result;
  }//end if (!result)
  return result;
}
//end currentConfigurationProgramArgumentsControllerForKey:

-(NSArray*) currentConfigurationProgramArgumentsForKey:(NSString*)key
{
  NSArray* result = !key ? nil : [self valueForKeyPath:[NSString stringWithFormat:@"selection.%@.%@", CompositionConfigurationProgramArgumentsKey, key]];
  if (!result)
    result = @[];
  return result;
}
//end currentConfigurationProgramArgumentsControllerForKey:

//redefined from NSArrayControllerExtended
-(void) moveObjectsAtIndices:(NSIndexSet*)indices toIndex:(NSUInteger)index
{
  NSInteger preambleLaTeXisationIndex = [[NSUserDefaults standardUserDefaults] integerForKey:LatexisationSelectedPreambleIndexKey];
  NSInteger preambleServiceIndex      = [[NSUserDefaults standardUserDefaults] integerForKey:ServiceSelectedPreambleIndexKey];
  id preambleLaTeXisation = !IsBetween_N(1, preambleLaTeXisationIndex+1, [[self arrangedObjects] count]) ? nil :
    self.arrangedObjects[preambleLaTeXisationIndex];
  id preambleService = !IsBetween_N(1, preambleServiceIndex+1, [[self arrangedObjects] count]) ? nil :
    self.arrangedObjects[preambleServiceIndex];
  [super moveObjectsAtIndices:indices toIndex:index];
  NSUInteger newPreambleLaTeXisationIndex = [self.arrangedObjects indexOfObject:preambleLaTeXisation];
  NSUInteger newPreambleServiceIndex      = [self.arrangedObjects indexOfObject:preambleService];
  [[NSUserDefaults standardUserDefaults] setInteger:(newPreambleLaTeXisationIndex == NSNotFound) ? -1 : (signed)newPreambleLaTeXisationIndex
                                             forKey:LatexisationSelectedPreambleIndexKey];
  [[NSUserDefaults standardUserDefaults] setInteger:(newPreambleServiceIndex == NSNotFound) ? -1 : (signed)newPreambleServiceIndex
                                             forKey:ServiceSelectedPreambleIndexKey];
}
//end moveObjectsAtIndices:toIndex:

@end
