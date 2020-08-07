//
//  ServiceRegularExpressionFiltersController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/01/13.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ServiceRegularExpressionFiltersController : NSArrayController {

}

-(NSString*) applyFilter:(NSString*)value;
-(NSAttributedString*) applyFilterToAttributedString:(NSAttributedString*)value;

@end
