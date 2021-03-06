//
//  LinkBack.h
//  LinkBack Project
//
//  Created by Charles Jolley on Tue Jun 15 2004.
//  Copyright (c) 2004, Nisus Software, Inc.
//  All rights reserved.

//  Redistribution and use in source and binary forms, with or without 
//  modification, are permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, 
//  this list of conditions and the following disclaimer.
//
//  Redistributions in binary form must reproduce the above copyright notice, 
//  this list of conditions and the following disclaimer in the documentation 
//  and/or other materials provided with the distribution.
//
//  Neither the name of the Nisus Software, Inc. nor the names of its 
//  contributors may be used to endorse or promote products derived from this 
//  software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS 
//  IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, 
//  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
//  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR 
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
//  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, 
//  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR 
//  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
//  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
//  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import <Foundation/NSDictionary.h>
#import <Foundation/NSDate.h>
#import <AppKit/NSPasteboard.h>

NS_ASSUME_NONNULL_BEGIN

/// Use this pasteboard type to put LinkBack data to the pasteboard.  Use +[NSDictionary linkBackDataWithServerName:appData:] to create the data.
extern NSPasteboardType const LinkBackPboardType NS_SWIFT_NAME(linkBack) ;

// Default Action Names.  These will be localized for you automatically.
extern NSString * const LinkBackEditActionName ;
extern NSString * const LinkBackRefreshActionName ;

//
// Support Functions
//
extern NSString* LinkBackUniqueItemKey(void);
extern NSString* LinkBackEditMultipleMenuTitle(void);
extern NSString* LinkBackEditNoneMenuTitle(void);

// 
// Deprecated Support Functions -- use LinkBack Data Category instead
//
id __null_unspecified MakeLinkBackData(NSString* __null_unspecified serverName, id __null_unspecified appData) DEPRECATED_ATTRIBUTE;
id __null_unspecified LinkBackGetAppData(id __null_unspecified linkBackData) DEPRECATED_ATTRIBUTE;
BOOL LinkBackDataBelongsToActiveApplication(id __null_unspecified data) DEPRECATED_ATTRIBUTE;

///
/// LinkBack Data Category
///
/// Use these methods to create and access linkback data objects.
@interface NSDictionary (LinkBackData)

+ (NSDictionary<NSString*,id>*)linkBackDataWithServerName:(NSString*)serverName appData:(nullable id)appData ;

+ (NSDictionary<NSString*,id>*)linkBackDataWithServerName:(NSString*)serverName appData:(nullable id)appData suggestedRefreshRate:(NSTimeInterval)rate ;

+ (NSDictionary<NSString*,id>*)linkBackDataWithServerName:(NSString*)serverName appData:(nullable id)appData actionName:(nullable NSString*)action suggestedRefreshRate:(NSTimeInterval)rate ;

@property (readonly) BOOL linkBackDataBelongsToActiveApplication ;

@property (readonly, retain, nullable) id linkBackAppData ;
@property (readonly, copy, nullable) NSString *linkBackSourceApplicationName ;
@property (readonly, copy, nullable) NSString *linkBackActionName ;
@property (readonly, copy, nullable) NSString *linkBackVersion ;
@property (readonly, retain, nullable) NSURL *linkBackApplicationURL ;

@property (readonly) NSTimeInterval linkBackSuggestedRefreshRate ;

@property (readonly, copy) NSString *linkBackEditMenuTitle ;

@end

//
// Delegate Protocols
//

@class LinkBack ;

@protocol LinkBackServerDelegate <NSObject>
- (void)linkBackDidClose:(LinkBack*)link ;
- (void)linkBackClientDidRequestEdit:(LinkBack*)link ;
@end

@protocol LinkBackClientDelegate <NSObject>
- (void)linkBackDidClose:(LinkBack*)link ;
- (void)linkBackServerDidSendEdit:(LinkBack*)link ;
@end

/// used for cross app communications
@protocol LinkBack <NSObject>
- (oneway void)remoteCloseLink ;
- (void)requestEditWithPasteboardName:(bycopy NSPasteboardName)pboardName ; ///< from client
- (void)refreshEditWithPasteboardName:(bycopy NSPasteboardName)pboardName ; ///< from server
@end


static NSString* LinkBackServerBundleIdentifierKey = @"bundleId" ;

@interface LinkBack : NSObject <LinkBack> {
    LinkBack* peer ; ///< the client or server on the other side.
    BOOL isServer ; 
    __unsafe_unretained id delegate ;
    NSPasteboard* pboard ;
    id repobj ; 
    NSString* sourceName ;
	NSString* sourceApplicationName ;
    NSString* key ;
}

/// works for both the client and server side.  Valid only while a link is connected.
+ (nullable LinkBack*)activeLinkBackForItemKey:(id)key ;

// ...........................................................................
// General Use methods
//
@property (readonly, strong) NSPasteboard *pasteboard ;
- (void)closeLink ;

/// Applications can use this represented object to attach some meaning to the live link.  For example, a client application may set this to the object to be modified when the edit is refreshed.  This retains its value.
@property (readwrite, strong, nullable) id representedObject ;

@property (readonly, copy) NSString *sourceName ;
@property (readonly, copy) NSString *sourceApplicationName ;
@property (readonly, copy) NSString *itemKey ; // maybe this matters only on the client side.

// ...........................................................................
// Server-side methods
//
+ (BOOL)publishServerWithName:(NSString*)name delegate:(id<LinkBackServerDelegate>)del;
+ (BOOL)publishServerWithName:(NSString*)name bundleIdentifier:(NSString *)anIdentifier delegate:(id<LinkBackServerDelegate>)del;

+ (void)retractServerWithName:(NSString*)name;
+ (void)retractServerWithName:(NSString*)name bundleIdentifier:(NSString *)anIdentifier;

- (void)sendEdit ;

// ...........................................................................
// Client-Side Methods
//
+ (nullable LinkBack*)editLinkBackData:(id)data sourceName:(NSString*)aName delegate:(id<LinkBackClientDelegate>)del itemKey:(NSString*)aKey ;

@end

@interface LinkBack (InternalUseOnly)

- (id)initServerWithClient: (LinkBack*)aLinkBack delegate: (id<LinkBackServerDelegate>)aDel ;

- (id)initClientWithSourceName:(NSString*)aName delegate:(id<LinkBackClientDelegate>)aDel itemKey:(NSString*)aKey ;

- (BOOL)connectToServerWithName:(NSString*)aName inApplication:(NSString*)bundleIdentifier fallbackURL:(NSURL*)url appName:(NSString*)appName ;

- (void)requestEdit ;

@end

NS_ASSUME_NONNULL_END
