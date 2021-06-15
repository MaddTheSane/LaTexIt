//
//  Utils.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 15/03/06.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import "Utils.h"

#import "NSObjectExtended.h"
#import "NSStringExtended.h"

int DebugLogLevel = 0;

#include <AvailabilityMacros.h>

#import <objc/objc-runtime.h>

NSString* NSAppearanceDidChangeNotification = @"NSAppearanceDidChangeNotification";

static NSString* MyWebURLsWithTitlesPboardType = nil;

NSString* GetMySVGPboardType(void)
{
  NSString* result = nil;
  if (!result && isMacOS10_10OrAbove())
    result = (NSString*)kUTTypeScalableVectorGraphics;
  if (!result)
    result = @"public.svg-image";
  return result;
}
//end GetMySVGPboardType()

NSString* GetWebURLsWithTitlesPboardType(void)
{
  if (!MyWebURLsWithTitlesPboardType)
    MyWebURLsWithTitlesPboardType = @"WebURLsWithTitlesPboardType";
  return MyWebURLsWithTitlesPboardType;
}
//end GetWebURLsWithTitlesPboardType()

latex_mode_t validateLatexMode(latex_mode_t mode)
{
  latex_mode_t result = (mode != LATEX_MODE_ALIGN) &&
                        (mode != LATEX_MODE_DISPLAY) &&
                        (mode != LATEX_MODE_INLINE) &&
                        (mode != LATEX_MODE_TEXT) ? LATEX_MODE_ALIGN :
                        mode;
  return result;
}
//end validateLatexMode()

NSString* getUTIForExportFormat(export_format_t exportFormat)
{
  NSString* result = nil;
  switch(exportFormat)
  {
    case EXPORT_FORMAT_PDF:
    case EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS:
      result = (NSString*)kUTTypePDF;
      break;
    case EXPORT_FORMAT_EPS:
      result = @"com.adobe.encapsulated-​postscript";
      break;
    case EXPORT_FORMAT_TIFF:
      result = (NSString*)kUTTypeTIFF;
      break;
    case EXPORT_FORMAT_PNG:
      result = (NSString*)kUTTypePNG;
      break;
    case EXPORT_FORMAT_JPEG:
      result = (NSString*)kUTTypeJPEG;
      break;
    case EXPORT_FORMAT_MATHML:
      result = (NSString*)kUTTypeHTML;
      break;
    case EXPORT_FORMAT_SVG:
      result = GetMySVGPboardType();
      break;
    case EXPORT_FORMAT_TEXT:
      result = (NSString*)kUTTypeText;
      break;
    case EXPORT_FORMAT_RTFD:
      result = (NSString*)kUTTypeRTFD;
      break;
  }//end switch(exportFormat)
  return result;
}
//end getUTIForExportFormat()

NSString* getFileExtensionForExportFormat(export_format_t exportFormat)
{
  NSString* result = nil;
  switch(exportFormat)
  {
    case EXPORT_FORMAT_PDF:
    case EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS:
      result = @"pdf";
      break;
    case EXPORT_FORMAT_EPS:
      result = @"eps";
      break;
    case EXPORT_FORMAT_TIFF:
      result = @"tiff";
      break;
    case EXPORT_FORMAT_PNG:
      result = @"png";
      break;
    case EXPORT_FORMAT_JPEG:
      result = @"jpeg";
      break;
    case EXPORT_FORMAT_MATHML:
      result = @"html";
      break;
    case EXPORT_FORMAT_SVG:
      result = @"svg";
      break;
    case EXPORT_FORMAT_TEXT:
      result = @"tex";
      break;
    case EXPORT_FORMAT_RTFD:
      result = @"rtfd";
      break;
  }//end switch(exportFormat)
  return result;
}
//end getFileExtensionForExportFormat()

NSString* makeStringDifferent(NSString* string, NSArray* otherStrings, BOOL* pDidChange)
{
  NSString* result = string;
  NSMutableString* differentString = nil;
  BOOL didChange = NO;

  NSString* radical =
    [string stringByMatching:@"(.*) \\(([[:digit:]]+)\\)" options:RKLNoOptions inRange:string.range
                     capture:1 error:nil];
  NSString* identifierString =
    [string stringByMatching:@"(.*) \\(([[:digit:]]+)\\)" options:RKLNoOptions inRange:string.range
                     capture:2 error:nil];
  if (!radical || ![radical length])
    radical = string;
  if (!identifierString)
    identifierString = @"";

  NSUInteger identifier = 2;
  if (radical)
  {
    result = radical;
    identifier = (NSUInteger)([identifierString integerValue]+1);
  }

  if ([otherStrings containsObject:result])
  {
    didChange = YES;
    differentString = [NSMutableString stringWithFormat:@"%@ (%lu)", result, (unsigned long)identifier++];
  }
  while(identifier && [otherStrings containsObject:differentString])
  {
    [differentString setString:@""];
    [differentString appendFormat:@"%@ (%lu)", result, (unsigned long)identifier++];
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

NSComparisonResult compareVersions(NSString* version1, NSString* version2)
{
  NSComparisonResult result = NSOrderedSame;
  if (!version1 && !version2){
  }
  else if (!version1 && version2)
    result = NSOrderedAscending;
  else if (version1 && !version2)
    result = NSOrderedDescending;
  else//if (version1 && version2)
  {
    NSArray* components1 = [version1 componentsSeparatedByString:@"."];
    NSArray* components2 = [version2 componentsSeparatedByString:@"."];
    NSEnumerator* it1 = [components1 objectEnumerator];
    NSEnumerator* it2 = [components2 objectEnumerator];
    NSString* c1 = [it1 nextObject];
    NSString* c2 = [it2 nextObject];
    BOOL stop = NO;
    while(!stop)
    {
      if (!c1 && !c2){
      }
      else if (!c1 && c2)
        result = NSOrderedAscending;
      else if (c1 && !c2)
        result = NSOrderedDescending;
      else
        result = [c1 compare:c2 options:NSNumericSearch];
      stop |= !c1 || !c2 || (result != NSOrderedSame);
      c1 = [it1 nextObject];
      c2 = [it2 nextObject];
    }//end while(!stop)
  }//if (version1 && version2)
  return result;
}
//end compareVersions()

void MethodSwizzle(Class aClass, SEL orig_sel, SEL alt_sel, BOOL isInstanceMethod)
{
  Method orig_method = nil, alt_method = nil;
  if (isInstanceMethod)
  {
    orig_method = class_getInstanceMethod(aClass, orig_sel);
    alt_method = class_getInstanceMethod(aClass, alt_sel);
  }
  else
  {
    orig_method = class_getClassMethod(aClass, orig_sel);
    alt_method = class_getClassMethod(aClass, alt_sel);
  }
  if ((orig_method != nil) && (alt_method != nil))
  {
    #if 1//defined(OBJC_API_VERSION) && (OBJC_API_VERSION >= 2)
    IMP m1 = method_getImplementation(orig_method);
    IMP m2 = method_getImplementation(alt_method);
    method_setImplementation(orig_method, m2);
    method_setImplementation(alt_method, m1);
    #else
    char* temp1 = 0;
    IMP temp2 = 0;
    temp1 = orig_method->method_types;
    orig_method->method_types = alt_method->method_types;
    alt_method->method_types = temp1;
    temp2 = orig_method->method_imp;
    orig_method->method_imp = alt_method->method_imp;
    alt_method->method_imp = temp2;
    #endif
  }//end if ((orig_method != nil) && (alt_method != nil))
}
//end MethodSwizzle()
