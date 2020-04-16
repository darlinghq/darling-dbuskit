/** Helper functions for boxing and unboxing D-Bus types.
   Copyright (C) 2011 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: September 2011

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   */

#import "DKBoxingUtils.h"
#import "DKArgument.h"
#import "DKProxy+Private.h"

#define INCLUDE_RUNTIME_H
#import "config.h"
#undef INCLUDE_RUNTIME_H

#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSFileHandle.h>
#import <Foundation/NSValue.h>

#import <GNUstepBase/Unicode.h>

#include <dbus/dbus.h>
#include <wctype.h>
#include <stdlib.h>

Class
DKBuiltinObjCClassForDBusType(int type)
{
  switch (type)
  {
    case DBUS_TYPE_BYTE:
    case DBUS_TYPE_BOOLEAN:
    case DBUS_TYPE_INT16:
    case DBUS_TYPE_UINT16:
    case DBUS_TYPE_INT32:
    case DBUS_TYPE_UINT32:
    case DBUS_TYPE_INT64:
    case DBUS_TYPE_UINT64:
    case DBUS_TYPE_DOUBLE:
      return [NSNumber class];
    case DBUS_TYPE_STRING:
      return [NSString class];
    case DBUS_TYPE_OBJECT_PATH:
      return [DKProxy class];
    case DBUS_TYPE_SIGNATURE:
      return [DKArgument class];
    // Some DBUS_TYPE_ARRAYs will actually be dictionaries if they contain
    // DBUS_TYPE_DICT_ENTRies.
    case DBUS_TYPE_ARRAY:
    case DBUS_TYPE_STRUCT:
      return [NSArray class];
#ifdef  DBUS_TYPE_UNIX_FD
    case DBUS_TYPE_UNIX_FD:
      return [NSFileHandle class];
#endif
    // The following types have no explicit representation, they will either not
    // be handled at all, or their boxing is determined by the container resp.
    // the contained type.
    case DBUS_TYPE_INVALID:
    case DBUS_TYPE_VARIANT:
    case DBUS_TYPE_DICT_ENTRY:
    default:
      break;
  }
  return Nil;
}


int
DKDBusTypeForObjCType(const char* code)
{
  switch (*code)
  {
    case _C_BOOL:
      return DBUS_TYPE_BOOLEAN;
    case _C_CHR:
    case _C_SHT:
      return DBUS_TYPE_INT16;
    case _C_INT:
      return DBUS_TYPE_INT32;
    case _C_LNG_LNG:
      return DBUS_TYPE_INT64;
    case _C_UCHR:
      return DBUS_TYPE_BYTE;
    case _C_USHT:
      return DBUS_TYPE_UINT16;
    case _C_UINT:
      return DBUS_TYPE_UINT32;
    case _C_ULNG_LNG:
      return DBUS_TYPE_UINT64;
    case _C_FLT:
    case _C_DBL:
      return DBUS_TYPE_DOUBLE;
    case _C_CHARPTR:
      return DBUS_TYPE_STRING;
    case _C_ID:
      return DBUS_TYPE_VARIANT;
    case _C_ARY_B:
      return DBUS_TYPE_ARRAY;
    case _C_STRUCT_B:
      return DBUS_TYPE_STRUCT;
    default:
      return DBUS_TYPE_INVALID;
  }
  return DBUS_TYPE_INVALID;
}

const char*
DKUnboxedObjCTypeForDBusType(int type)
{
  switch (type)
  {
    case DBUS_TYPE_BYTE:
      return @encode(unsigned char);
    case DBUS_TYPE_BOOLEAN:
      return @encode(BOOL);
    case DBUS_TYPE_INT16:
      return @encode(int16_t);
    case DBUS_TYPE_UINT16:
      return @encode(uint16_t);
    case DBUS_TYPE_INT32:
      return @encode(int32_t);
    case DBUS_TYPE_UINT32:
      return @encode(uint32_t);
    case DBUS_TYPE_INT64:
      return @encode(int64_t);
    case DBUS_TYPE_UINT64:
      return @encode(uint64_t);
    case DBUS_TYPE_DOUBLE:
      return @encode(double);
    case DBUS_TYPE_STRING:
      return @encode(char*);
#   ifdef DBUS_TYPE_UNIX_FD
    // Qua POSIX, file descriptors are integer sized.
    case DBUS_TYPE_UNIX_FD:
      return @encode(int);
#   endif
    // We always box the following types:
    case DBUS_TYPE_OBJECT_PATH:
    case DBUS_TYPE_ARRAY:
    case DBUS_TYPE_STRUCT:
    case DBUS_TYPE_VARIANT:
      return @encode(id);
    // And because we do, the following types will never appear in a signature:
    case DBUS_TYPE_INVALID:
    case DBUS_TYPE_SIGNATURE:
    case DBUS_TYPE_DICT_ENTRY:
    default:
      return NULL;
  }
  return NULL;
}

