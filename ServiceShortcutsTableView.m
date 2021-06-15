//
//  ServiceShortcutsTableView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/12/05.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.


//The ServiceShortcutsTableView is the class used to display the application service shortcut preferences.
//It has been sub-classed to tune a little the behaviour

#import "ServiceShortcutsTableView.h"

#import "PreferencesController.h"

extern NSString *NSMenuDidBeginTrackingNotification;

@interface ServiceShortcutsTableView (PrivateAPI)
@end

@implementation ServiceShortcutsTableView

-(id) initWithCoder:(NSCoder*)coder
{
  if ((!(self = [super initWithCoder:coder])))
    return nil;
  return self;
}
//end initWithCoder:

-(void) dealloc
{
  NSArrayController* serviceShortcutsController = [[PreferencesController sharedController] serviceShortcutsController];
  [serviceShortcutsController removeObserver:self forKeyPath:[NSString stringWithFormat:@"arrangedObjects.%@", ServiceShortcutEnabledKey]];
  [serviceShortcutsController removeObserver:self forKeyPath:[NSString stringWithFormat:@"arrangedObjects.%@", ServiceShortcutStringKey]];
  [super dealloc];
}
//end dealloc

-(void) awakeFromNib
{
  [self->serviceWarningShortcutConflictButton setHidden:YES];
  [self setDelegate:(id)self];
  NSArrayController* serviceShortcutsController = [[PreferencesController sharedController] serviceShortcutsController];
  [serviceShortcutsController addObserver:self forKeyPath:[NSString stringWithFormat:@"arrangedObjects.%@", ServiceShortcutEnabledKey] options:0 context:0];
  [serviceShortcutsController addObserver:self forKeyPath:[NSString stringWithFormat:@"arrangedObjects.%@", ServiceShortcutStringKey]  options:0 context:0];
  [[self tableColumnWithIdentifier:@"enabled"] bind:NSValueBinding toObject:serviceShortcutsController
      withKeyPath:[NSString stringWithFormat:@"arrangedObjects.%@", ServiceShortcutEnabledKey]
      options:nil];
  [[self tableColumnWithIdentifier:@"description"] bind:NSValueBinding toObject:serviceShortcutsController
      withKeyPath:[NSString stringWithFormat:@"arrangedObjects.@self"]
          options:[NSDictionary dictionaryWithObjectsAndKeys:
            [DelegatingTransformer transformerWithDelegate:self context:@"description"], NSValueTransformerBindingOption, nil]];
  [[self tableColumnWithIdentifier:@"string"] bind:NSValueBinding toObject:serviceShortcutsController
      withKeyPath:[NSString stringWithFormat:@"arrangedObjects.%@", ServiceShortcutStringKey]
          options:[NSDictionary dictionaryWithObjectsAndKeys:
            [DelegatingTransformer transformerWithDelegate:self context:@"string"], NSValueTransformerBindingOption,
            NSLocalizedString(@"none", @""), NSNullPlaceholderBindingOption,
             nil]];
  [[self tableColumnWithIdentifier:@"warning"] bind:NSValueBinding toObject:serviceShortcutsController
      withKeyPath:[NSString stringWithFormat:@"arrangedObjects.@self"]
          options:[NSDictionary dictionaryWithObjectsAndKeys:
            [DelegatingTransformer transformerWithDelegate:self context:@"warning"], NSValueTransformerBindingOption, nil]];
}
//end awakeFromNib

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  [self performSelector:@selector(reloadData) withObject:nil afterDelay:0.];//refresh conflicts indicator
  [[PreferencesController sharedController]
    changeServiceShortcutsWithDiscrepancyFallback:CHANGE_SERVICE_SHORTCUTS_FALLBACK_APPLY_USERDEFAULTS
                           authenticationFallback:CHANGE_SERVICE_SHORTCUTS_FALLBACK_ASK];
}
//end observeValueForKeyPath:ofObject:change:context:

