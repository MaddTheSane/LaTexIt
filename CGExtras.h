#ifndef __CGEXTRAS_H__
#define __CGEXTRAS_H__

#import <Quartz/Quartz.h>

#if NSGEOMETRY_TYPES_SAME_AS_CGGEOMETRY_TYPES
#define CGRectFromNSRect(rect) (rect)
#else
CG_INLINE CGRect CGRectFromNSRect(NSRect rect) {return CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);}
#endif

//Path
void CGContextAddRoundedRect(CGContextRef context, CGRect rect, CGFloat ovalWidth, CGFloat ovalHeight);

//color blends

typedef CGFloat (*blendFunction_t)(CGFloat, CFNumberRef parameter);
CG_INLINE CGFloat CGBlendLinear(CGFloat t, CFNumberRef parameter)
                  {return t;}
CG_INLINE CGFloat CGBlendPow(CGFloat t, CFNumberRef parameter)
                  {CGFloat value; CFNumberGetValue(parameter, kCFNumberFloatType, &value); return pow(t, value);}

typedef struct blend_colors_s* CGBlendColorsRef;
CGBlendColorsRef CGBlendColorsCreateCGF(CGColorRef colors[], NSUInteger nbColors, blendFunction_t blendFunction, CGFloat blendFunctionParameter);
CGBlendColorsRef CGBlendColorsCreate(CGColorRef colors[], NSUInteger nbColors, blendFunction_t blendFunction, CFNumberRef blendFunctionParameter);
CGBlendColorsRef CGBlendColorsRetain(CGBlendColorsRef blendColors);
void CGBlendColorsRelease(CGBlendColorsRef blendColors);

//Shadings
extern const CGFunctionCallbacks CGBlendColorsFunctionCallBacks;

//Color conversions
void    RGB2HLS(CGFloat r, CGFloat g, CGFloat b, CGFloat* pH, CGFloat* pL, CGFloat* pS);
void    HLS2RGB(CGFloat h, CGFloat l, CGFloat s, CGFloat* pR, CGFloat* pG, CGFloat* pB);
CGFloat H2RGB(CGFloat v1, CGFloat v2, CGFloat vH);

#endif
