//
//  CHProtoBuffers.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 11/11/13.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "CHProtoBuffers.h"

#if USE_PROTOBUFFERS
#import <CHProtobuf/CHProtobuf.h>
#endif

#import "NSObjectExtended.h"
#import "NSStringExtended.h"

@implementation CHProtoBuffers

#if USE_PROTOBUFFERS
void parseFields(const google::protobuf::UnknownFieldSet& unknown_fields, NSMutableArray* outputPlist)
{
  for(NSInteger i = 0; i < unknown_fields.field_count(); i++)
  {
    const google::protobuf::UnknownField& field = unknown_fields.field(i);
    NSInteger fieldNumber = field.number();
    switch (field.type())
    {
      case google::protobuf::UnknownField::TYPE_VARINT: {
        uint64 value = field.varint();
        [outputPlist addObject:[NSDictionary dictionaryWithObjectsAndKeys:
          @(value),
          @(fieldNumber),
          nil]];
        }
        break;
      case google::protobuf::UnknownField::TYPE_FIXED32: {
        uint32 value = field.fixed32();
        [outputPlist addObject:[NSDictionary dictionaryWithObjectsAndKeys:
          @(value),
          @(fieldNumber),
          nil]];
        }
        break;
      case google::protobuf::UnknownField::TYPE_FIXED64: {
        uint64 value = field.fixed64();
        [outputPlist addObject:[NSDictionary dictionaryWithObjectsAndKeys:
          @(value),
          @(fieldNumber),
          nil]];
        }
        break;
      case google::protobuf::UnknownField::TYPE_LENGTH_DELIMITED: {
        const std::string& value = field.length_delimited();
        google::protobuf::UnknownFieldSet embedded_unknown_fields;
        if (!value.empty() && embedded_unknown_fields.ParseFromString(value))
        {
          NSMutableArray* subFields = [NSMutableArray array];
          [outputPlist addObject:[NSDictionary dictionaryWithObjectsAndKeys:
            subFields,
            @(fieldNumber),
            nil]];
          parseFields(embedded_unknown_fields, subFields);
        }
        else
        {
          NSString* s = [[[NSString alloc] initWithUTF8String:value.c_str()] autorelease];
          [outputPlist addObject:[NSDictionary dictionaryWithObjectsAndKeys:
            s,
            @(fieldNumber),
            nil]];
        }
        }
        break;
      case google::protobuf::UnknownField::TYPE_GROUP: {
          NSMutableArray* subFields = [NSMutableArray array];
          [outputPlist addObject:[NSDictionary dictionaryWithObjectsAndKeys:
            subFields,
            @(fieldNumber),
            nil]];
          parseFields(field.group(), subFields);
        }
        break;
    }//end switch
  }//end for each field
}
//end parseFields()

void parsePlist(id plist, NSString** outPdfFileName, NSString** outUUID)
{
  NSArray* array = nil;
  NSDictionary* dict = nil;
  if ((array = [plist dynamicCastToClass:[NSArray class]]))
  {
    NSEnumerator* enumerator = [array objectEnumerator];
    id object = nil;
    while((object = [enumerator nextObject]))
    {
      NSString* s = [object dynamicCastToClass:[NSString class]];
      if ([s endsWith:@".pdf" options:NSCaseInsensitiveSearch] && outPdfFileName)
        *outPdfFileName = s;
      else if (s && outUUID)
        *outUUID = s;
      else
        parsePlist(object, outPdfFileName, outUUID);
    }//end for each object
  }//end if ((array = [plist dynamicCastToClass:[NSArray class]]))
  else if ((dict = [plist dynamicCastToClass:[NSDictionary class]]))
  {
    NSEnumerator* keyEnumerator = [dict keyEnumerator];
    id key = nil;
    while((key = [keyEnumerator nextObject]))
    {
      id object = [dict objectForKey:key];
      NSString* s = [object dynamicCastToClass:[NSString class]];
      if ([s endsWith:@".pdf" options:NSCaseInsensitiveSearch] && outPdfFileName)
        *outPdfFileName = s;
      else if (s && outUUID)
        *outUUID = s;
      else
        parsePlist(object, outPdfFileName, outUUID);
    }//end for each object
  }//end if ((dict = [plist dynamicCastToClass:[NSDictionary class]]))
}
//end parsePlist()
#endif

+(void) parseData:(NSData*)data outPdfFileName:(NSString**)outPdfFileName outUUID:(NSString**)outUUID
{
  #if USE_PROTOBUFFERS
  if ([data length])
  {
    try{
      google::protobuf::io::ArrayInputStream ais(((const char*)[data bytes])+1, [data length]-1);
      google::protobuf::DescriptorPool pool;
      google::protobuf::FileDescriptorProto file;
      file.set_name("empty_message.proto");
      file.add_message_type()->set_name("EmptyMessage");
      pool.BuildFile(file);
      std::string codec_type = "EmptyMessage";
      const google::protobuf::Descriptor* type = pool.FindMessageTypeByName(codec_type);
      google::protobuf::DynamicMessageFactory dynamic_factory(&pool);
      google::protobuf::scoped_ptr<google::protobuf::Message> message(dynamic_factory.GetPrototype(type)->New());
      bool b1 = message->ParsePartialFromZeroCopyStream(&ais);
      bool b2 = message->IsInitialized();
      const google::protobuf::Reflection* reflection = message->GetReflection();
      std::vector<const google::protobuf::FieldDescriptor*> fields;
      reflection->ListFields(*message, &fields);
      const google::protobuf::UnknownFieldSet& unknown_fields = reflection->GetUnknownFields(*message);
      NSMutableArray* plist = [NSMutableArray array];
      parseFields(unknown_fields, plist);
      NSString* pdfFileName = nil;
      NSString* uuid = nil;
      parsePlist(plist, outPdfFileName, outUUID);
    }
    catch(...){
    }
  }//end if ([data length])
  #endif
}
//end parseData:outPdfFileName:outUUID:

@end
