//
//  LibraryPreviewPanelImageView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/05/06.
//  Copyright 2006 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface LibraryPreviewPanelImageView : NSImageView {
  NSColor* backgroundColor;
}

-(void) setBackgroundColor:(NSColor*)color;
-(NSColor*) backgroundColor;

@end
