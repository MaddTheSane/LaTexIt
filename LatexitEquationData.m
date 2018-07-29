//
//  LatexitEquationData.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 17/06/11.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "LatexitEquationData.h"

#import "LaTeXProcessor.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

static NSEntityDescription* cachedEntity = nil;

@implementation LatexitEquationData

+(NSEntityDescription*) entity
{
  if (!cachedEntity)
  {
    @synchronized(self)
    {
      if (!cachedEntity)
        cachedEntity = [[LaTeXProcessor sharedLaTeXProcessor] managedObjectModel].entitiesByName[NSStringFromClass([self class])];
    }//end @synchronized(self)
  }//end if (!cachedEntity)
  return cachedEntity;
}
//end entity

-(void) didTurnIntoFault
{
  [super didTurnIntoFault];
}
//end didTurnIntoFault

-(NSData*) pdfData
{
  NSData* result = nil;
  [self willAccessValueForKey:@"pdfData"];
  result = [self primitiveValueForKey:@"pdfData"];
  [self didAccessValueForKey:@"pdfData"];
  return result;
} 
//end pdfData

-(void) setPdfData:(NSData*)value
{
  [self willChangeValueForKey:@"pdfData"];
  [self setPrimitiveValue:value forKey:@"pdfData"];
  [self didChangeValueForKey:@"pdfData"];
}
//end setPdfData:

@end
