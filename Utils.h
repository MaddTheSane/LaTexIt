//
//  Utils.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 15/03/06.
//  Copyright 2006 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

extern int DebugLogLevel;
#define DebugLog(level,log,...) ((DebugLogLevel<level) ? 0 : NSLog(@"[%p : %@ %s] \"%@\"",[NSThread currentThread],[self class],sel_getName(_cmd),[NSString stringWithFormat:log,##__VA_ARGS__]))

#define NSAppKitVersionNumber10_4 824
#define NSAppKitVersionNumber10_5 949

BOOL isMacOS10_5OrAbove(void);
BOOL isMacOS10_6OrAbove(void);

FOUNDATION_STATIC_INLINE          char  IsBetween_c(char inf, char x, char sup) {return (inf <= x) && (x <= sup);}
FOUNDATION_STATIC_INLINE unsigned char  IsBetween_uc(unsigned char inf, unsigned char x, unsigned char sup) {return (inf <= x) && (x <= sup);}
FOUNDATION_STATIC_INLINE          short IsBetween_s(short inf, short x, short sup) {return (inf <= x) && (x <= sup);}
FOUNDATION_STATIC_INLINE unsigned short IsBetween_us(unsigned short inf, unsigned short x, unsigned short sup) {return (inf <= x) && (x <= sup);}
FOUNDATION_STATIC_INLINE          int   IsBetween_i(int inf, int x, int sup) {return (inf <= x) && (x <= sup);}
FOUNDATION_STATIC_INLINE unsigned int   IsBetween_ui(unsigned int inf, unsigned int x, unsigned int sup) {return (inf <= x) && (x <= sup);}
FOUNDATION_STATIC_INLINE          long  IsBetween_l(long inf, long x, long sup) {return (inf <= x) && (x <= sup);}
FOUNDATION_STATIC_INLINE unsigned long  IsBetween_ul(unsigned long inf, unsigned long x, unsigned long sup) {return (inf <= x) && (x <= sup);}
FOUNDATION_STATIC_INLINE         float  IsBetween_f(float inf, float x, float sup) {return (inf <= x) && (x <= sup);}
FOUNDATION_STATIC_INLINE       CGFloat  IsBetween_cgf(CGFloat inf, CGFloat x, CGFloat sup) {return (inf <= x) && (x <= sup);}
FOUNDATION_STATIC_INLINE        double  IsBetween_d(double inf, double x, double sup) {return (inf <= x) && (x <= sup);}
FOUNDATION_STATIC_INLINE          char  Clip_c(char inf, char x, char sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
FOUNDATION_STATIC_INLINE unsigned char  Clip_uc(unsigned char inf, unsigned char x, unsigned char sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
FOUNDATION_STATIC_INLINE          short Clip_s(short inf, short x, short sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
FOUNDATION_STATIC_INLINE unsigned short Clip_us(unsigned short inf, unsigned short x, unsigned short sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
FOUNDATION_STATIC_INLINE          int   Clip_i(int inf, int x, int sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
FOUNDATION_STATIC_INLINE unsigned int   Clip_ui(unsigned int inf, unsigned int x, unsigned int sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
FOUNDATION_STATIC_INLINE          long  Clip_l(long inf, long x, long sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
FOUNDATION_STATIC_INLINE unsigned long  Clip_ul(unsigned long inf, unsigned long x, unsigned long sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
FOUNDATION_STATIC_INLINE          float Clip_f(float inf, float x, float sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
FOUNDATION_STATIC_INLINE      CGFloat Clip_cgf(CGFloat inf, CGFloat x, CGFloat sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
FOUNDATION_STATIC_INLINE         double Clip_d(double inf, double x, double sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}

NSString* GetMyPNGPboardType(void);
NSString* GetMyJPEGPboardType(void);
latex_mode_t validateLatexMode(latex_mode_t mode);

FOUNDATION_EXTERN_INLINE int EndianI_BtoN(int x);
FOUNDATION_EXTERN_INLINE int EndianI_NtoB(int x);
FOUNDATION_EXTERN_INLINE unsigned int EndianUI_BtoN(unsigned int x);
FOUNDATION_EXTERN_INLINE unsigned int EndianUI_NtoB(unsigned int x);
FOUNDATION_EXTERN_INLINE long EndianL_BtoN(long x);
FOUNDATION_EXTERN_INLINE long EndianL_NtoB(long x);
FOUNDATION_EXTERN_INLINE unsigned long EndianUL_BtoN(unsigned long x);
FOUNDATION_EXTERN_INLINE unsigned long EndianUL_NtoB(unsigned long x);

NSString* makeStringDifferent(NSString* string, NSArray* otherStrings, BOOL* didChange);

FOUNDATION_STATIC_INLINE NSRect NSRectDelta(NSRect rect, CGFloat deltaX, CGFloat deltaY, CGFloat deltaWidth, CGFloat deltaHeight)
{return NSMakeRect(rect.origin.x+deltaX, rect.origin.y+deltaY, rect.size.width+deltaWidth, rect.size.height+deltaHeight);}

FOUNDATION_STATIC_INLINE NSRect NSRectChange(NSRect rect, BOOL setX, float newX, BOOL setY, float newY,
                                             BOOL setWidth, float newWidth, BOOL setHeight, float newHeight)
{return NSMakeRect(setX ? newX : rect.origin.x, setY ? newY : rect.origin.y,
                   setWidth ? newWidth : rect.size.width, setHeight ? newHeight : rect.size.height);}

NSRect adaptRectangle(NSRect rectangle, NSRect containerRectangle, BOOL allowScaleDown, BOOL allowScaleUp, BOOL integerScale);
