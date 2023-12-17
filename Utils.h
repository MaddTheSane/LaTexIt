//
//  Utils.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 15/03/06.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <tgmath.h>

#ifdef ARC_ENABLED
#define CHBRIDGE __bridge
#else
#define CHBRIDGE
#endif

#import "LaTeXiTSharedTypes.h"

extern int DebugLogLevel;
#define DebugLog(level,log,...) do{if (DebugLogLevel>=level) {NSLog(@"[%p : %@ %s] \"%@\"",[NSThread currentThread],[self class],sel_getName(_cmd),[NSString stringWithFormat:log,##__VA_ARGS__]);}}while(0)
#define DebugLogStatic(level,log,...) do{if (DebugLogLevel>=level) {NSLog(@"[%p - static] \"%@\"",[NSThread currentThread], [NSString stringWithFormat:log,##__VA_ARGS__]);}}while(0)

#define LocalLocalizedString(key, comment) \
	    [[NSBundle bundleForClass:[self class]] localizedStringForKey:(key) value:@"" table:nil]

#define NSAppKitVersionNumber10_10 1343
#define NSAppKitVersionNumber10_11 1404
#define NSAppKitVersionNumber10_12 1504
#define NSAppKitVersionNumber10_13 1561
#define NSAppKitVersionNumber10_14 1671

NS_INLINE BOOL isMacOS10_5OrAbove(void)  {return (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4);}
NS_INLINE BOOL isMacOS10_6OrAbove(void)  {return (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_5);}
NS_INLINE BOOL isMacOS10_7OrAbove(void)  {return (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6);}
NS_INLINE BOOL isMacOS10_8OrAbove(void)  {return (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_7);}
NS_INLINE BOOL isMacOS10_9OrAbove(void)  {return (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_8);}
NS_INLINE BOOL isMacOS10_10OrAbove(void) {return (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_9);}
NS_INLINE BOOL isMacOS10_11OrAbove(void) {return (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_10);}
NS_INLINE BOOL isMacOS10_12OrAbove(void) {return (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_11);}
NS_INLINE BOOL isMacOS10_13OrAbove(void) {return (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_12);}
NS_INLINE BOOL isMacOS10_14OrAbove(void) {return (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_13);}
NS_INLINE BOOL isMacOS10_15OrAbove(void) {return (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_14);}

extern const NSNotificationName NSAppearanceDidChangeNotification;

