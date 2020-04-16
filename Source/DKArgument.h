/** Interface for DKArgument class for boxing and unboxing D-Bus types.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: June 2010

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

   <title>DKArgument class reference</title>
   */

#import "DKIntrospectionNode.h"

#include <dbus/dbus.h>
#import "config.h"

#if HAVE_LIBCLANG
#include <clang-c/Index.h>
#endif

@class NSString, NSInvocation, NSMutableArray, NSXMLNode, DKProxy;

extern NSString *kDKArgumentDirectionIn;
extern NSString *kDKArgumentDirectionOut;


/**
 *  DKArgument encapsulates D-Bus argument information and handles
 *  serializing/unserializing to/from D-Bus to Objective-C.
 */
@interface DKArgument: DKIntrospectionNode
{
  int DBusType;
  Class objCEquivalent;
}

/**
 * Registers the selector to be used for unboxing objects to specific
 * D-Bus types. The method named by the selector may not take any arguments and
 * its return value can not exceed 8 bytes.
 */
+ (void)registerUnboxingSelector: (SEL)selector
                     forDBusType: (int)type;


#if HAVE_LIBCLANG
/**
 * Initializes the argument to be of the specified libclang type. This is a
 * convenience method that might not work for all types. It will return nil
 * in that case.
 */
- (id)initWithCXType: (CXType)type
                name: (NSString*)name
              parent: (id)parent;
#endif
/**
 * Initializes the argument with the single complete D-Bus type signature
 * described by <var>characters</var>. Returns <code>nil</code> if the signature
 * is malformed or does contain more than one complete signature.
 */
- (id) initWithDBusSignature: (const char*)characters
                        name: (NSString*)name
                      parent: (id)parent;


/**
 * Initializes the argument with the first Objective-C type code appearing in
 * <var>objCType</var>. This is a convenience method that works for some, but
 * not all types and does not examine the contents of structs or arrays.
 * Unsupported types are:
 * <list>
 *   <item><code>#</code> (class)</item>
 *   <item><code>:</code> (selector)</item>
 *   <item><code>^</code> (pointer)</item>
 *   <item><code>?</code> (unknown or function pointer)</item>
 *   <item><code>%</code> (atom)</item>
 *   <item><code>()</code> (union)</item>
 *   <item><code>!</code> (vector)</item>
 *   <item><code>j</code> (complex number)</item>
 * </list>
 */
- (id)initWithObjCType: (const char*)objCType
                  name: (NSString*)_name
                parent: (id)_parent;
/**
 * Return whether the argument is a complex one that is made up by further
 * types.
 */
- (BOOL) isContainerType;

/**
 * Return the type char to be used if the argument is not boxed to an
 * Objective-C type.
 */
- (const char*) unboxedObjCTypeChar;

/**
 * Return the size of the unboxed type.
 */
- (size_t) unboxedObjCTypeSize;

/**
 * Return the class that will represent an argument of this type.
 */
- (Class) objCEquivalent;

/**
 * Returns the D-Bus type of the argument.
 */
- (int) DBusType;

/**
 * Return the D-Bus type signature equivalent to the argument.
 */
- (NSString*) DBusTypeSignature;

/**
 * Tries to unbox the value into the buffer and returns YES if successful. Since
 * libdbus makes guarantees that all primitive types will fit into 8 bytes of
 * memory, the buffer can be statically sized to 64bit width. For string
 * arguments, the address of the unboxed string is stored in the buffer.
 */
- (BOOL) unboxValue: (id)value
         intoBuffer: (long long*)buffer;

/**
 * Returns a boxed representation of the value in buffer according to the type
 * of the DKArgument.
 */
- (id) boxedValueForValueAt: (void*)buffer;

/**
 * Used unmarshalling D-Bus messages into NSInvocations. The index argument can
 * indicate the return value if set to -1. This method does not advance the
 * iterator.
 */
- (void) unmarshallFromIterator: (DBusMessageIter*)iter
                 intoInvocation: (NSInvocation*)inv
		        atIndex: (NSInteger)index
			 boxing: (BOOL)doBox;


/**
 * Returns the boxed equivalent of the value at the iterator. This method does
 * not advance the iterator.
 */
-(id) unmarshalledObjectFromIterator: (DBusMessageIter*)iter;


/**
 * Returns a standin for a proxy for an object path argument. This method is
 * only needed by the notification center.
 */
-(id) unmarshalledProxyStandinFromIterator: (DBusMessageIter*)iter;

/**
 * Marshall a value from an NSInvocation into an D-Bus message iterator set up
 * for writing. index indicates the index of the argument (in the invocation) to
 * be marshalled into the D-Bus format (-1 indicates the return value).
 */
- (void) marshallArgumentAtIndex: (NSInteger)index
                  fromInvocation: (NSInvocation*)inv
                    intoIterator: (DBusMessageIter*)iter
                          boxing: (BOOL)doBox;

/**
 * Unboxes the object into D-Bus format and appends it to a D-Bus message by
 * means of the specified iterator.
 */
- (void) marshallObject: (id)object
           intoIterator: (DBusMessageIter*)iter;

/**
 * Returns whether the parent of the node is already an DKArgument. This might
 * matter when serialising the argument into an XML or Objective-C
 * representation.
 */
- (BOOL)isSubArgument;

/**
 * Returns an XML node representing the argument.
 */
- (NSXMLNode*)XMLNode;


/**
 * Returns an XML node representing the argument for the specified direction.
 */
- (NSXMLNode*)XMLNodeForDirection: (NSString*)direction;

@end

/**
 * Encapsulates arguments that have sub-types and may require more complex
 * strategies to box and unbox.
 */
@interface DKContainerTypeArgument: DKArgument
{
  NSMutableArray *children;
}

/**
 * Return all sub-arguments that make up this argument.
 */
- (NSArray*) children;
@end;
