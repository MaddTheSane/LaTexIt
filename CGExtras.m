#include "CGExtras.h"

void CGContextAddRoundedRect(CGContextRef context, CGRect rect, CGFloat ovalWidth, CGFloat ovalHeight)
{
	if ((ovalWidth == 0.) || (ovalHeight == 0.))
		CGContextAddRect(context, rect);
  else
  {
  	CGContextSaveGState(context);
    CGContextTranslateCTM(context, CGRectGetMinX(rect), CGRectGetMinY(rect));
    CGContextScaleCTM(context, ovalWidth, ovalHeight);
    CGFloat fw = CGRectGetWidth(rect) / ovalWidth;
    CGFloat fh = CGRectGetHeight(rect) / ovalHeight;
    CGContextMoveToPoint(context, fw, fh/2);  // Start at lower right corner
    CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1);  // Top right corner
    CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1); // Top left corner
    CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1); // Lower left corner
    CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1); // Back to lower right
    CGContextClosePath(context);
    CGContextRestoreGState(context);
  }//end if (ovalWidth || ovalHeight)
}
//end CGContextAddRoundedRect()

//----------------- Blend colors --------------------

typedef struct {
  NSUInteger refCount;
  CGColorRef* colors;
  NSUInteger nbColors;
  blendFunction_t blendFunction;
  CFNumberRef     blendFunctionParameter;
} blend_colors_t;

CGBlendColorsRef CGBlendColorsCreateCGF(CGColorRef colors[], NSUInteger nbColors, blendFunction_t blendFunction, CGFloat blendFunctionParameter)
{
  CGBlendColorsRef result = 0;
  CFNumberRef number = CFNumberCreate(kCFAllocatorDefault, kCFNumberFloatType, &blendFunctionParameter);
  result = CGBlendColorsCreate(colors, nbColors, blendFunction, number);
  CFRelease(number);
  return result;
}
//end CGBlendColors2CreateCGF()

CGBlendColorsRef CGBlendColorsCreate(CGColorRef colors[], NSUInteger nbColors, blendFunction_t blendFunction, CFNumberRef blendFunctionParameter)
{
  blend_colors_t* result = malloc(sizeof(blend_colors_t));
  if (result)
  {
    result->refCount = 1;
    result->nbColors = nbColors;
    result->colors = malloc(nbColors*sizeof(CGColorRef));
    if (!result->colors)
    {
      free(result);
      result = 0;
    }
    else//if (result->colors)
    {
      NSUInteger i = 0;
      for(i = 0 ; i<nbColors ; ++i)
        result->colors[i] = CGColorRetain(colors[i]);
      result->blendFunction = blendFunction;
      result->blendFunctionParameter = !blendFunctionParameter ? 0 : CFRetain(blendFunctionParameter);
    }//end if (result->colors)
  }//end if (result)
  return result;
}
//end CGBlendColorsCreate()

CGBlendColorsRef CGBlendColorsRetain(CGBlendColorsRef blendColors)
{
  blend_colors_t* blendColorsStruct = (blend_colors_t*)blendColors;
  if (blendColorsStruct && (blendColorsStruct->refCount < NSUIntegerMax))
    ++blendColorsStruct->refCount;
  return blendColorsStruct;
}
//end CGBlendColorsRetain()

void CGBlendColorsRelease(CGBlendColorsRef blendColors)
{
  blend_colors_t* blendColorsStruct = (blend_colors_t*)blendColors;
  if (blendColorsStruct && (blendColorsStruct->refCount-- <= 1))
  {
    NSUInteger i = 0;
    for(i = 0 ; i<blendColorsStruct->nbColors ; CGColorRelease(blendColorsStruct->colors[i++])) {}
    free(blendColorsStruct->colors);
    if (blendColorsStruct->blendFunctionParameter) CFRelease(blendColorsStruct->blendFunctionParameter);
    free(blendColors);
  }//end if (blendColors2struct && (result->refCount-- <= 1))
}
//end CGBlendColorsRelease()

static void CGColorBlendColorsFunctionReleaseCallBack(void *info)
{
  CGBlendColorsRelease((blend_colors_t*) info);
}
//end CGColorBlendFunctionReleaseCallBack()

