//
//  LatexitEquationData.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 17/06/11.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface LatexitEquationData : NSManagedObject {
  //NSData* pdfData;
}

+(NSEntityDescription*) entity;

//accessors
@property (retain) NSData *pdfData;

@end
