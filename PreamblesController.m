//
//  PreamblesController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 05/08/08.
//  Copyright 2008 LAIC. All rights reserved.
//

#import "PreamblesController.h"

#import "DeepCopying.h"


@implementation PreamblesController

static NSAttributedString* defaultLocalizedPreamble = nil;

+(void) initialize
{
  @synchronized(self)
  {
    if (!defaultLocalizedPreamble)
    {
      NSString* path = [[NSBundle mainBundle] pathForResource:@"defaultPreamble" ofType:@"rtf"];
      if (path)
        defaultLocalizedPreamble = [[NSAttributedString alloc] initWithPath:path documentAttributes:nil];
    }
  }//end @synchronized
}
//end initialize

+(id) defaultLocalizedPreambleDictionary
{
  return [NSMutableDictionary dictionaryWithObjectsAndKeys:
           [NSMutableString stringWithString:NSLocalizedString(@"default", @"default")], @"name",
           [[defaultLocalizedPreamble mutableCopy] autorelease], @"value", nil];
}
//end defaultLocalizedPreambleDictionary

+(id) encodePreamble:(NSDictionary*)preambleDictionary
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
    [[[preambleDictionary objectForKey:@"name"] copy] autorelease], @"name",
    [NSKeyedArchiver archivedDataWithRootObject:[preambleDictionary objectForKey:@"value"]], @"value", nil];
}
//end encodePreamble:

+(id) decodePreamble:(NSDictionary*)preambleAsPlist
{
  return [NSMutableDictionary dictionaryWithObjectsAndKeys:
    [NSMutableString stringWithString:[preambleAsPlist objectForKey:@"name"]], @"name",
    [[[NSKeyedUnarchiver unarchiveObjectWithData:[preambleAsPlist objectForKey:@"value"]] mutableCopy] autorelease], @"value", nil];
}
//end decodePreamble:

-(BOOL) canRemove
{
  return [super canRemove] && ([[self arrangedObjects] count] > 1);
}
//end canRemove:

-(void) insertObject:(id)object atArrangedObjectIndex:(unsigned int)index
{
  [super insertObject:object atArrangedObjectIndex:(index+1 <= [[self arrangedObjects] count]) ? index+1 : index];
}

-(id) newObject
{
  id result = nil;
  NSArray* objects = [self arrangedObjects];
  NSArray* selectedObjects = [self selectedObjects];
  id modelObject = (selectedObjects && [selectedObjects count]) ? [selectedObjects objectAtIndex:0] :
                   (objects && [objects count]) ? [objects objectAtIndex:0] : nil;
  if (!modelObject)
    result = [[PreamblesController defaultLocalizedPreambleDictionary] deepMutableCopy];
  else
  {
    result = [modelObject deepMutableCopy];
    [result setObject:[NSMutableString stringWithFormat:NSLocalizedString(@"Copy of %@", "Copy of %@"), [result objectForKey:@"name"]] forKey:@"name"];
  }
  return result;
}
//end newObject

@end
