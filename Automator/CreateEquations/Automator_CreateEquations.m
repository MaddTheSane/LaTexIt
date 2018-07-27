//
//  Automator_CreateEquations.m
//  Automator_CreateEquations
//
//  Created by Pierre Chatelier on 24/09/08.
//  Copyright 2008 LAIC. All rights reserved.
//

#import "Automator_CreateEquations.h"

#import "LaTeXiTPreferencesKeys.h"
#import "LaTeXiTSharedTypes.h"

#import "LatexProcessor.h"

#import "NSColorExtended.h"
#import "NSStringExtended.h"
#import "PreamblesController.h"

#import <Bridge10_5/Bridge10_5.h>

#import <OSAKit/OSAKit.h>
#import <OgreKit/OgreKit.h>

static unsigned long firstFreeUniqueIdentifier = 1;
static NSMutableSet* freeIds = nil;

typedef enum {ALONGSIDE_INPUT, TEMPORARY_FOLDER} equationDestination_t;

@implementation Automator_CreateEquations

+(void) initialize
{
  @synchronized(self)
  {
    if (!freeIds)
      freeIds = [[NSMutableSet alloc] init];
  }
}
//end initialize

+(unsigned long) getNewIdentifier
{
  unsigned long result = 0;
  @synchronized(freeIds)
  {
    if ([freeIds count])
      result = [[freeIds anyObject] unsignedLongValue];
    else
      result = firstFreeUniqueIdentifier++;
  }
  return result;
}
//end getNewIdentifier

+(void) releaseIdentifier:(unsigned long)identifier
{
  @synchronized(freeIds)
  {
    if (identifier+1 == firstFreeUniqueIdentifier)
      --firstFreeUniqueIdentifier;
    else
      [freeIds addObject:[NSNumber numberWithUnsignedLong:identifier]];
  }
}
//end getNewIdentifier

-(NSString*) workingDirectory
{
  NSString* temporaryPath =
    [NSTemporaryDirectory() stringByAppendingPathComponent:
      [NSString stringWithFormat:@"latexit-automator-%u", self->uniqueId]];
  NSFileManager* fileManager = [NSFileManager defaultManager];
  BOOL isDirectory = NO;
  BOOL exists = [fileManager fileExistsAtPath:temporaryPath isDirectory:&isDirectory];
  if (exists && !isDirectory)
  {
    [fileManager removeFileAtPath:temporaryPath handler:NULL];
    exists = NO;
  }
  if (!exists)
    [fileManager createDirectoryAtPath:temporaryPath attributes:nil];
  return temporaryPath;
}
//end workingDirectory

-(id) initWithDefinition:(NSDictionary*)dict fromArchive:(BOOL)archived
{
  if (![super initWithDefinition:dict fromArchive:archived])
    return nil;
  self->uniqueId = [[self class] getNewIdentifier];
  return self;
}
//end initWithDefinition:fromArchive:

-(void) dealloc
{
  [[self class] releaseIdentifier:self->uniqueId];
  [super dealloc];
}
//end dealloc

