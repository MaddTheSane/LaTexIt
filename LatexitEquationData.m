//
//  LatexitEquationData.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 17/06/11.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "LatexitEquationData.h"

#import "LaTeXProcessor.h"

static NSEntityDescription* cachedEntity = nil;

@implementation LatexitEquationData

+(NSEntityDescription*) entity
{
  if (!cachedEntity)
  {
    @synchronized(self)
    {
      #ifdef ARC_ENABLED
      if (!cachedEntity)
        cachedEntity = [[[[LaTeXProcessor sharedLaTeXProcessor] managedObjectModel] entitiesByName] objectForKey:NSStringFromClass([self class])];
      #else
      if (!cachedEntity)
        cachedEntity = [[[[[LaTeXProcessor sharedLaTeXProcessor] managedObjectModel] entitiesByName] objectForKey:NSStringFromClass([self class])] retain];
      #endif
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
