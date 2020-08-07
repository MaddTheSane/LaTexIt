//
//  Utils.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 15/03/06.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

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

#define NSAppKitVersionNumber10_4 824
#define NSAppKitVersionNumber10_5 949
#define NSAppKitVersionNumber10_6 1038
#define NSAppKitVersionNumber10_7 1110
#define NSAppKitVersionNumber10_8 1187
#define NSAppKitVersionNumber10_9 1265
#define NSAppKitVersionNumber10_10 1343
#define NSAppKitVersionNumber10_11 1404
#define NSAppKitVersionNumber10_12 1504
#define NSAppKitVersionNumber10_13 1561
#define NSAppKitVersionNumber10_14 1671

BOOL isMacOS10_5OrAbove(void);
BOOL isMacOS10_6OrAbove(void);
BOOL isMacOS10_7OrAbove(void);
BOOL isMacOS10_8OrAbove(void);
BOOL isMacOS10_9OrAbove(void);
BOOL isMacOS10_10OrAbove(void);
BOOL isMacOS10_11OrAbove(void);
BOOL isMacOS10_12OrAbove(void);
BOOL isMacOS10_13OrAbove(void);
BOOL isMacOS10_14OrAbove(void);
BOOL isMacOS10_15OrAbove(void);

extern NSString* NSAppearanceDidChangeNotification;

FOUNDATION_STATIC_INLINE          char  IsBetween_c(char inf, char x, char sup) {return (inf <= x) && (x <= sup);}
FOUNDATION_STATIC_INLINE unsigned char  IsBetween_uc(unsigned char inf, unsigned char x, unsigned char sup) {return (inf <= x) && (x <= sup);}
FOUNDATION_STATIC_INLINE          short IsBetween_s(short inf, short x, short sup) {return (inf <= x) && (x <= sup);}
FOUNDATION_STATIC_INLINE unsigned short IsBetween_us(unsigned short inf, unsigned short x, unsigned short sup) {return (inf <= x) && (x <= sup);}
FOUNDATION_STATIC_INLINE          int   IsBetween_i(int inf, int x, int sup) {return (inf <= x) && (x <= sup);}
FOUNDATION_STATIC_INLINE unsigned int   IsBetween_ui(unsigned int inf, unsigned int x, unsigned int sup) {return (inf <= x) && (x <= sup);}
FOUNDATION_STATIC_INLINE     NSInteger  IsBetween_nsi(NSInteger inf, NSInteger x, NSInteger sup) {return (inf <= x) && (x <= sup);}
FOUNDATION_STATIC_INLINE    NSUInteger  IsBetween_nsui(NSUInteger inf, NSUInteger x, NSUInteger sup) {return (inf <= x) && (x <= sup);}
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
FOUNDATION_STATIC_INLINE    NSInteger   Clip_nsi(NSInteger inf, NSInteger x, NSInteger sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
FOUNDATION_STATIC_INLINE   NSUInteger   Clip_nsui(NSUInteger inf, NSUInteger x, NSUInteger sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
FOUNDATION_STATIC_INLINE          long  Clip_l(long inf, long x, long sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
FOUNDATION_STATIC_INLINE unsigned long  Clip_ul(unsigned long inf, unsigned long x, unsigned long sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
FOUNDATION_STATIC_INLINE          float Clip_f(float inf, float x, float sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
FOUNDATION_STATIC_INLINE      CGFloat Clip_cgf(CGFloat inf, CGFloat x, CGFloat sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}
FOUNDATION_STATIC_INLINE         double Clip_d(double inf, double x, double sup) {return (x<inf) ? inf : (sup<x) ? sup : x;}

NSString* GetMySVGPboardType(void);
NSString* GetWebURLsWithTitlesPboardType(void);
latex_mode_t validateLatexMode(latex_mode_t mode);
NSString* getUTIForExportFormat(export_format_t exportFormat);
NSString* getFileExtensionForExportFormat(export_format_t exportFormat);

FOUNDATION_EXTERN int EndianI_BtoN(int x);
FOUNDATION_EXTERN int EndianI_NtoB(int x);
FOUNDATION_EXTERN unsigned int EndianUI_BtoN(unsigned int x);
FOUNDATION_EXTERN unsigned int EndianUI_NtoB(unsigned int x);
FOUNDATION_EXTERN long EndianL_BtoN(long x);
FOUNDATION_EXTERN long EndianL_NtoB(long x);
FOUNDATION_EXTERN unsigned long EndianUL_BtoN(unsigned long x);
FOUNDATION_EXTERN unsigned long EndianUL_NtoB(unsigned long x);

FOUNDATION_STATIC_INLINE NSString* NSStringWithNilDefault(NSString* s, NSString* nilDefault) {return !s ? nilDefault : s;}
NSString* makeStringDifferent(NSString* string, NSArray* otherStrings, BOOL* didChange);

FOUNDATION_STATIC_INLINE NSRect NSRectDelta(NSRect rect, CGFloat deltaX, CGFloat deltaY, CGFloat deltaWidth, CGFloat deltaHeight)
{return NSMakeRect(rect.origin.x+deltaX, rect.origin.y+deltaY, rect.size.width+deltaWidth, rect.size.height+deltaHeight);}

FOUNDATION_STATIC_INLINE NSRect NSRectChange(NSRect rect, BOOL setX, float newX, BOOL setY, float newY,
                                             BOOL setWidth, float newWidth, BOOL setHeight, float newHeight)
{return NSMakeRect(setX ? newX : rect.origin.x, setY ? newY : rect.origin.y,
                   setWidth ? newWidth : rect.size.width, setHeight ? newHeight : rect.size.height);}

NSRect adaptRectangle(NSRect rectangle, NSRect containerRectangle, BOOL allowScaleDown, BOOL allowScaleUp, BOOL integerScale);
NSComparisonResult compareVersions(NSString* version1, NSString* version2);

void MethodSwizzle(Class aClass, SEL orig_sel, SEL alt_sel, BOOL isInstanceMethod);
