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
CGBlendColorsRef CGBlendColorsCreateCGF(CGColorRef colors[], NSUInteger nbColors, blendFunction_t blendFunction, CGFloat blendFunctionParameter);
CGBlendColorsRef CGBlendColorsCreate(CGColorRef colors[], NSUInteger nbColors, blendFunction_t blendFunction, CFNumberRef __nullable blendFunctionParameter);
CGBlendColorsRef CGBlendColorsRetain(CGBlendColorsRef blendColors);
void CGBlendColorsRelease(CGBlendColorsRef blendColors);

///Shadings
extern CGFunctionCallbacks CGBlendColorsFunctionCallBacks;

//Color conversions
void    RGB2HLS(CGFloat r, CGFloat g, CGFloat b, CGFloat* __nullable pH, CGFloat* __nullable pL, CGFloat* __nullable pS);
void    HLS2RGB(CGFloat h, CGFloat l, CGFloat s, CGFloat* __nullable pR, CGFloat* __nullable pG, CGFloat* __nullable pB);
CGFloat H2RGB(CGFloat v1, CGFloat v2, CGFloat vH);
void    HSV2RGB(CGFloat h, CGFloat s, CGFloat v, CGFloat* __nullable pR, CGFloat* __nullable pG, CGFloat* __nullable pB);

NS_ASSUME_NONNULL_END

#endif