size_t
DKUnboxedObjCTypeSizeForDBusType(int type)
{
  switch (type)
  {
    case DBUS_TYPE_BYTE:
      return sizeof(char);
    case DBUS_TYPE_BOOLEAN:
      return sizeof(BOOL);
    case DBUS_TYPE_INT16:
      return sizeof(int16_t);
    case DBUS_TYPE_UINT16:
      return sizeof(uint16_t);
    case DBUS_TYPE_INT32:
      return sizeof(int32_t);
    case DBUS_TYPE_UINT32:
      return sizeof(uint32_t);
    case DBUS_TYPE_INT64:
      return sizeof(int64_t);
    case DBUS_TYPE_UINT64:
      return sizeof(uint64_t);
    case DBUS_TYPE_DOUBLE:
      return sizeof(double);
    case DBUS_TYPE_STRING:
      return sizeof(char*);
#   ifdef DBUS_TYPE_UNIX_FD
    case DBUS_TYPE_UNIX_FD:
      return sizeof(int);
#   endif
    // We always box the following types:
    case DBUS_TYPE_OBJECT_PATH:
    case DBUS_TYPE_ARRAY:
    case DBUS_TYPE_STRUCT:
    case DBUS_TYPE_VARIANT:
      return sizeof(id);
    // And because we do, the following types will never appear in a signature:
    case DBUS_TYPE_INVALID:
    case DBUS_TYPE_SIGNATURE:
    case DBUS_TYPE_DICT_ENTRY:
    default:
      return 0;
  }
  return 0;
}

size_t
DKPrimitiveObjCTypeSize(const char* code)
{
  // Guard against NULL pointers
  if (NULL == code)
  {
    return 0;
  }

  // Guard against empty strings
  if ('\0' == *code)
  {
    return 0;
  }

  switch (*code)
  {
#   define APPLY_TYPE(typeName, name, capitalizedName, encodingChar) \
    case encodingChar: \
      return sizeof(typeName);
#   define NON_INTEGER_TYPES 1
#   include "type_encoding_cases.h"
    default:
      return 0;
  }
}

BOOL
DKDBusTypeIsIntegerType(int type)
{
  switch (type)
  {
    case DBUS_TYPE_BYTE:
    case DBUS_TYPE_BOOLEAN:
    case DBUS_TYPE_INT16:
    case DBUS_TYPE_UINT16:
    case DBUS_TYPE_INT32:
    case DBUS_TYPE_UINT32:
    case DBUS_TYPE_INT64:
    case DBUS_TYPE_UINT64:
      return YES;
    default:
      return NO;
  }
  return NO;
}


BOOL
DKObjCTypeIsIntegerType(const char* code)
{
  // Guard against NULL pointers
  if (NULL == code)
  {
    return NO;
  }

  // Guard against empty strings
  if ('\0' == *code)
  {
    return NO;
  }

  switch (*code)
  {
    case 'c':
    case 's':
    case 'i':
    case 'l':
    case 'q':
    case 'C':
    case 'B':
    case 'S':
    case 'I':
    case 'L':
    case 'Q':
      return YES;
    default:
      return NO;
  }
  return NO;
}

BOOL
DKDBusTypeIsUnsigned(int type)
{
  switch (type)
  {
    case DBUS_TYPE_UINT16:
    case DBUS_TYPE_UINT32:
    case DBUS_TYPE_UINT64:
      return YES;
    default:
      return NO;
  }
}

BOOL
DKObjCTypeIsUnsigned(const char* code)
{
  // Guard against NULL pointers
  if (NULL == code)
  {
    return NO;
  }

  // Guard against empty strings
  if ('\0' == *code)
  {
    return NO;
  }

  switch (*code)
  {
    case 'C':
    case 'S':
    case 'I':
    case 'L':
    case 'Q':
      return YES;
    default:
      return NO;
  }
  return NO;
}


BOOL
DKDBusTypeIsFPType(int type)
{
  return (DBUS_TYPE_DOUBLE == type);
}

BOOL
DKObjCTypeIsFPType(const char* code)
{
  // Guard against NULL pointers
  if (NULL == code)
  {
    return NO;
  }

  // Guard against empty strings
  if ('\0' == *code)
  {
    return NO;
  }

  switch (*code)
  {
    case 'd':
    case 'f':
      return YES;
    default:
      return NO;
  }
  return NO;
}

