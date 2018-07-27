//
//  Utils.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 15/03/06.
//  Copyright 2006 Pierre Chatelier. All rights reserved.
//

#import "Utils.h"

#import "RegexKitLite.h"
int DebugLogLevel = 0;

static NSString* MyPNGPboardType = nil;
extern NSString* NSPNGPboardType __attribute__((weak_import));
static NSString* MyJPEGPboardType = nil;

BOOL isMacOS10_5OrAbove(void)
{
  BOOL result = (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4);
  return result;
}
//end isMacOS10_5OrAbove()

BOOL isMacOS10_6OrAbove(void)
{
  BOOL result = (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_5);
  return result;
}
//end isMacOS10_6OrAbove()

NSString* GetMyPNGPboardType(void)
{
  if (!MyPNGPboardType && isMacOS10_5OrAbove())
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
  if (!MyJPEGPboardType && isMacOS10_5OrAbove())
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
  #ifdef MIGRATE_ALIGN
  latex_mode_t result = (mode != LATEX_MODE_ALIGN) &&
                        (mode != LATEX_MODE_DISPLAY) &&
                        (mode != LATEX_MODE_INLINE) &&
                        (mode != LATEX_MODE_TEXT) ? LATEX_MODE_ALIGN :
                        mode;
  #else
  latex_mode_t result = (mode != LATEX_MODE_EQNARRAY) &&
                        (mode != LATEX_MODE_DISPLAY) &&
                        (mode != LATEX_MODE_INLINE) &&
                        (mode != LATEX_MODE_TEXT) ? LATEX_MODE_EQNARRAY :
                        mode;
  #endif
  return result;
}
//end validateLatexMode()

NSString* makeStringDifferent(NSString* string, NSArray* otherStrings, BOOL* pDidChange)
{
  NSString* result = string;
  NSMutableString* differentString = nil;
  BOOL didChange = NO;

  NSString* radical =
    [string stringByMatching:@"(.*) \\(([[:digit:]]+)\\)" options:RKLNoOptions inRange:NSMakeRange(0, [string length])
                     capture:1 error:nil];
  NSString* identifierString =
    [string stringByMatching:@"(.*) \\(([[:digit:]]+)\\)" options:RKLNoOptions inRange:NSMakeRange(0, [string length])
                     capture:2 error:nil];
  if (!radical || ![radical length])
    radical = string;
  if (!identifierString)
    identifierString = @"";

  unsigned int identifier = 2;
  if (radical)
  {
    result = radical;
    identifier = (unsigned)([identifierString intValue]+1);
  }

  if ([otherStrings containsObject:result])
  {
    didChange = YES;
    differentString = [NSMutableString stringWithFormat:@"%@ (%u)", result, identifier++];
  }
  while(identifier && [otherStrings containsObject:differentString])
  {
    [differentString setString:@""];
    [differentString appendFormat:@"%@ (%u)", result, identifier++];
  }
  if (didChange)
    result = differentString;
  if (pDidChange) *pDidChange = didChange;
  return result;
}
//end makeStringDifferent()

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

NSRect adaptRectangle(NSRect rectangle, NSRect containerRectangle, BOOL allowScaleDown, BOOL allowScaleUp, BOOL integerScale)
{
  NSRect result = rectangle;
  if (allowScaleDown && ((result.size.width>containerRectangle.size.width) ||
                         (result.size.height>containerRectangle.size.height)))
  {
    CGFloat divisor = MAX(!containerRectangle.size.width  ? 0.f : result.size.width/containerRectangle.size.width,
                          !containerRectangle.size.height ? 0.f : result.size.height/containerRectangle.size.height);
    if (integerScale)
      divisor = ceil(divisor);
    result.size.width /= divisor;
    result.size.height /= divisor;
  }
  if (allowScaleUp && ((rectangle.size.width<containerRectangle.size.width) ||
                       (rectangle.size.height<containerRectangle.size.height)))
  {
    CGFloat factor = MIN(!result.size.width  ? 0.f : containerRectangle.size.width/result.size.width,
                         !result.size.height ? 0.f : containerRectangle.size.height/result.size.height);
    if (factor)
      factor = floor(factor);
    result.size.width *= factor;
    result.size.height *= factor;
  }
  result.origin.x = (containerRectangle.origin.x+(containerRectangle.size.width-result.size.width)/2);
  result.origin.y = (containerRectangle.origin.y+(containerRectangle.size.height-result.size.height)/2);
  return result;
}
//end adaptRectangle()
