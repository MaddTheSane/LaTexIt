//
//  LaTeXiT_HelperAppDelegate.m
//  LaTeXiT Helper
//
//  Created by Pierre Chatelier on 25/11/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "LaTeXiT_HelperAppDelegate.h"

#import "NSWorkspaceExtended.h"

@implementation LaTeXiT_HelperAppDelegate

-(void) applicationDidFinishLaunching:(NSNotification*)aNotification
{
  BOOL published = [LinkBack publishServerWithName:@"LaTeXiT" delegate:self];
  if (!published)
    NSLog(@"LaTeXiT_Helper : published server failed");
  NSArray* componentsOfSelfPath = [NSBundle mainBundle].bundlePath.pathComponents;
  NSInteger count = componentsOfSelfPath.count;
  NSArray* componentsOfOwnerPath = (count < 3) ? nil : [componentsOfSelfPath subarrayWithRange:NSMakeRange(0, count-3)];
  NSString* ownerPath = [NSString pathWithComponents:componentsOfOwnerPath];
  if ([ownerPath.pathExtension.lowercaseString isEqualToString:@"app"])
    [[NSWorkspace sharedWorkspace] launchApplication:ownerPath];
  else
  {
    NSNumber* launchIdentifier = nil;
    [[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:@"fr.chachatelier.pierre.LaTeXiT" options:NSWorkspaceLaunchDefault
      additionalEventParamDescriptor:nil launchIdentifier:&launchIdentifier];
  }
}
//end applicationDidFinishLaunching:

-(void) applicationWillTerminate:(NSNotification*)notification
{
  [LinkBack retractServerWithName:@"LaTeXiT"];
}
//end applicationWillTerminate:

//LinkBack

-(void) linkBackDidClose:(LinkBack*)link
{
}
//end linkBackDidClose:

-(void) linkBackClientDidRequestEdit:(LinkBack*)link
{
  id oldPeer = [[link valueForKey:@"peer"] retain];
  [oldPeer remoteCloseLink];
  [link connectToServerWithName:@"LaTeXiT" inApplication:@"fr.chachatelier.pierre.LaTeXiT" fallbackURL:[NSURL URLWithString:@"http://pierre.chachatelier.fr/latexit/index.php"] appName:@"LaTeXiT"];
  [link setValue:oldPeer forKeyPath:@"peer.peer"];
  [oldPeer release];
  [link requestEdit];
}
//end linkBackClientDidRequestEdit:

@end
