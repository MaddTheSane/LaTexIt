/* =============================================================================
	FILE:		UKKQueue.m
	PROJECT:	Filie
    
    COPYRIGHT:  (c) 2005-06 M. Uli Kusterer, all rights reserved.
    
	AUTHORS:	M. Uli Kusterer - UK
    
    LICENSES:   MIT License

	REVISIONS:
		2006-03-13	UK	Created, moved notification constants here as exportable
						symbols.
   ========================================================================== */

// -----------------------------------------------------------------------------
//  Headers:
// -----------------------------------------------------------------------------

#import <Cocoa/Cocoa.h>
#import "UKFileWatcher.h"


// -----------------------------------------------------------------------------
//  Constants:
// -----------------------------------------------------------------------------

// Do not rely on the actual contents of these constants. They will eventually
//	be changed to be more generic and less KQueue-specific.

NSString*const UKFileWatcherRenameNotification				= @"UKKQueueFileRenamedNotification";
NSString*const UKFileWatcherWriteNotification				= @"UKKQueueFileWrittenToNotification";
NSString*const UKFileWatcherDeleteNotification				= @"UKKQueueFileDeletedNotification";
NSString*const UKFileWatcherAttributeChangeNotification		= @"UKKQueueFileAttributesChangedNotification";
NSString*const UKFileWatcherSizeIncreaseNotification		= @"UKKQueueFileSizeIncreasedNotification";
NSString*const UKFileWatcherLinkCountChangeNotification		= @"UKKQueueFileLinkCountChangedNotification";
NSString*const UKFileWatcherAccessRevocationNotification	= @"UKKQueueFileAccessRevocationNotification";

