//
//  Utils.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 15/03/06.
//  Copyright 2006 Pierre Chatelier. All rights reserved.
//

#import "Utils.h"

static NSString* MyPNGPboardType = nil;
extern NSString* NSPNGPboardType __attribute__((weak_import));
static NSString* MyJPEGPboardType = nil;

#define NSAppKitVersionNumber10_4 824

NSString* GetMyPNGPboardType(void)
{
  if (!MyPNGPboardType && (!(floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4))) //Leopard+
    MyPNGPboardType = @"public.png";
  if (!MyPNGPboardType)  
    MyPNGPboardType = (NSString*)UTTypeCopyPreferredTagWithClass(kUTTypePNG, kUTTagClassNSPboardType);//retain count is 1
  if (!MyPNGPboardType && NSPNGPboardType)
    MyPNGPboardType = [[NSString alloc] initWithString:NSPNGPboardType];
  if (!MyPNGPboardType)
    MyPNGPboardType = NSTIFFPboardType;
  return MyPNGPboardType;
}
//end GetMyPNGPboardType()

NSString* GetMyJPEGPboardType(void)
{
  if (!MyJPEGPboardType && (!(floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4))) //Leopard+
    MyJPEGPboardType = @"public.jpeg";
  if (!MyJPEGPboardType)  
    MyJPEGPboardType = (NSString*)UTTypeCopyPreferredTagWithClass(kUTTypeJPEG, kUTTagClassNSPboardType);//retain count is 1
  if (!MyJPEGPboardType)
    MyJPEGPboardType = NSTIFFPboardType;
  return MyJPEGPboardType;
}
//end GetMyPNGPboardType()

latex_mode_t validateLatexMode(latex_mode_t mode)
{
  return (mode >= LATEX_MODE_DISPLAY) && (mode <= LATEX_MODE_EQNARRAY) ? mode : LATEX_MODE_DISPLAY;
}
//end validateLatexMode()

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
//end indexOfLatexMode()

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
//end latexModeForIndex()

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
