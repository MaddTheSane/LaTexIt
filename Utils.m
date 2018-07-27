//
//  Utils.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 15/03/06.
//  Copyright 2006 Pierre Chatelier. All rights reserved.
//

#import "Utils.h"

static NSString* MyPNGPboardType = nil;

#ifndef PANTHER
extern NSString* NSPNGPboardType __attribute__((weak_import));
#endif

NSString* GetMyPNGPboardType(void)
{
  #ifdef PANTHER
  if (!MyPNGPboardType)
    MyPNGPboardType = (NSString*)UTTypeCopyPreferredTagWithClass((CFStringRef)@"public.png", kUTTagClassNSPboardType);//retain count is 1
  #else
  if (!MyPNGPboardType)  
    MyPNGPboardType = (NSString*)UTTypeCopyPreferredTagWithClass(kUTTypePNG, kUTTagClassNSPboardType);//retain count is 1
  #endif
  #ifndef PANTHER
  if (!MyPNGPboardType && NSPNGPboardType)
    MyPNGPboardType = [[NSString alloc] initWithString:NSPNGPboardType];
  #endif

  if (!MyPNGPboardType)
    MyPNGPboardType = NSTIFFPboardType;
  return MyPNGPboardType;
}

latex_mode_t validateLatexMode(latex_mode_t mode)
{
  return (mode >= LATEX_MODE_DISPLAY) && (mode <= LATEX_MODE_EQNARRAY) ? mode : LATEX_MODE_DISPLAY;
}

int indexOfLatexMode(latex_mode_t mode)
{
  int index = 0;
  switch(mode)
  {
    case LATEX_MODE_EQNARRAY:index=0;break;
    case LATEX_MODE_DISPLAY :index=1;break;
    case LATEX_MODE_INLINE  :index=2;break;
    case LATEX_MODE_TEXT    :index=3;break;
    default: index = mode; break;
  }
  return index;
}

latex_mode_t latexModeForIndex(int index)
{
  int mode = LATEX_MODE_DISPLAY;
  switch(index)
  {
    case 0:mode = LATEX_MODE_EQNARRAY;break;
    case 1:mode = LATEX_MODE_DISPLAY ;break;
    case 2:mode = LATEX_MODE_INLINE  ;break;
    case 3:mode = LATEX_MODE_TEXT    ;break;
    default:mode = index ;break;
  }
  return mode;
}

int EndianI_BtoN(int x)
{
  return (sizeof(x) == sizeof(int32_t)) ? EndianS32_BtoN(x) :
         (sizeof(x) == sizeof(int64_t)) ? EndianS64_BtoN(x) :
         x;
}

int EndianI_NtoB(int x)
{
  return (sizeof(x) == sizeof(int32_t)) ? EndianS32_NtoB(x) :
         (sizeof(x) == sizeof(int64_t)) ? EndianS64_NtoB(x) :
         x;
}

unsigned int EndianUI_BtoN(unsigned int x)
{
  return (sizeof(x) == sizeof(uint32_t)) ? EndianU32_BtoN(x) :
         (sizeof(x) == sizeof(uint64_t)) ? EndianU64_BtoN(x) :
         x;
}

unsigned int EndianUI_NtoB(unsigned int x)
{
  return (sizeof(x) == sizeof(uint32_t)) ? EndianU32_NtoB(x) :
         (sizeof(x) == sizeof(uint64_t)) ? EndianU64_NtoB(x) :
         x;
}

long EndianL_BtoN(long x)
{
  return (sizeof(x) == sizeof(int32_t)) ? EndianS32_BtoN(x) :
         (sizeof(x) == sizeof(int64_t)) ? EndianS64_BtoN(x) :
         x;
}

long EndianL_NtoB(long x)
{
  return (sizeof(x) == sizeof(int32_t)) ? EndianS32_NtoB(x) :
         (sizeof(x) == sizeof(int64_t)) ? EndianS64_NtoB(x) :
         x;
}

unsigned long EndianUL_BtoN(unsigned long x)
{
  return (sizeof(x) == sizeof(uint32_t)) ? EndianU32_BtoN(x) :
         (sizeof(x) == sizeof(uint64_t)) ? EndianU64_BtoN(x) :
         x;
}

unsigned long EndianUL_NtoB(unsigned long x)
{
  return (sizeof(x) == sizeof(uint32_t)) ? EndianU32_NtoB(x) :
         (sizeof(x) == sizeof(uint64_t)) ? EndianU64_NtoB(x) :
         x;
}

@implementation Utils

+(BOOL) createDirectoryPath:(NSString*)path attributes:(NSDictionary*)attributes
{
  BOOL ok = YES;
  BOOL isDirectory = NO;
  NSFileManager* fileManager = [NSFileManager defaultManager];
  NSArray* components = [path pathComponents];
  components = components ? components : [NSArray array];
  unsigned int i = 0;
  for(i = 1 ; ok && (i <= [components count]) ; ++i)
  {
    NSString* subPath = [NSString pathWithComponents:[components subarrayWithRange:NSMakeRange(0, i)]];
    ok &= ([fileManager fileExistsAtPath:subPath isDirectory:&isDirectory] && isDirectory) ||
           [fileManager createDirectoryAtPath:subPath attributes:attributes];
  }//end for each subPath
  return ok;
}
//end createDirectoryPath:attributes:

@end
