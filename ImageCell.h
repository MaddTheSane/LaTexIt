//
//  ImageCell.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 10/03/2019.
//
//

#import <Cocoa/Cocoa.h>

@interface ImageCell : NSImageCell {
  NSColor* backgroundColor;
}

-(NSColor*) backgroundColor;
-(void) setBackgroundColor:(NSColor*)value;

@end
