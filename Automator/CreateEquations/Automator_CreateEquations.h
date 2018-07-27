//
//  Automator_CreateEquations.h
//  Automator_CreateEquations
//
//  Created by Pierre Chatelier on 24/09/08.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Automator/AMBundleAction.h>

@interface Automator_CreateEquations : AMBundleAction 
{
  IBOutlet NSView* normalView;
  IBOutlet NSView* warningView;
  BOOL latexitPreferencesAvailable;
  unsigned int uniqueId;
  BOOL fromArchive;
}

-(id) runWithInput:(id)input fromAction:(AMAction*)anAction error:(NSDictionary**)errorInfo;
-(NSString*) extractFromObject:(id)object preamble:(NSString**)outPeamble body:(NSString**)outBody isFilePath:(BOOL*)isFilePath
                         error:(NSError**)error;

@end