NS_INLINE          char  IsBetween_c(char inf, char x, char sup) {return (inf <= x) && (x <= sup);}
NS_INLINE unsigned char  IsBetween_uc(unsigned char inf, unsigned char x, unsigned char sup) {return (inf <= x) && (x <= sup);}
NS_INLINE          short IsBetween_s(short inf, short x, short sup) {return (inf <= x) && (x <= sup);}
NS_INLINE unsigned short IsBetween_us(unsigned short inf, unsigned short x, unsigned short sup) {return (inf <= x) && (x <= sup);}
NS_INLINE          int   IsBetween_i(int inf, int x, int sup) {return (inf <= x) && (x <= sup);}
NS_INLINE unsigned int   IsBetween_ui(unsigned int inf, unsigned int x, unsigned int sup) {return (inf <= x) && (x <= sup);}
NS_INLINE     NSInteger  IsBetween_nsi(NSInteger inf, NSInteger x, NSInteger sup) {return (inf <= x) && (x <= sup);}
NS_INLINE    NSUInteger  IsBetween_nsui(NSUInteger inf, NSUInteger x, NSUInteger sup) {return (inf <= x) && (x <= sup);}
NS_INLINE          long  IsBetween_l(long inf, long x, long sup) {return (inf <= x) && (x <= sup);}
NS_INLINE unsigned long  IsBetween_ul(unsigned long inf, unsigned long x, unsigned long sup) {return (inf <= x) && (x <= sup);}
NS_INLINE         float  IsBetween_f(float inf, float x, float sup) {return (inf <= x) && (x <= sup);}
NS_INLINE       CGFloat  IsBetween_cgf(CGFloat inf, CGFloat x, CGFloat sup) {return (inf <= x) && (x <= sup);}
NS_INLINE        double  IsBetween_d(double inf, double x, double sup) {return (inf <= x) && (x <= sup);}
NS_INLINE          char  Clip_c(char inf, char x, char sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
NS_INLINE unsigned char  Clip_uc(unsigned char inf, unsigned char x, unsigned char sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
NS_INLINE          short Clip_s(short inf, short x, short sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
NS_INLINE unsigned short Clip_us(unsigned short inf, unsigned short x, unsigned short sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
NS_INLINE          int   Clip_i(int inf, int x, int sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
NS_INLINE unsigned int   Clip_ui(unsigned int inf, unsigned int x, unsigned int sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
NS_INLINE    NSInteger   Clip_nsi(NSInteger inf, NSInteger x, NSInteger sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
NS_INLINE   NSUInteger   Clip_nsui(NSUInteger inf, NSUInteger x, NSUInteger sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
NS_INLINE          long  Clip_l(long inf, long x, long sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
NS_INLINE unsigned long  Clip_ul(unsigned long inf, unsigned long x, unsigned long sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
NS_INLINE          float Clip_f(float inf, float x, float sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
NS_INLINE      CGFloat Clip_cgf(CGFloat inf, CGFloat x, CGFloat sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
NS_INLINE         double Clip_d(double inf, double x, double sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}

NSString* GetMySVGPboardType(void);
NSPasteboardType GetWebURLsWithTitlesPboardType(void);
latex_mode_t validateLatexMode(latex_mode_t mode);
NSString* getUTIForExportFormat(export_format_t exportFormat);
UTType* getContentTypeForExportFormat(export_format_t exportFormat) API_AVAILABLE(macos(11.0));
NSString* getFileExtensionForExportFormat(export_format_t exportFormat);

FOUNDATION_EXTERN int EndianI_BtoN(int x);
FOUNDATION_EXTERN int EndianI_NtoB(int x);
FOUNDATION_EXTERN unsigned int EndianUI_BtoN(unsigned int x);
FOUNDATION_EXTERN unsigned int EndianUI_NtoB(unsigned int x);
FOUNDATION_EXTERN long EndianL_BtoN(long x);
FOUNDATION_EXTERN long EndianL_NtoB(long x);
FOUNDATION_EXTERN unsigned long EndianUL_BtoN(unsigned long x);
FOUNDATION_EXTERN unsigned long EndianUL_NtoB(unsigned long x);

NS_INLINE NSString* NSStringWithNilDefault(NSString* s, NSString* nilDefault) {return !s ? nilDefault : s;}
NSString* makeStringDifferent(NSString* string, NSArray* otherStrings, BOOL* didChange);

NS_INLINE NSRect NSRectDelta(NSRect rect, CGFloat deltaX, CGFloat deltaY, CGFloat deltaWidth, CGFloat deltaHeight)
{return NSMakeRect(rect.origin.x+deltaX, rect.origin.y+deltaY, rect.size.width+deltaWidth, rect.size.height+deltaHeight);}

NS_INLINE NSRect NSRectChange(NSRect rect, BOOL setX, CGFloat newX, BOOL setY, CGFloat newY,
                                             BOOL setWidth, CGFloat newWidth, BOOL setHeight, CGFloat newHeight)
{return NSMakeRect(setX ? newX : rect.origin.x, setY ? newY : rect.origin.y,
                   setWidth ? newWidth : rect.size.width, setHeight ? newHeight : rect.size.height);}

NSRect adaptRectangle(NSRect rectangle, NSRect containerRectangle, BOOL allowScaleDown, BOOL allowScaleUp, BOOL integerScale);
NSComparisonResult compareVersions(NSString* version1, NSString* version2);

void MethodSwizzle(Class aClass, SEL orig_sel, SEL alt_sel, BOOL isInstanceMethod);

#define _LU_ATTRS __attribute__((__overloadable__, __always_inline__))
#define _LU_ATTRSp __attribute__((__overloadable__))

typedef void _Argument_type_is_not_arithmetic;
static inline _Argument_type_is_not_arithmetic __lu_promote(...)
  __attribute__((__unavailable__,__overloadable__));
static inline char                 _LU_ATTRSp __lu_promote(char);
static inline unsigned char        _LU_ATTRSp __lu_promote(unsigned char);
static inline short                _LU_ATTRSp __lu_promote(short);
static inline unsigned short       _LU_ATTRSp __lu_promote(unsigned short);
static inline int                  _LU_ATTRSp __lu_promote(int);
static inline unsigned int         _LU_ATTRSp __lu_promote(unsigned int);
static inline long                 _LU_ATTRSp __lu_promote(long);
static inline unsigned long        _LU_ATTRSp __lu_promote(unsigned long);
static inline float                _LU_ATTRSp __lu_promote(float);
static inline double               _LU_ATTRSp __lu_promote(double);

#define __lu_promote3(__x, __y, __z) (__typeof__(__lu_promote(__x) + \
                                                 __lu_promote(__y) + \
                                                 __lu_promote(__z)))

static inline char _LU_ATTRS __IsBetween(char inf, char x, char sup) {return IsBetween_c(inf, x, sup);}
static inline unsigned char _LU_ATTRS __IsBetween(unsigned char inf, unsigned char x, unsigned char sup) {return IsBetween_uc(inf, x, sup);}
static inline short _LU_ATTRS __IsBetween(short inf, short x, short sup) {return IsBetween_s(inf,x,sup);}
static inline unsigned short _LU_ATTRS __IsBetween(unsigned short inf, unsigned short x, unsigned short sup) {return IsBetween_us(inf,x,sup);}
static inline int _LU_ATTRS __IsBetween(int inf, int x, int sup) {return IsBetween_i(inf,x,sup);}
static inline unsigned int _LU_ATTRS __IsBetween(unsigned int inf, unsigned int x, unsigned int sup) {return IsBetween_ui(inf,x,sup);}
static inline long _LU_ATTRS __IsBetween(long inf, long x, long sup) {return IsBetween_l(inf,x,sup);}
static inline unsigned long _LU_ATTRS __IsBetween(unsigned long inf, unsigned long x, unsigned long sup) {return IsBetween_ul(inf,x,sup);}
static inline float _LU_ATTRS __IsBetween(float inf, float x, float sup) {return IsBetween_f(inf,x,sup);}
static inline double _LU_ATTRS __IsBetween(double inf, double x, double sup) {return IsBetween_d(inf,x,sup);}

static inline char _LU_ATTRS __Clip(char inf, char x, char sup) {return Clip_c(inf, x, sup);}
static inline unsigned char _LU_ATTRS __Clip(unsigned char inf, unsigned char x, unsigned char sup) {return Clip_uc(inf, x, sup);}
static inline short _LU_ATTRS __Clip(short inf, short x, short sup) {return Clip_s(inf, x, sup);}
static inline unsigned short _LU_ATTRS __Clip(unsigned short inf, unsigned short x, unsigned short sup) {return Clip_us(inf, x, sup);}
static inline int _LU_ATTRS __Clip(int inf, int x, int sup) {return Clip_i(inf, x, sup);}
static inline unsigned int _LU_ATTRS __Clip(unsigned int inf, unsigned int x, unsigned int sup) {return Clip_ui(inf, x, sup);}
static inline long _LU_ATTRS __Clip(long inf, long x, long sup) {return Clip_l(inf, x, sup);}
static inline unsigned long _LU_ATTRS __Clip(unsigned long inf, unsigned long x, unsigned long sup) {return Clip_ul(inf, x, sup);}
static inline float _LU_ATTRS __Clip(float inf, float x, float sup) {return Clip_f(inf, x, sup);}
static inline double _LU_ATTRS __Clip(double inf, double x, double sup) {return Clip_d(inf, x, sup);}

#define IsBetween(__x, __y, __z) __IsBetween(__lu_promote3((__x), (__y), (__z))(__x), \
                                             __lu_promote3((__x), (__y), (__z))(__y), \
                                             __lu_promote3((__x), (__y), (__z))(__z))

#define Clip(__x, __y, __z) __Clip(__lu_promote3((__x), (__y), (__z))(__x), \
                                   __lu_promote3((__x), (__y), (__z))(__y), \
                                   __lu_promote3((__x), (__y), (__z))(__z))

#undef _LU_ATTRS
#undef _LU_ATTRSp
