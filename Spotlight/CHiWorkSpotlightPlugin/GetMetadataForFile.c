#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h> 

#include <ApplicationServices/ApplicationServices.h>

#include <syslog.h>

/* -----------------------------------------------------------------------------
   Step 1
   Set the UTI types the importer supports
  
   Modify the CFBundleDocumentTypes entry in Info.plist to contain
   an array of Uniform Type Identifiers (UTI) for the LSItemContentTypes 
   that your importer can handle
  
   ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
   Step 2 
   Implement the GetMetadataForURL function
  
   Implement the GetMetadataForURL function below to scrape the relevant
   metadata from your document and return it as a CFDictionary using standard keys
   (defined in MDItem.h) whenever possible.
   ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
   Step 3 (optional) 
   If you have defined new attributes, update schema.xml and schema.strings files
   
   The schema.xml should be added whenever you need attributes displayed in 
   Finder's get info panel, or when you have custom attributes.  
   The schema.strings should be added whenever you have custom attributes. 
 
   Edit the schema.xml file to include the metadata keys that your importer returns.
   Add them to the <allattrs> and <displayattrs> elements.
  
   Add any custom types that your importer requires to the <attributes> element
  
   <attribute name="com_mycompany_metadatakey" type="CFString" multivalued="true"/>
  
   ----------------------------------------------------------------------------- */



/* -----------------------------------------------------------------------------
    Get metadata attributes from file
   
   This function's job is to extract useful information your file format supports
   and return it as a dictionary
   ----------------------------------------------------------------------------- */
   
static void PrintCFString(const char* prefix, CFStringRef string);
static void PrintCFString(const char* prefix, CFStringRef string)
{
  unsigned char buffer[4096] = {0};
  CFIndex length = 0;
  CFStringGetBytes(string, CFRangeMake(0, CFStringGetLength(string)), kCFStringEncodingUTF8, '?', false, buffer, sizeof(buffer), &length);
  syslog(LOG_ERR|LOG_USER, "%s <%s>", prefix, buffer);
}
//end PrintCFString()

Boolean GetMetadataForURL(void* thisInterface, 
			   CFMutableDictionaryRef attributes, 
			   CFStringRef contentTypeUTI,
			   CFURLRef urlForFile)
{
    Boolean result = 0;
    openlog("LaTeXiT/CHiWorkSpotlightPlugin", 0, LOG_KERN|LOG_USER);
    PrintCFString("urlForFile", CFURLGetString(urlForFile));
    CFURLRef urlForDocumentIdentifierFile1 = !urlForFile ? 0 :
      CFURLCreateCopyAppendingPathComponent(kCFAllocatorDefault, urlForFile, CFSTR("Metadata"), true);
    PrintCFString("urlForDocumentIdentifierFile1", CFURLGetString(urlForDocumentIdentifierFile1));
    CFURLRef urlForDocumentIdentifierFile2 = !urlForDocumentIdentifierFile1 ? 0 :
      CFURLCreateCopyAppendingPathComponent(kCFAllocatorDefault, urlForDocumentIdentifierFile1, CFSTR("DocumentIdentifier"), false);
    PrintCFString("urlForDocumentIdentifierFile2", CFURLGetString(urlForDocumentIdentifierFile2));
    CGDataProviderRef dataProvider = !urlForDocumentIdentifierFile2 ? 0 :
      CGDataProviderCreateWithURL(urlForDocumentIdentifierFile2);
    syslog(LOG_ERR|LOG_USER, "dataProvider = <%p>", dataProvider);
    CFDataRef data = !dataProvider ? 0 :
      CGDataProviderCopyData(dataProvider);
    syslog(LOG_ERR|LOG_USER, "data = <%p>", data);
    CFStringRef uuid = !data ? 0 :
      CFStringCreateFromExternalRepresentation(kCFAllocatorDefault, data, kCFStringEncodingUTF8);
    syslog(LOG_ERR|LOG_USER, "uuid = <%p>", uuid);
    if (uuid)
    {
      PrintCFString("uuid", uuid);
      CFDictionaryAddValue(attributes, CFSTR("kCHiWorkDocumentUUIDKey"), uuid);
      result = 1;
      CFRelease(uuid);
    }//end if (uuid)
    if (data)
      CFRelease(data);
    CGDataProviderRelease(dataProvider);
    if (urlForDocumentIdentifierFile1)
      CFRelease(urlForDocumentIdentifierFile1);
    if (urlForDocumentIdentifierFile2)
      CFRelease(urlForDocumentIdentifierFile2);
    closelog();
    return result;
}
//end GetMetadataForURL()
