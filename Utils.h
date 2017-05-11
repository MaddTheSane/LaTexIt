//
//  Utils.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 15/03/06.
//  Copyright 2006 Pierre Chatelier. All rights reserved.
//

#include <tgmath.h>
#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

extern int DebugLogLevel;
#define DebugLog(level,log,...) do{if (DebugLogLevel>=level) {NSLog(@"[%p : %@ %s] \"%@\"",[NSThread currentThread],[self class],sel_getName(_cmd),[NSString stringWithFormat:log,##__VA_ARGS__]);}}while(0)
#define DebugLogStatic(level,log,...) do{if (DebugLogLevel>=level) {NSLog(@"[%p - static] \"%@\"",[NSThread currentThread], [NSString stringWithFormat:log,##__VA_ARGS__]);}}while(0)

#define LocalLocalizedString(key, comment) \
	    [[NSBundle bundleForClass:[self class]] localizedStringForKey:(key) value:@"" table:nil]

#ifndef NSAppKitVersionNumber10_4
#define NSAppKitVersionNumber10_4 824
#endif
#ifndef NSAppKitVersionNumber10_5
#define NSAppKitVersionNumber10_5 949
#endif
#ifndef NSAppKitVersionNumber10_6
#define NSAppKitVersionNumber10_6 1038
#endif
#ifndef NSAppKitVersionNumber10_7
#define NSAppKitVersionNumber10_7 1110
#endif
#ifndef NSAppKitVersionNumber10_8
#define NSAppKitVersionNumber10_8 1187
#endif

#define isMacOS10_5OrAbove() (YES)
#define isMacOS10_6OrAbove() (YES)
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_7
#define isMacOS10_7OrAbove() (YES)
#else
BOOL isMacOS10_7OrAbove(void);
#endif
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_8
#define isMacOS10_8OrAbove() (YES)
#else
BOOL isMacOS10_8OrAbove(void);
#endif

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

#define _TG_ATTRS __attribute__((__overloadable__, __always_inline__))

static inline char
_TG_ATTRS
__tg_Clip_N(char inf, char x, char sup) {return Clip_c(inf, x, sup);}

static inline unsigned char
_TG_ATTRS
__tg_Clip_N(unsigned char inf, unsigned char x, unsigned char sup) {return Clip_uc(inf, x, sup);}

static inline short
_TG_ATTRS
__tg_Clip_N(short inf, short x, short sup) {return Clip_s(inf, x, sup);}

static inline unsigned short
_TG_ATTRS
__tg_Clip_N(unsigned short inf, unsigned short x, unsigned short sup) {return Clip_us(inf, x, sup);}

static inline int
_TG_ATTRS
__tg_Clip_N(int inf, int x, int sup) {return Clip_i(inf, x, sup);}

static inline unsigned int
_TG_ATTRS
__tg_Clip_N(unsigned int inf, unsigned int x, unsigned int sup) {return Clip_ui(inf, x, sup);}

static inline long
_TG_ATTRS
__tg_Clip_N(long inf, long x, long sup) {return Clip_l(inf, x, sup);}

static inline unsigned long
_TG_ATTRS
__tg_Clip_N(unsigned long inf, unsigned long x, unsigned long sup) {return Clip_ul(inf, x, sup);}

static inline float
_TG_ATTRS
__tg_Clip_N(float inf, float x, float sup) {return Clip_f(inf, x, sup);}

static inline double
_TG_ATTRS
__tg_Clip_N(double inf, double x, double sup) {return Clip_d(inf, x, sup);}


static inline char
_TG_ATTRS
__tg_IsBetween_N(char inf, char x, char sup) {return IsBetween_c(inf, x, sup);}

static inline unsigned char
_TG_ATTRS
__tg_IsBetween_N(unsigned char inf, unsigned char x, unsigned char sup) {return IsBetween_uc(inf, x, sup);}

static inline short
_TG_ATTRS
__tg_IsBetween_N(short inf, short x, short sup) {return IsBetween_s(inf, x, sup);}

static inline unsigned short
_TG_ATTRS
__tg_IsBetween_N(unsigned short inf, unsigned short x, unsigned short sup) {return IsBetween_us(inf, x, sup);}

static inline int
_TG_ATTRS
__tg_IsBetween_N(int inf, int x, int sup) {return IsBetween_i(inf, x, sup);}

static inline unsigned int
_TG_ATTRS
__tg_IsBetween_N(unsigned int inf, unsigned int x, unsigned int sup) {return IsBetween_ui(inf, x, sup);}

static inline long
_TG_ATTRS
__tg_IsBetween_N(long inf, long x, long sup) {return IsBetween_l(inf, x, sup);}

static inline unsigned long
_TG_ATTRS
__tg_IsBetween_N(unsigned long inf, unsigned long x, unsigned long sup) {return IsBetween_ul(inf, x, sup);}

static inline float
_TG_ATTRS
__tg_IsBetween_N(float inf, float x, float sup) {return IsBetween_f(inf, x, sup);}

static inline double
_TG_ATTRS
__tg_IsBetween_N(double inf, double x, double sup) {return IsBetween_d(inf, x, sup);}


#undef Clip_N
#define Clip_N(__x, __y, __z)                                \
		__tg_Clip_N(__tg_promote3((__x), (__y), (__z))(__x), \
					__tg_promote3((__x), (__y), (__z))(__y), \
					__tg_promote3((__x), (__y), (__z))(__z))

#undef IsBetween_N
#define IsBetween_N(__x, __y, __z)                                \
    __tg_IsBetween_N(__tg_promote3((__x), (__y), (__z))(__x), \
    __tg_promote3((__x), (__y), (__z))(__y), \
    __tg_promote3((__x), (__y), (__z))(__z))


NSString* GetMySVGPboardType(void);
NSString* GetMyPNGPboardType(void);
NSString* GetMyJPEGPboardType(void);
NSString* GetWebURLsWithTitlesPboardType(void);
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
NSComparisonResult compareVersions(NSString* version1, NSString* version2);