-(void) opened
{
  NSMutableDictionary* dict = [self parameters];
  CFStringRef appKey = (CFStringRef)@"fr.club.ktd.LaTeXiT";
  NSString* latexitVersion = (NSString*)CFPreferencesCopyAppValue((CFStringRef)LaTeXiTVersionKey, appKey);
  self->latexitPreferencesAvailable = (latexitVersion != nil);
  [normalView  setHidden:!self->latexitPreferencesAvailable];
  [warningView setHidden:self->latexitPreferencesAvailable];
  Boolean ok = CFPreferencesSynchronize(appKey, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
  latex_mode_t equationMode = CFPreferencesGetAppIntegerValue((CFStringRef)DefaultModeKey, appKey, &ok);
  if (!ok)     equationMode = LATEX_MODE_EQNARRAY;
  NSNumber*    fontSizeNumber = (NSNumber*)CFPreferencesCopyAppValue((CFStringRef)DefaultPointSizeKey, appKey);
  float        fontSize       = !fontSizeNumber ? 36.f : [fontSizeNumber floatValue];
  NSData*      fontColorData  = (NSData*)CFPreferencesCopyAppValue((CFStringRef)DefaultColorKey, appKey);
  NSColor*     fontColor      = !fontColorData ? [NSColor blackColor] : [NSColor colorWithData:fontColorData];
  [dict setValue:[NSNumber numberWithInt:equationMode] forKey:@"equationMode"];
  [dict setValue:[NSNumber numberWithFloat:fontSize] forKey:@"fontSize"];
  [dict setValue:fontColor forKey:@"fontColor"];
  [self setParameters:dict];
  [self updateParameters];
  [super opened];
}
//end opened

-(void) awakeFromBundle
{
}
//end awakeFromBundle

-(id) runWithInput:(id)input fromAction:(AMAction*)anAction error:(NSDictionary**)errorInfo
{
  NSMutableArray* result = [[[NSMutableArray alloc] initWithCapacity:[input count]] autorelease];
  NSDictionary* parameters = [self parameters];
  latex_mode_t equationMode = (latex_mode_t)[[parameters objectForKey:@"equationMode"] intValue];
  float        fontSize     = [[parameters objectForKey:@"fontSize"] floatValue];
  NSColor*     fontColor    = [parameters objectForKey:@"fontColor"];
  equationDestination_t equationDestination = (equationDestination_t) [[parameters objectForKey:@"equationFilesDestination"] intValue];
  NSString*    workingDirectory = [self workingDirectory];
  NSDictionary* fullEnvironment = nil;
  Boolean ok = NO;
  CFStringRef appKey = (CFStringRef)@"fr.club.ktd.LaTeXiT";
  BOOL useLoginShell = CFPreferencesGetAppBooleanValue((CFStringRef)UseLoginShellKey, appKey, &ok);
  NSArray* compositionConfigurations = (NSArray*)
    CFPreferencesCopyAppValue((CFStringRef)CompositionConfigurationsKey, appKey);
  int compositionConfigurationIndex = CFPreferencesGetAppIntegerValue(
    (CFStringRef)CurrentCompositionConfigurationIndexKey, appKey, &ok);
  NSDictionary* configuration = (!ok || (compositionConfigurationIndex<0) ||
                                 ((unsigned)compositionConfigurationIndex >= [compositionConfigurations count])) ? nil :
                                [compositionConfigurations objectAtIndex:compositionConfigurationIndex];
  composition_mode_t compositionMode =
    [[configuration objectForKey:CompositionConfigurationCompositionModeKey] intValue];
  NSString* pdfLatexPath = [configuration objectForKey:CompositionConfigurationPdfLatexPathKey];
  NSString* xeLatexPath = [configuration objectForKey:CompositionConfigurationXeLatexPathKey];
  NSString* latexPath = [configuration objectForKey:CompositionConfigurationLatexPathKey];
  NSString* dviPdfPath = [configuration objectForKey:CompositionConfigurationDvipdfPathKey];
  NSString* gsPath = [configuration objectForKey:CompositionConfigurationGsPathKey];
  NSString* ps2PdfPath = [configuration objectForKey:CompositionConfigurationPs2PdfPathKey];
  NSDictionary* additionalProcessingScripts =
    [configuration objectForKey:CompositionConfigurationAdditionalProcessingScriptsKey];
  float leftMargin   = [(id)CFPreferencesCopyAppValue((CFStringRef)AdditionalLeftMarginKey, appKey) floatValue];
  float rightMargin  = [(id)CFPreferencesCopyAppValue((CFStringRef)AdditionalRightMarginKey, appKey) floatValue];
  float bottomMargin = [(id)CFPreferencesCopyAppValue((CFStringRef)AdditionalBottomMarginKey, appKey) floatValue];
  float topMargin    = [(id)CFPreferencesCopyAppValue((CFStringRef)AdditionalTopMarginKey, appKey) floatValue];
  
  NSArray* preambles = (NSArray*) CFPreferencesCopyAppValue((CFStringRef)PreamblesKey, appKey);
  int selectedPreambleIndex = CFPreferencesGetAppIntegerValue(
    (CFStringRef)LatexisationSelectedPreambleIndexKey, appKey, &ok);
  id defaultPreambleAsPlist = (!ok || (selectedPreambleIndex<0) ||
                              ((unsigned)selectedPreambleIndex >= [preambles count])) ? nil :
                              [preambles objectAtIndex:selectedPreambleIndex];
  NSDictionary* defaultPreambleAsDictionary = [PreamblesController decodePreamble:defaultPreambleAsPlist];
  NSAttributedString* defaultPreambleAsAttributedString = [defaultPreambleAsDictionary objectForKey:@"value"];
  NSString* defaultPreamble = [defaultPreambleAsAttributedString string];
  
	// Add your code here, returning the data to be passed to the next action.
  NSMutableSet* uniqueIdentifiers = [[NSMutableSet alloc] init];
  NSFileManager* fileManager = [NSFileManager defaultManager];
  NSSet*          inputAsSet    = [NSSet setWithArray:input];
  NSMutableArray* mutableInput  = [NSMutableArray arrayWithArray:input];
  NSMutableArray* filteredInput = [NSMutableArray arrayWithCapacity:[mutableInput count]];
  unsigned int i = 0;
  for(i = 0 ; configuration && (i<[mutableInput count]) ; ++i)
  {
    id object = [mutableInput objectAtIndex:i];
    NSString* string = [object isKindOfClass:[NSString class]] ? (NSString*) object : nil;
    if (!string)
      [filteredInput addObject:object];
    else//if (string)
    {
      BOOL isDirectory = NO;
      if (![fileManager fileExistsAtPath:string isDirectory:&isDirectory])
        [filteredInput addObject:object];//if !path
      else//if path
      {
        if (!isDirectory)
        {//keep it if it is a file text
          if ([[NSWorkspace sharedWorkspace] filenameExtension:[string pathExtension] isValidForType:@"public.text"])
            [filteredInput addObject:object];
        }
        else //if (isDirectory)
        {//if this folder was embedded in a previous folder,forget it. otherwise, explore it
          if ([inputAsSet containsObject:object])
          {
            NSError* error = nil;
            NSArray* directoryContent = [fileManager contentsOfDirectoryAtPath:string error:&error];
            NSEnumerator* fileEnumerator = [directoryContent objectEnumerator];
            NSString* filename = nil;
            while((filename = [fileEnumerator nextObject]))
              [mutableInput addObject:[string stringByAppendingPathComponent:filename]];
          }//end if root-level folder
        }//end if folder
      }//end if path
    }//end if string
  }//end for each input
  
  BOOL didEncounterError = NO;
  NSEnumerator* enumerator = [filteredInput objectEnumerator];
  id object = nil;
  while(configuration && (object = [enumerator nextObject]))
  {
    NSAutoreleasePool* ap = [[NSAutoreleasePool alloc] init];
    NSString* preamble = nil;
    NSString* body     = nil;
    NSError*  error    = nil;
    BOOL      isInputFilePath = NO;
    NSString* uniqueIdentifierPrefix = [self extractFromObject:object preamble:&preamble body:&body isFilePath:&isInputFilePath error:&error];
    NSString* uniqueIdentifier = uniqueIdentifierPrefix;
    unsigned long index = 1;
    while ([uniqueIdentifiers containsObject:uniqueIdentifier])
      uniqueIdentifier = [NSString stringWithFormat:@"%@-%u", uniqueIdentifierPrefix, ++index];
    [uniqueIdentifiers addObject:uniqueIdentifier];
    if (!body)
    {
      *errorInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
        [NSNumber numberWithInt:errOSAGeneralError], OSAScriptErrorNumber,
        [error localizedDescription], OSAScriptErrorMessage, nil];
      didEncounterError = YES;
    }
    else
    {
      latex_mode_t latexMode = preamble ? LATEX_MODE_TEXT : equationMode;
      if (!preamble)
        preamble = defaultPreamble;
      NSString* outFullLog = nil;
      NSArray*  errors = nil;
      NSData*   pdfData = nil;
      NSString* outFilePath =
        [LatexProcessor latexiseWithPreamble:preamble body:body color:fontColor mode:latexMode magnification:fontSize
                           compositionMode:compositionMode workingDirectory:workingDirectory uniqueIdentifier:uniqueIdentifier
                           additionalFilepaths:nil fullEnvironment:fullEnvironment useLoginShell:useLoginShell
                                  pdfLatexPath:pdfLatexPath xeLatexPath:xeLatexPath latexPath:latexPath
                                    dviPdfPath:dviPdfPath gsPath:gsPath ps2PdfPath:ps2PdfPath
                                    leftMargin:leftMargin rightMargin:rightMargin
                                     topMargin:topMargin bottomMargin:bottomMargin
                               backgroundColor:nil additionalProcessingScripts:additionalProcessingScripts
                                   outFullLog:&outFullLog outErrors:&errors outPdfData:&pdfData];
      if (outFilePath && ![errors count])
      {
        if (isInputFilePath && (equationDestination == ALONGSIDE_INPUT))
        {
          NSString* destinationFolder = [object stringByDeletingLastPathComponent];
          NSString* newPath = [destinationFolder stringByAppendingPathComponent:[outFilePath lastPathComponent]];
          if (![outFilePath isEqualToString:newPath])
          {
            if ([fileManager movePath:outFilePath toPath:newPath handler:0])
              outFilePath = newPath;
          }
        }
        [fileManager changeFileAttributes:
          [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:'LTXt'] forKey:NSFileHFSCreatorCode]
                                   atPath:outFilePath];
        unsigned int options = 0;
        #ifndef PANTHER
        options = NSExclude10_4ElementsIconCreationOption;
        #endif
        [[NSWorkspace sharedWorkspace] setIcon:[LatexProcessor makeIconForData:pdfData backgroundColor:nil]
                                       forFile:outFilePath options:options];
        [result addObject:outFilePath];
      }
      else
      {
        NSArray* latexErrors = 
          [LatexProcessor filterLatexErrors:outFullLog shiftLinesBy:[[preamble componentsSeparatedByString:@"\n"] count]+1];
        if (didEncounterError && *errorInfo)
           [*errorInfo release];
        didEncounterError = YES;
        *errorInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
          [NSNumber numberWithInt:errOSAGeneralError], OSAScriptErrorNumber,
          [latexErrors componentsJoinedByString:@"\n"], OSAScriptErrorMessage, nil];
      }
    }//end if (!body)
    [ap release];
  }//end or each object
  if (didEncounterError && *errorInfo)
  {
    [*errorInfo autorelease];
    if ([filteredInput count] > 1)//cancel errors if multiple input
      *errorInfo = nil;
  }
  [uniqueIdentifiers release];
	return result;
}
//end runWithInput:fromAction:error:

-(NSString*) extractFromObject:(id)object preamble:(NSString**)outPeamble body:(NSString**)outBody isFilePath:(BOOL*)isFilePath
                         error:(NSError**)error
{
  NSString* result = nil;
  NSString* fullText = nil;
  
  //extract fullText
  if ([object isKindOfClass:[NSString class]])
  {
    BOOL isDirectory = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:object isDirectory:&isDirectory])
    {//path
      if (isFilePath) *isFilePath = !isDirectory;
      NSStringEncoding encoding = NSUTF8StringEncoding;
      fullText = [NSString stringWithContentsOfFile:object guessEncoding:&encoding error:error];
      result = [[object lastPathComponent] stringByDeletingPathExtension];
    }
    else //(if !path)
    {
      fullText = object;
      result = [NSString stringWithFormat:@"latexit-automator-%u", ++uniqueId];
    }
  }
  else if ([object isKindOfClass:[NSURL class]])
  {
    NSStringEncoding encoding = NSUTF8StringEncoding;
    fullText = [NSString stringWithContentsOfURL:object guessEncoding:&encoding error:error];
    result = [[[object absoluteString] lastPathComponent] stringByDeletingPathExtension];
  }

  //analyze fullText
  if (fullText)
  {
    OGRegularExpression* documentEnclosingWithContextRegexp =
      [OGRegularExpression regularExpressionWithString:@"(^|\n)[^%\n]*\\\\begin{document}.*\\\\end{document}"];
    OGRegularExpression* documentEnclosingRegexp =
      [OGRegularExpression regularExpressionWithString:@"[\n]*(.*)\\\\begin{document}(.*)\\\\end{document}"];
    NSArray* matches = [documentEnclosingWithContextRegexp allMatchesInString:fullText];
    if (![matches count])
    {
      if (outPeamble) *outPeamble = nil;
      if (outBody)    *outBody    = fullText;
    }
    else//if ([matches count])
    {
      NSEnumerator* matchEnumerator = [matches objectEnumerator];
      OGRegularExpressionMatch* match = nil;
      while((match = [matchEnumerator nextObject]))
      {
        NSString* matchedString = [match matchedString];
        NSString* preamble = [documentEnclosingRegexp replaceAllMatchesInString:matchedString withString:@"\\1"];
        NSString* body     = [documentEnclosingRegexp replaceAllMatchesInString:matchedString withString:@"\\2"];
        if (outPeamble) *outPeamble = preamble;
        if (outBody)    *outBody    = body;
      }//end for each match
    }//end if ([matches count])
  }//end if (fullText)
  return result;
}
//end extractFromObject:preamble:body:

@end