static inline BOOL
_DKObjCTypeFitsIntoObjCType(const char *sourceType, const char *targetType)
{
  // NOTE This function is only ever called from functions that already did
  // sanity checks on the arguments.
  BOOL sourceIsInteger = NO;
  BOOL targetIsInteger = NO;
  BOOL sourceIsFP = NO;
  BOOL targetIsFP = NO;
  BOOL sourceIsUnsigned = NO;
  BOOL targetIsUnsigned = NO;
  size_t sourceSize = 0;
  size_t targetSize = 0;


  // First test: Conversion between equal types always works.
  if (*sourceType == *targetType)
  {
    return YES;
  }

  /*
   * More complex cases. We need to gather information about the types. Of that,
   * we will always need the size.
   */
  sourceSize = DKPrimitiveObjCTypeSize(sourceType);
  targetSize = DKPrimitiveObjCTypeSize(targetType);
  sourceIsInteger = DKObjCTypeIsIntegerType(sourceType);
  targetIsInteger = DKObjCTypeIsIntegerType(targetType);

  if (sourceIsInteger && targetIsInteger)
  {
    /*
     * Both types are integers. Find out whether they are signed.
     */

    sourceIsUnsigned = DKObjCTypeIsUnsigned(sourceType);
    targetIsUnsigned = DKObjCTypeIsUnsigned(targetType);
    if (targetSize > sourceSize)
    {
      /*
       * If the type we are converting to needs more storage space than the
       * source, we're save, even if we are converting from an unsigned to a
       * signed value. But we don't claim that we can convert a signed value
       * to an unsigned.
       * FIXME: Of course we could try to examine the concrete value in every
       * case and only fail when it actually doesn't fit.
       */
      if ((sourceIsUnsigned == targetIsUnsigned)
	|| (sourceIsUnsigned && (NO == targetIsUnsigned)))
      {
	return YES;
      }
    }

    /* If both types are of equal size, we also require equal signedness. */
    if ((targetSize == sourceSize) && (sourceIsUnsigned == targetIsUnsigned))
    {
      return YES;
    }
  }

  sourceIsFP = DKObjCTypeIsFPType(sourceType);
  targetIsFP = DKObjCTypeIsFPType(targetType);

  if (sourceIsFP && targetIsFP)
  {
    /* This is easier if only floating point values are involved. */
    if (targetSize >= sourceSize)
    {
      return YES;
    }
  }
  return NO;
}

BOOL
DKDBusTypeFitsIntoObjCType(int origType, const char* objCType)
{
  const char* convertedDBusType;
  // Guard against NULL pointers
  if (NULL == objCType)
  {
    return NO;
  }

  // Guard against empty strings
  if ('\0' == *objCType)
  {
    return NO;
  }

  if (DBUS_TYPE_INVALID == origType)
  {
    return NO;
  }
  convertedDBusType = DKUnboxedObjCTypeForDBusType(origType);

  if (convertedDBusType == NULL)
  {
    return NO;
  }
  if (*convertedDBusType == '\0')
  {
    return NO;
  }
  return _DKObjCTypeFitsIntoObjCType(convertedDBusType, objCType);
}

BOOL
DKObjCTypeFitsIntoDBusType(const char *origType, int DBusType)
{
  const char* convertedDBusType;
  // Guard against NULL pointers
  if (NULL == origType)
  {
    return NO;
  }

  // Guard against empty strings
  if ('\0' == *origType)
  {
    return NO;
  }

  if (DBUS_TYPE_INVALID == DBusType)
  {
    return NO;
  }
  convertedDBusType = DKUnboxedObjCTypeForDBusType(DBusType);

  if (convertedDBusType == NULL)
  {
    return NO;
  }
  if (*convertedDBusType == '\0')
  {
    return NO;
  }
  return _DKObjCTypeFitsIntoObjCType(origType, convertedDBusType);
}

BOOL
DKObjCTypeFitsIntoObjCType(const char *sourceType, const char *targetType)
{
  // Guard against NULL pointers
  if ((NULL == sourceType) || (NULL == targetType))
  {
    return NO;
  }

  // Guard against empty strings
  if (('\0' == *sourceType) || ('\0' == *targetType))
  {
    return NO;
  }

  return _DKObjCTypeFitsIntoObjCType(sourceType, targetType);
}