static void CGColorBlendColorsFunctionCallBack(void* info, const CGFloat* inData, CGFloat* outData)
{
  blend_colors_t* blendColors = (blend_colors_t*)info;
  CGFloat t = blendColors->blendFunction(*inData, blendColors->blendFunctionParameter);
  NSUInteger prevColorIndex = !blendColors->nbColors ? 0 : (NSUInteger)MAX(0, MIN(blendColors->nbColors-1, floor(t*(blendColors->nbColors-1))));
  NSUInteger nextColorIndex = !blendColors->nbColors ? 0 : (NSUInteger)MAX(0, MIN(blendColors->nbColors-1,  ceil(t*(blendColors->nbColors-1))));
  CGFloat t2 = !blendColors->nbColors ? 0. : fmod(t*(blendColors->nbColors-1.), 1.);
  if (blendColors->nbColors)
  {
   size_t maxNbComponents = 0;
   NSUInteger i = 0;
   for(i = 0 ; i<blendColors->nbColors ; ++i)
     maxNbComponents = MAX(maxNbComponents, CGColorGetNumberOfComponents(blendColors->colors[i]));
   for(i = 0 ; i<maxNbComponents ; ++i)
    outData[i] = (1.0 - t2) * CGColorGetComponents(blendColors->colors[prevColorIndex])[i] +
                      t2    * CGColorGetComponents(blendColors->colors[nextColorIndex])[i];
  }
}
//end CGColorBlendFunctionCallBack()

CGFunctionCallbacks CGBlendColorsFunctionCallBacks = {0, &CGColorBlendColorsFunctionCallBack, &CGColorBlendColorsFunctionReleaseCallBack};

//---------------- Color conversions ----------------------

void RGB2HLS(CGFloat r, CGFloat g, CGFloat b, CGFloat* pH, CGFloat* pL, CGFloat* pS)
{
  CGFloat var_Min = MIN(MIN(r, g), b);
  CGFloat var_Max = MAX(MAX(r, g), b);
  CGFloat del_Max = var_Max - var_Min;
  CGFloat h = 0.;
  CGFloat l = (var_Max + var_Min) / 2;
  CGFloat s = 0.;
  if (del_Max > 0.)
  {
    s = (l<.5) ? del_Max / ( var_Max + var_Min ) : del_Max / ( 2 - var_Max - var_Min );
    CGFloat del_R = ( ( ( var_Max - r ) / 6 ) + ( del_Max / 2 ) ) / del_Max;
    CGFloat del_G = ( ( ( var_Max - g ) / 6 ) + ( del_Max / 2 ) ) / del_Max;
    CGFloat del_B = ( ( ( var_Max - b ) / 6 ) + ( del_Max / 2 ) ) / del_Max;
    if      ( r == var_Max ) h = del_B - del_G;
    else if ( g == var_Max ) h = ( 1 / 3 ) + del_R - del_B;
    else                         h = ( 2 / 3 ) + del_G - del_R;
    if (h < 0) h += 1.;
    else if (h > 1)  h -= 1.;
  }
  if (pH) *pH = h;
  if (pL) *pL = l;
  if (pS) *pS = s;
}
//end RGB2HLS()

void HLS2RGB(CGFloat h, CGFloat l, CGFloat s, CGFloat* pR, CGFloat* pG, CGFloat* pB)
{
  CGFloat r = l;
  CGFloat g = l;
  CGFloat b = l;
  if (s > 0.)
  {
    CGFloat var_h = h * 6;
    if ( var_h == 6. ) var_h = 0;      //H must be < 1
    NSInteger var_i = (NSInteger)var_h;            //Or ... var_i = floor( var_h )
    CGFloat var_1 = l * ( 1 - s );
    CGFloat var_2 = l * ( 1 - s * ( var_h - var_i ) );
    CGFloat var_3 = l * ( 1 - s * ( 1 - ( var_h - var_i ) ) );

    if      ( var_i == 0 ) { r = l     ; g = var_3 ; b = var_1; }
    else if ( var_i == 1 ) { r = var_2 ; g = l     ; b = var_1; }
    else if ( var_i == 2 ) { r = var_1 ; g = l     ; b = var_3; }
    else if ( var_i == 3 ) { r = var_1 ; g = var_2 ; b = l;     }
    else if ( var_i == 4 ) { r = var_3 ; g = var_1 ; b = l;     }
    else                   { r = l     ; g = var_1 ; b = var_2; }
  }//end if (s > 0.)
  if (pR) *pR = r;
  if (pG) *pG = g;
  if (pB) *pB = b;
}
//end HLS2RGB()
