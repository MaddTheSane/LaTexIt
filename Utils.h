//
//  Utils.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 15/03/06.
//  Copyright 2006 Pierre Chatelier. All rights reserved.
//

#import "AppController.h"

#import <Cocoa/Cocoa.h>

NSString* GetMyPNGPboardType(void);
latex_mode_t validateLatexMode(latex_mode_t mode);
int indexOfLatexMode(latex_mode_t mode);
latex_mode_t latexModeForIndex(int index);

FOUNDATION_EXTERN_INLINE int EndianI_BtoN(int x);
FOUNDATION_EXTERN_INLINE int EndianI_NtoB(int x);
FOUNDATION_EXTERN_INLINE unsigned int EndianUI_BtoN(unsigned int x);
FOUNDATION_EXTERN_INLINE unsigned int EndianUI_NtoB(unsigned int x);
FOUNDATION_EXTERN_INLINE long EndianL_BtoN(long x);
FOUNDATION_EXTERN_INLINE long EndianL_NtoB(long x);
FOUNDATION_EXTERN_INLINE unsigned long EndianUL_BtoN(unsigned long x);
FOUNDATION_EXTERN_INLINE unsigned long EndianUL_NtoB(unsigned long x);

@interface Utils : NSObject {
}

+(BOOL) createDirectoryPath:(NSString*)path attributes:(NSDictionary*)attributes;
+(NSString*) localizedPath:(NSString*)path;

@end