NSString*
DKMethodNameFromSelectorString(const char* selString)
{
  NSString *selName = nil;
  NSUInteger length;
  BOOL charsOnStack;
  unichar stackChars[64];
  unichar *heapChars = NULL;
  if (NULL == selString)
  {
    return nil;
  }
  selName = [NSString stringWithUTF8String: selString];
  length = [selName length];
  charsOnStack = (length < 64);
  // 64 characters on the stack should be large enough most of the time.
  if (NO == charsOnStack)
  {
    heapChars = malloc(length * sizeof(unichar));
  }
  else
  {
    heapChars = &stackChars[0];
  }
  NS_DURING
  {
    [selName getCharacters: heapChars range: NSMakeRange(0,length)];

    NSUInteger i;
    for (i = 0; i < (length - 1); i++)
    {
      if(':' == heapChars[i])
      {
	// Advance the buffer, uppercase the next character
	i++;
	if (iswlower(heapChars[i]))
	{
	  heapChars[i] = uni_toupper(heapChars[i]);
	}
      }
    }
    selName = [NSString stringWithCharacters: heapChars length: length];
  }
  NS_HANDLER
  {
    if (NO == charsOnStack)
    {
      free(heapChars);
    }
    [localException raise];
  }
  NS_ENDHANDLER

  if (NO == charsOnStack)
  {
    free(heapChars);
  }
  return [selName stringByReplacingOccurrencesOfString: @":" withString: @""];

}

NSString*
DKMethodNameFromSelector(SEL selector)
{
  if (0 == selector)
  {
    return nil;
  }
  return DKMethodNameFromSelectorString(sel_getName(selector));
}


#if HAVE_LIBCLANG
NSString*
DKDBusTypeSignatureForCXType(CXType ty)
{
  int DBusType = DBUS_TYPE_INVALID;
  CXCursor tyCursor = clang_getTypeDeclaration(clang_getCanonicalType(ty));
  if (CXType_ObjCObjectPointer == ty.kind)
  {
    // Presently, we are only interested in NSString, NSArray, NSDictionary
    // and NSFileHandle in order to treat them specially.
    CXString cName = clang_getCursorSpelling(tyCursor);
    const char *clsName = clang_getCString(cName);

    // If we are lucky, the class exists in this compilation unit and we can
    // check whether it is a subclass of the well known ones.
    Class theClass = objc_getClass(clsName);

    // Ad-hoc bitfield for the checks
    // 1 < 0 : NSString
    // 1 < 1 : NSArray
    // 1 < 2 : NSDictionary
    // 1 < 3 : NSFileHandle
    // 1 < 4 : NSData
    char field = 0;

    // Prefetch class pointers
    Class string = [NSString class];
    Class array = [NSArray class];
    Class dict = [NSDictionary class];
    Class fd = [NSFileHandle class];
    Class data = [NSData class];
    // Check whether theClass inherits from one of those:
    while ((theClass != Nil) && (0 == field))
    {
      if (string == theClass)
      {
	field = 1 < 0;
      }
      else if (array == theClass)
      {
	field = 1 < 1;
      }
      else if (dict == theClass)
      {
	field = 1 < 2;
      }
      else if (fd == theClass)
      {
	field = 1 < 3;
      }
      else if (data == theClass)
      {
        field = 1 < 4;
      }
      else
      {
	// Check the superclass next time:
	theClass = class_getSuperclass(theClass);
      }
    }

    /*
     * The following code path doesn't make sense yet. But it will become
     * useful once we allow the user to specify abitrary class->type mappings.
     * Those classes might not be in Foundation/-base, so that we don't get a
     * class for them. So we need brute for name checking:
    if (0 == field)
    {
      NString *className = [NSString stringWithUTF8String: clsName];
      // brute force check...
    }
     */
    clang_disposeString(cName);

    switch (field)
    {
      case 1:
	DBusType = DBUS_TYPE_STRING;
	break;
      case 2:
	// Variant type as element because it may contain arbitrary stuff,
	// return it right away.
	return @"av";
      case 4:
	// Dicts are also arrays, but with variant dict elements in them.
	// We can also just return those.
	return @"a{vv}";
      case 8:
	DBusType = DBUS_TYPE_UNIX_FD;
	break;
      case 16:
        // NSData is converted to byte arrays on the bus
	return @"ay";
      default:
        break;
    }

  }
  else
  {
    CXString encoding = clang_getDeclObjCTypeEncoding(tyCursor);
    DBusType = DKDBusTypeForObjCType(clang_getCString(encoding));
    clang_disposeString(encoding);
  }


  // These come from C structs or arrays, we don't handle them yet because we
  // are too lazy to do the alignment etc.
  if ((DBUS_TYPE_STRUCT == DBusType) ||
    (DBUS_TYPE_ARRAY == DBusType))
  {
    DBusType = DBUS_TYPE_VARIANT;
  }

  if (DBUS_TYPE_INVALID == DBusType)
  {
    return nil;
  }

  return [NSString stringWithFormat: @"%c", (char)DBusType];

}
#endif
