//
//  DirectoryServiceHelper.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/09/08.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "DirectoryServiceHelper.h"


@implementation DirectoryServiceHelper

-(id) init
{
  if ((!(self = [super init])))
    return nil;
  tDirStatus dirStatus = dsOpenDirService(&gDirRef);
  if (gDirRef)
  {
    tDataListPtr nodePath = dsBuildFromPath(self->gDirRef, "/Local/Default", "/");
    if (nodePath)
    {
      dirStatus = dsOpenDirNode(self->gDirRef, nodePath, &self->nodeRef);
      dsDataListDeallocate(gDirRef, nodePath);
      free(nodePath);
    }
  }
  return self;
}
//end init

-(void) dealloc
{
  tDirStatus dirStatus = eDSNoErr;
  if (self->nodeRef)
    dirStatus = dsCloseDirNode(self->nodeRef);
  if (self->gDirRef)
    dirStatus = dsCloseDirService(gDirRef);
  [super dealloc];
}
//end dealloc

-(NSString*) valueForKey:(const char*)key andUser:(NSString*)userName
{
  NSString* result = nil;
  tDirStatus dirStatus = eDSNoErr;
  if (self->gDirRef && self->nodeRef)
  {
    tDataNodePtr recName = dsDataNodeAllocateString(self->gDirRef, [userName UTF8String]);
    if (recName)
    {
      tDataNodePtr recType = dsDataNodeAllocateString(self->gDirRef, kDSStdRecordTypeUsers);
      if (recType)
      {
        tRecordReference recRef = 0;
        dirStatus = dsOpenRecord(self->nodeRef, recType, recName, &recRef);
        if (recRef)
        {
          tDataNodePtr attrType = dsDataNodeAllocateString(gDirRef, key);
          if (attrType)
          {
            tAttributeValueEntryPtr attrValue = 0;
            dirStatus = dsGetRecordAttributeValueByIndex(recRef, attrType, 1, &attrValue);
            if (attrValue)
            {
              NSData* data = [NSData dataWithBytes:attrValue->fAttributeValueData.fBufferData length:attrValue->fAttributeValueData.fBufferLength];
              result = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
              dirStatus = dsDeallocAttributeValueEntry(gDirRef, attrValue);
            }//end if attrValue
            dirStatus = dsDataNodeDeAllocate(gDirRef, attrType);
          }//end if attrType
          dirStatus = dsCloseRecord(recRef);
        }//end if recRef
        dirStatus = dsDataNodeDeAllocate(gDirRef, recType);
      }//end if recType
      dirStatus = dsDataNodeDeAllocate(gDirRef, recName);
    }//end if recName
  }//end if (self->gDirRef && self->nodeRef)
  return result;
}

@end
