//
//  ServiceRegularExpressionFiltersController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/01/13.
//  Copyright 2013 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ServiceRegularExpressionFiltersController : NSArrayController {

}

-(NSString*) applyFilter:(NSString*)value;

@end