-(id) transformer:(DelegatingTransformer*)transformer reverse:(BOOL)reverse value:(id)value context:(id)context
{
  id result = nil;
  if (!reverse)
  {
    if ([context isEqual:@"description"])
    {
      NSString* serviceIdentifier = [[PreferencesController sharedController]
        serviceDescriptionForIdentifier:(service_identifier_t)[[value objectForKey:ServiceShortcutIdentifierKey] integerValue]];
      result = NSLocalizedString(serviceIdentifier, @"");
    }
    else if ([context isEqual:@"string"])  
    {//add shift+command in front of the upper-case, one-character-shortcut
      NSString* normalShortcut = [[value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
      const unichar firstCharacter = [normalShortcut isEqualToString:@""] ? '\0' : [normalShortcut characterAtIndex:0];
      const unichar shift = 0x21e7;
      const unichar command = 0x2318;
      const unichar tab[] = {shift, command, firstCharacter};
      NSInteger begin = [[NSCharacterSet letterCharacterSet] characterIsMember:firstCharacter] ? 0 : 1;
      NSString* displayShortcut = firstCharacter ? [NSString stringWithCharacters:tab+begin length:3-begin] : @"";
      result = displayShortcut;
    }//end if ([context isEqualToString:@"string"])
    else if ([context isEqual:@"warning"])
    {
      NSArray* serviceShortcuts = [[PreferencesController sharedController] serviceShortcuts];
      NSString* valueShortcutString = [[value objectForKey:ServiceShortcutStringKey] uppercaseString];
      BOOL valueHasShortcut = valueShortcutString && ![valueShortcutString isEqualToString:@""];
      BOOL conflict = NO;
      
      #warning Is it possible to detect conflicts in current Service menu without displaying it once ?
      NSMutableArray* systemWideServiceMenuItems = [NSMutableArray arrayWithArray:[[NSApp servicesMenu] itemArray]];
      NSMutableArray* alreadyUsedServiceShortcuts = [NSMutableArray array];
      NSUInteger index = 0;
      while(index < [systemWideServiceMenuItems count])
      {
        id object = [systemWideServiceMenuItems objectAtIndex:index];
        if ([object isKindOfClass:[NSMenu class]])
        {
          [systemWideServiceMenuItems addObjectsFromArray:[object itemArray]];
          [systemWideServiceMenuItems removeObjectAtIndex:index];
        }
        else if ([object isKindOfClass:[NSMenuItem class]])
        {
          if ([object hasSubmenu] && ![[object title] isEqualToString:@"LaTeXiT"])
          {
            [systemWideServiceMenuItems addObjectsFromArray:[[object submenu] itemArray]];
            [systemWideServiceMenuItems removeObjectAtIndex:index];
          }
          else
          {
            NSString* upperCaseShortcut = [[object keyEquivalent] uppercaseString];
            if (![upperCaseShortcut isEqualToString:@""])
              [alreadyUsedServiceShortcuts addObject:upperCaseShortcut];
            ++index;
          }
        }
        else
          [systemWideServiceMenuItems removeObjectAtIndex:index];
      }//end for each service
      
      conflict |= [alreadyUsedServiceShortcuts containsObject:valueShortcutString];
      NSEnumerator* enumerator = conflict ? nil : [serviceShortcuts objectEnumerator];
      NSDictionary* service = nil;
      while(!conflict && ((service = [enumerator nextObject])))
        conflict |= (service != value) && valueHasShortcut && [[value objectForKey:ServiceShortcutEnabledKey] boolValue] &&
                    [[service objectForKey:ServiceShortcutEnabledKey] boolValue] &&
                    [[[service objectForKey:ServiceShortcutStringKey] uppercaseString] isEqualToString:valueShortcutString];
      result = !conflict ? nil : [NSImage imageNamed:@"warning-triangle"];
      [self->serviceWarningShortcutConflictButton setHidden:!conflict && [self->serviceWarningShortcutConflictButton isHidden]];
    }
  }//end if (!reverse)
  else if (reverse)
  {
    if ([context isEqual:@"string"])  
    {
      const unichar shift = 0x21e7;
      const unichar command = 0x2318;
      const unichar tab[] = {shift, command};
      NSString* charactersToTrim = [NSString stringWithCharacters:tab length:2];
      result = value;
      result = [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
      result = [result stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:charactersToTrim]];
      result = [result uppercaseString];
      if (!result)
        result = @"";
      else if ([result length])
        result = [result substringWithRange:NSMakeRange(0, 1)];
    }//end if ([context isEqual:@"string"])  
  }//end if (reverse)
  return result;
}
//end transformer:reverse:value:

//prevents from selecting next line when finished editing
-(void) textDidEndEditing:(NSNotification *)aNotification
{
  NSInteger selectedRow = [self selectedRow];
  //the shortcut must be only one character long
  NSArray* serviceShortcuts = [[PreferencesController sharedController] serviceShortcuts];
  NSString* normalShortcut = ((selectedRow>=0) && ((unsigned)selectedRow<[serviceShortcuts count])) ?
    [[[serviceShortcuts objectAtIndex:selectedRow] objectForKey:ServiceShortcutStringKey] uppercaseString] : nil;
  NSUInteger length = [normalShortcut length];
  if (!normalShortcut)
    normalShortcut = @"";
  else if (length > 0)
    normalShortcut = [normalShortcut substringWithRange:NSMakeRange(0, 1)];
  [[serviceShortcuts objectAtIndex:selectedRow] setObject:normalShortcut forKey:ServiceShortcutStringKey];
  [super textDidEndEditing:aNotification];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
}
//end textDidEndEditing:



@end
