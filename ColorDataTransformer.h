//
//  ColorDataTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 11/11/08.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ColorDataTransformer : NSValueTransformer {

}

+(Class) transformedValueClass;
+(BOOL) allowsReverseTransformation;
-(id) transformedValue:(id)value;
-(id) reverseTransformedValue:(id)value;


@end
