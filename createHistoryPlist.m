//
//  createHistoryPlist.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/10/06.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[])
{
  NSAutoreleasePool* ap = [[NSAutoreleasePool alloc] init];
  
  NSString* filePath_en = @"/Users/chacha/Programmation/Cocoa/Projets/LaTeXiT-mainline/Resources/documentation/current-version-en.rtf";
  NSString* filePath_fr = @"/Users/chacha/Programmation/Cocoa/Projets/LaTeXiT-mainline/Resources/documentation/current-version-fr.rtf";
  NSString* filePath_de = @"/Users/chacha/Programmation/Cocoa/Projets/LaTeXiT-mainline/Resources/documentation/current-version-de.rtf";
  NSString* filePath_es = @"/Users/chacha/Programmation/Cocoa/Projets/LaTeXiT-mainline/Resources/documentation/current-version-es.rtf";
  NSData* rtfData_en = [NSData dataWithContentsOfFile:filePath_en];
  NSData* rtfData_fr = [NSData dataWithContentsOfFile:filePath_fr];
  NSData* rtfData_de = [NSData dataWithContentsOfFile:filePath_de];
  NSData* rtfData_es = [NSData dataWithContentsOfFile:filePath_es];

  NSDictionary* documentAttributes = nil;
  NSAttributedString* description = nil;

  documentAttributes = nil;
  description = [[[NSAttributedString alloc] initWithRTF:rtfData_en documentAttributes:&documentAttributes] autorelease];
  NSData* descriptionData_en = [NSArchiver archivedDataWithRootObject:description];

  documentAttributes = nil;
  description = [[[NSAttributedString alloc] initWithRTF:rtfData_fr documentAttributes:&documentAttributes] autorelease];
  NSData* descriptionData_fr = [NSArchiver archivedDataWithRootObject:description];

  documentAttributes = nil;
  description = [[[NSAttributedString alloc] initWithRTF:rtfData_de documentAttributes:&documentAttributes] autorelease];
  NSData* descriptionData_de = [NSArchiver archivedDataWithRootObject:description];

  documentAttributes = nil;
  description = [[[NSAttributedString alloc] initWithRTF:rtfData_es documentAttributes:&documentAttributes] autorelease];
  NSData* descriptionData_es = [NSArchiver archivedDataWithRootObject:description];
  
  NSDictionary* descriptions =
    [NSDictionary dictionaryWithObjectsAndKeys:
      descriptionData_en, @"en",
      descriptionData_fr, @"fr",
      descriptionData_de, @"de",
      descriptionData_es, @"es",
      nil];
  
  NSDictionary* newVersionDictionary =
    [NSDictionary dictionaryWithObjectsAndKeys:
       @"1.13.0", @"number",
       descriptions, @"descriptions",
       nil];
      
  NSString* errorString = nil;
  NSPropertyListFormat plistFormat;
  NSData* plistData = [NSData dataWithContentsOfFile:@"/Users/chacha/Sites/site_perso_php/programmation/fichiers/latexit-versions.plist"];
  NSMutableDictionary* plist =
    [NSPropertyListSerialization propertyListFromData:plistData
                                      mutabilityOption:NSPropertyListMutableContainers format:&plistFormat errorDescription:&errorString];
  if (![plist objectForKey:@"versions"])
    [plist setObject:[NSMutableDictionary dictionary] forKey:@"versions"];
  [[plist objectForKey:@"versions"] setObject:newVersionDictionary forKey:[newVersionDictionary objectForKey:@"number"]];
  [plist setObject:[newVersionDictionary objectForKey:@"number"] forKey:@"latestVersionId"];

  plistData = [NSPropertyListSerialization dataFromPropertyList:plist
                                                         format:NSPropertyListXMLFormat_v1_0  errorDescription:&errorString];
  [plistData writeToFile:@"/Users/chacha/Sites/site_perso_php/programmation/fichiers/latexit-versions.plist" atomically:YES];
  [ap release];
  return 0;
}
