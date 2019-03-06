//
//  NSAttributedStringExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/08/06.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSAttributedString (Extended)

-(NSDictionary*) attachmentsOfType:(NSString*)type docAttributes:(NSDictionary*)docAttributes;

@end
