/* =============================================================================
	FILE:		UKFNSubscribeFileWatcher.m
	PROJECT:	Filie
    
    COPYRIGHT:  (c) 2005 M. Uli Kusterer, all rights reserved.
    
	AUTHORS:	M. Uli Kusterer - UK
    
    LICENSES:   MIT License

	REVISIONS:
		2006-03-13	UK	Commented, added singleton.
		2005-03-02	UK	Created.
   ========================================================================== */

// -----------------------------------------------------------------------------
//  Headers:
// -----------------------------------------------------------------------------

#import <Cocoa/Cocoa.h>
#import "UKFileWatcher.h"
#include <Carbon/Carbon.h>

/*
	NOTE: FNSubscribe has a built-in delay: If your application is in the
	background while the changes happen, all notifications will be queued up
	and sent to your app at once the moment it is brought to front again. If
	your app really needs to do live updates in the background, use a KQueue
	instead.
*/

// -----------------------------------------------------------------------------
//  Class declaration:
// -----------------------------------------------------------------------------

@interface UKFNSubscribeFileWatcher : NSObject <UKFileWatcher>
{
    __unsafe_unretained id<UKFileWatcherDelegate> delegate;           ///< Delegate must respond to \c UKFileWatcherDelegate protocol.
    NSMutableDictionary<NSString*,NSValue*>*      subscriptions;      ///< List of \c FNSubscription pointers in NSValues, with the pathnames as their keys.
}

+(UKFNSubscribeFileWatcher*) sharedFileWatcher;

// UKFileWatcher defines the methods: addPath: removePath: and delegate accessors.

// Private:
-(void) sendDelegateMessage: (FNMessage)message forSubscription: (FNSubscriptionRef)subscription;

@end
