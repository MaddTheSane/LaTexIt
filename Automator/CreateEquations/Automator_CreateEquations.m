//
//  Automator_CreateEquations.m
//  Automator_CreateEquations
//
//  Created by Pierre Chatelier on 24/09/08.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import "Automator_CreateEquations.h"

#import "KeyedUnarchiveFromDataTransformer.h"
#import "LaTeXiTSharedTypes.h"
#import "LaTeXProcessor.h"
#import "NSColorExtended.h"
#import "NSFileManagerExtended.h"
#import "NSStringExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreamblesController.h"
#import "PreferencesController.h"
#import "Utils.h"

#import <OSAKit/OSAKit.h>
#import "RegexKitLite.h"

static unsigned long firstFreeUniqueIdentifier = 1;
static NSMutableSet* freeIds = nil;

typedef enum {ALONGSIDE_INPUT, TEMPORARY_FOLDER} equationDestination_t;

@implementation Automator_CreateEquations

+(void) initialize
{
  @synchronized(self)
  {
    if (!freeIds)
    {
      freeIds = [[NSMutableSet alloc] init];
      [KeyedUnarchiveFromDataTransformer initialize];//seems needed on Tiger
    }
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
  if ((!(self = [super initWithDefinition:dict fromArchive:archived])))
    return nil;
  self->fromArchive = archived;
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
  if (!self->fromArchive) //init from latexit preferences
  {
    NSMutableDictionary* dict = [self parameters];
    PreferencesController* preferencesController = [PreferencesController sharedController];
    CFPreferencesAppSynchronize((CFStringRef)LaTeXiTAppKey);
    NSString* latexitVersion = [preferencesController latexitVersion];
    self->latexitPreferencesAvailable = (latexitVersion != nil);
    [normalView  setHidden:!self->latexitPreferencesAvailable];
    [warningView setHidden:self->latexitPreferencesAvailable];
    latex_mode_t equationMode = [preferencesController latexisationLaTeXMode];
    CGFloat      fontSize       = [preferencesController latexisationFontSize];
    NSData*      fontColorData  = [preferencesController latexisationFontColorData];
    [dict setObject:[NSNumber numberWithInt:equationMode] forKey:@"equationMode"];
    [dict setObject:[NSNumber numberWithFloat:fontSize] forKey:@"fontSize"];
    if (fontColorData)
      [dict setObject:fontColorData forKey:@"fontColorData"];
    [self setParameters:dict];
  }//end if (!self->fromArchive) //init from latexit preferences
  [self parametersUpdated];
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
  CGFloat      fontSize     = [[parameters objectForKey:@"fontSize"] floatValue];
  NSData*      fontColorData = [parameters objectForKey:@"fontColorData"];
  NSColor*     fontColor      = !fontColorData ? [NSColor blackColor] : [NSColor colorWithData:fontColorData];
  equationDestination_t equationDestination = (equationDestination_t) [[parameters objectForKey:@"equationFilesDestination"] intValue];
  NSString*    workingDirectory = [self workingDirectory];
  NSDictionary* fullEnvironment = nil;

  CFPreferencesAppSynchronize((CFStringRef)LaTeXiTAppKey);
  PreferencesController* preferencesController = [PreferencesController sharedController];
  CGFloat leftMargin   = [preferencesController marginsAdditionalLeft];
  CGFloat rightMargin  = [preferencesController marginsAdditionalRight];
  CGFloat bottomMargin = [preferencesController marginsAdditionalBottom];
  CGFloat topMargin    = [preferencesController marginsAdditionalTop];
  
  NSString* defaultPreamble = [[preferencesController preambleDocumentAttributedString] string];
  
	// Add your code here, returning the data to be passed to the next action.
  NSMutableSet* uniqueIdentifiers = [[NSMutableSet alloc] init];
  NSFileManager* fileManager      = [NSFileManager defaultManager];
  NSSet*          inputAsSet      = [NSSet setWithArray:input];
  NSMutableArray* mutableInput    = [NSMutableArray arrayWithArray:input];
  NSMutableArray* filteredInput   = [NSMutableArray arrayWithCapacity:[mutableInput count]];
  unsigned int i = 0;
  for(i = 0 ; defaultPreamble && (i<[mutableInput count]) ; ++i)
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
            NSArray* directoryContent = [fileManager bridge_contentsOfDirectoryAtPath:string error:&error];
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
  while(defaultPreamble && (object = [enumerator nextObject]))
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
        [[LaTeXProcessor sharedLaTeXProcessor] latexiseWithPreamble:preamble body:body color:fontColor mode:latexMode magnification:fontSize
          compositionConfiguration:[preferencesController compositionConfigurationDocument] backgroundColor:nil
          leftMargin:leftMargin rightMargin:rightMargin topMargin:topMargin bottomMargin:bottomMargin
          additionalFilesPaths:[preferencesController additionalFilesPaths]
          workingDirectory:workingDirectory fullEnvironment:fullEnvironment uniqueIdentifier:uniqueIdentifier
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
        [[NSWorkspace sharedWorkspace] setIcon:[[LaTeXProcessor sharedLaTeXProcessor] makeIconForData:pdfData backgroundColor:nil]
                                       forFile:outFilePath options:NSExclude10_4ElementsIconCreationOption];
        [result addObject:outFilePath];
      }
      else
      {
        NSArray* latexErrors = 
          [[LaTeXProcessor sharedLaTeXProcessor] filterLatexErrors:outFullLog shiftLinesBy:[[preamble componentsSeparatedByString:@"\n"] count]+1];
        if (didEncounterError && *errorInfo)
           [*errorInfo release];
        didEncounterError = YES;
        NSString* errorMessage = [latexErrors count] ? [latexErrors componentsJoinedByString:@"\n"] :
          NSLocalizedString(@"Unknown error. Please make sure that LaTeXiT has been run once and is fully functional.",
                            @"Unknown error. Please make sure that LaTeXiT has been run once and is fully functional.");
        *errorInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
          [NSNumber numberWithInt:errOSAGeneralError], OSAScriptErrorNumber,
          errorMessage, OSAScriptErrorMessage, nil];
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
    NSError* error = nil;
    NSString* preamble =
      [fullText stringByMatching:@"(.*)[^%\n]*\\\\begin\\{document\\}(.*)[^%\n]*\\\\end\\{document\\}(.*)" options:RKLMultiline|RKLDotAll
        inRange:NSMakeRange(0, [fullText length]) capture:1 error:&error];
    NSString* body =
      [fullText stringByMatching:@"(.*)[^%\n]*\\\\begin\\{document\\}(.*)[^%\n]*\\\\end\\{document\\}(.*)" options:RKLMultiline|RKLDotAll
        inRange:NSMakeRange(0, [fullText length]) capture:2 error:&error];
    if ((!preamble || ![preamble length]) && (!body || ![body length]))
      body = fullText;
    if (!body)     body     = @"";
    if (outPeamble) *outPeamble = preamble;
    if (outBody)    *outBody = body;
  }//end if (fullText)
  return result;
}
//end extractFromObject:preamble:body:

@end
