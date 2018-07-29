#ifndef __CGEXTRAS_H__
#define __CGEXTRAS_H__

#import <Quartz/Quartz.h>

NS_ASSUME_NONNULL_BEGIN

CG_INLINE CGRect CGRectFromNSRect(NSRect rect) {return CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);}

///Path
void CGContextAddRoundedRect(CGContextRef context, CGRect rect, CGFloat ovalWidth, CGFloat ovalHeight);

//color blends

typedef CGFloat (*blendFunction_t)(CGFloat, CFNumberRef parameter);
CG_INLINE CGFloat CGBlendLinear(CGFloat t, CFNumberRef parameter)
                  {return t;}
CG_INLINE CGFloat CGBlendPow(CGFloat t, CFNumberRef parameter)
                  {double value; CFNumberGetValue(parameter, kCFNumberDoubleType, &value); return pow(t, value);}

typedef struct blend_colors_t* CGBlendColorsRef;

CF_IMPLICIT_BRIDGING_ENABLED

CGBlendColorsRef CGBlendColorsCreateCGF(CGColorRef _Nonnull colors[_Nonnull], NSUInteger nbColors, blendFunction_t blendFunction, CGFloat blendFunctionParameter);

CF_IMPLICIT_BRIDGING_DISABLED

CGBlendColorsRef CGBlendColorsCreate(CGColorRef _Nonnull colors[_Nonnull], NSUInteger nbColors, blendFunction_t blendFunction, CFNumberRef __nullable blendFunctionParameter) CF_RETURNS_RETAINED;
CGBlendColorsRef CGBlendColorsRetain(CGBlendColorsRef blendColors);

CF_IMPLICIT_BRIDGING_ENABLED

void CGBlendColorsRelease(CGBlendColorsRef blendColors);

///Shadings
extern CGFunctionCallbacks CGBlendColorsFunctionCallBacks;

//Color conversions
void    RGB2HLS(CGFloat r, CGFloat g, CGFloat b, CGFloat* __nullable pH, CGFloat* __nullable pL, CGFloat* __nullable pS);
void    HLS2RGB(CGFloat h, CGFloat l, CGFloat s, CGFloat* __nullable pR, CGFloat* __nullable pG, CGFloat* __nullable pB);
CGFloat H2RGB(CGFloat v1, CGFloat v2, CGFloat vH);

CF_IMPLICIT_BRIDGING_DISABLED


NS_ASSUME_NONNULL_END

#endif
