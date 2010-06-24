/** Implementation of DKMethod class for encapsulating D-Bus methods.
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

   <title>DKMethod class reference</title>
   */
#import <Foundation/NSArray.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSString.h>

#import "DKArgument.h"
#import "DKMethod.h"

#include <dbus/dbus.h>
#include <stdint.h>


DKMethod *_DKMethodIntrospect;

@implementation DKMethod

+ (void)initialize
{
  if ([DKMethod class] == self)
  {
    DKArgument *xmlOutArg = nil;
    _DKMethodIntrospect = [[DKMethod alloc] initWithMethodName: @"Introspect"
                                                     interface: @"org.freedesktop.DBus.Introspectable"
                                                        parent: nil];
    xmlOutArg = [[DKArgument alloc] initWithDBusSignature: "s"
                                                     name: @"data"
                                                   parent: _DKMethodIntrospect];
    [_DKMethodIntrospect addArgument: xmlOutArg
                           direction: DKArgumentDirectionOut];
    [xmlOutArg release];
  }
}

- (id) initWithMethodName: (NSString*)aName
                interface: (NSString*)anInterface
                   parent: (id)aParent
{
  if (nil == (self = [super initWithName: aName
                                  parent: aParent]))
  {
    return nil;
  }
  if (0 == [name length])
  {
    [self release];
    return nil;
  }
  ASSIGNCOPY(interface,anInterface);
  inArgs = [NSMutableArray new];
  outArgs = [NSMutableArray new];
  return self;
}

- (char*) returnTypeBoxed: (BOOL)doBox
{
  NSUInteger count = [outArgs count];
  if (count == 0)
  {
    // No return value, void method.
    return @encode(void);
  }
  else if ((count == 1) && (NO == doBox))
  {
    // One argument, and we don't want boxing
    return [(DKArgument*)[outArgs objectAtIndex: 0] unboxedObjCTypeChar];
  }
  else
  {
    // Multiple return value, or we want boxing anyhow.
    return @encode(id);
  }
}

- (NSMethodSignature*) methodSignatureBoxed: (BOOL)doBox
{
  /* Type-encodings are as follows:
   * <return-type><arg-frame length><type/offset pairs>
   * Nothing uses the frame length/offset information, though. So we can have a
   * less paranoid stance on the offsets and sizes and spare ourselves the work
   * of generating them.
   */

  // Initial type string containing self and _cmd.
  NSMutableString *typeString = [[NSMutableString alloc] initWithFormat: @"@0:%d", sizeof(id)];
  // Dummy offset value:
  NSUInteger offset = 8;
  NSString *fullString = nil;
  NSMethodSignature *ret = nil;

  NSEnumerator *en = [inArgs objectEnumerator];
  DKArgument *arg = nil;

  while (nil != (arg = [en nextObject]))
  {
    char *typeChar;
    if (doBox)
    {
      typeChar = @encode(id);
    }
    else
    {
      typeChar = [arg unboxedObjCTypeChar];
    }

    [typeString appendFormat: @"%s%d", typeChar, offset];
  }

  fullString = [[NSString alloc] initWithFormat: @"%s%d%@", [self returnTypeBoxed: doBox],
    offset,
    typeString];
  [typeString release];
  NSDebugMLog(@"Generated type signature '%@' for method '%@'.", fullString, name);
  ret = [NSMethodSignature signatureWithObjCTypes: [fullString UTF8String]];
  [fullString release];
  return ret;
}

- (NSMethodSignature*) methodSignature
{
  return [self methodSignatureBoxed: YES];
}

- (DKArgument*)DKArgumentAtIndex: (NSInteger)index
{
  NSArray *args = nil;
  if (index < 0)
  {
    args = outArgs;
    // Convert to positive integer:
    index *= -1;
    // Decrement to start with 0:
    index--;
  }
  else
  {
    args = inArgs;
  }

  if (index < [args count])
  {
    return [args objectAtIndex: index];
  }
  return nil;
}

- (void)addArgument: (DKArgument*)argument
          direction: (NSString*)direction
{
  if (nil == argument)
  {
    NSDebugMLog(@"Ignoring nil argument");
    return;
  }

  if ([direction isEqualToString: DKArgumentDirectionIn])
  {
    [inArgs addObject: argument];
  }
  else if ([direction isEqualToString: DKArgumentDirectionOut])
  {
    [outArgs addObject: argument];
  }
  else
  {
    NSDebugMLog(@"Ignoring argument with unkown direction '%@'.", direction);
  }
}

- (NSString*) interface
{
  return interface;
}

- (BOOL) isDeprecated
{
  return [[annotations valueForKey: @"org.freedesktop.DBus.Deprecated"] isEqualToString: @"true"];
}

- (BOOL) isOneway
{
  return [[annotations valueForKey: @"org.freedesktop.DBus.Method.NoReply"] isEqualToString: @"true"];
}


- (void) unmarshallReturnValueFromIterator: (DBusMessageIter*)iter
                            intoInvocation: (NSInvocation*)inv
                                    boxing: (BOOL)doBox
{
  NSUInteger numArgs = [outArgs count];
  if (0 == numArgs)
  {
    // Void return type, we retrun.
    return;
  }
  else if (1 == numArgs)
  {
    // Pass the iterator and the invocation to the argument, index -1 indicates
    // the return value.
    [[outArgs objectAtIndex: 0] unmarshallFromIterator: iter
                                        intoInvocation: inv
                                               atIndex: -1
                                                boxing: doBox];
  }
  else
  {
    NSMutableArray *returnValues = [NSMutableArray array];
    NSUInteger index = 0;
    NSNull *theNull = [NSNull null];
    while (index < numArgs)
    {
      // We can only support objects here, so we always get the boxed value
      id object = [[outArgs objectAtIndex: index] unmarshalledObjectFromIterator: iter];

      // Do not try to add nil objects
      if (nil == object)
      {
	object = theNull;
      }
      [returnValues addObject: object];

      /*
       * Proceed to the next value in the message, but raise an exception if
       * we are missing some.
       */
      NSAssert1(dbus_message_iter_next(iter),
        @"D-Bus message too short when unmarshalling return value for '%@'.",
	name);
      index++;
    }
    [inv setReturnValue: &returnValues];
  }

}

- (void) marshallReturnValueFromInvocation: (NSInvocation*)inv
                              intoIterator: (DBusMessageIter*)iter
                                    boxing: (BOOL)doBox
{
  NSUInteger numArgs = [outArgs count];
  if (0 == numArgs)
  {
    return;
  }
  else if (1 == numArgs)
  {
    [[outArgs objectAtIndex: 0] marshallArgumentAtIndex: -1
                                         fromInvocation: inv
                                           intoIterator: iter
                                                 boxing: doBox];
  }
  else
  {
    /*
     * For D-Bus methods with multiple out-direction arguments
     * the caller will have stored the individual values as objects in an
     * array.
     */
    NSArray *retVal = nil;
    NSUInteger retCount = 0;
    NSInteger index = 0;
    NSMethodSignature *sig = [inv methodSignature];

    // Make sure the method did return an object:
    NSAssert2((0 == strcmp(@encode(id), [sig methodReturnType])),
      @"Invalid return value when constucting D-Bus reply for '%@' on %@",
      NSStringFromSelector([inv selector]),
      [inv target]);

    [inv getReturnValue: &retVal];

    // Make sure that it responds to the needed selectors:
    NSAssert2(([retVal respondsToSelector: @selector(objectAtIndex:)]
      && [retVal respondsToSelector: @selector(count)]),
      @"Expected array return value when constucting D-Bus reply for '%@' on %@",
      NSStringFromSelector([inv selector]),
      [inv target]);

    retCount = [retVal count];

    // Make sure that the number of argument matches:
    NSAssert2((retCount == [outArgs count]),
      @"Argument number mismatch when constucting D-Bus reply for '%@' on %@",
      NSStringFromSelector([inv selector]),
      [inv target]);

    // Marshall them in order:
    while (index < retCount)
    {
      [[outArgs objectAtIndex: index] marshallObject: [retVal objectAtIndex: index]
                                        intoIterator: iter];
      index++;
    }
  }
}

- (void)unmarshallArgumentsFromIterator: (DBusMessageIter*)iter
                         intoInvocation: (NSInvocation*)inv
                                 boxing: (BOOL)doBox
{
  NSUInteger numArgs = [inArgs count];
  // Arguments start at index 2 (i.e. after self and _cmd)
  NSUInteger index = 2;
  while (index < (numArgs +2))
  {
    // Let the arguments umarshall themselves into the invocation
    [[inArgs objectAtIndex: (index - 2)] unmarshallFromIterator: iter
                                                 intoInvocation: inv
                                                        atIndex: index
                                                         boxing: doBox];
    /*
     * Proceed to the next value in the message, but raise an exception if
     * we are missing some arguments.
     */
    NSAssert2(dbus_message_iter_next(iter),
      @"D-Bus message too short when unmarshalling arguments for invocation of '%@' on '%@'.",
      NSStringFromSelector([inv selector]),
      [inv target]);
    index++;
  }
}

- (void) marshallArgumentsFromInvocation: (NSInvocation*)inv
                            intoIterator: (DBusMessageIter*)iter
                                  boxing: (BOOL)doBox
{
  // Start with index 2 to get the proper arguments
  NSUInteger index = 2;
  DKArgument *argument = nil;
  NSEnumerator *argEnum = [inArgs objectEnumerator];

  NSAssert1([inArgs count] == [[inv methodSignature] numberOfArguments],
    @"Argument number mismatch when constructing D-Bus call for '%@'", name);

  while (nil != (argument = [argEnum nextObject]))
  {
    [argument marshallArgumentAtIndex: index
                       fromInvocation: inv
                         intoIterator: iter
                               boxing: doBox];
  index++;
  }
}

- (void) unmarshallFromIterator: (DBusMessageIter*)iter
                 intoInvocation: (NSInvocation*)inv
   	            messageType: (int)type
	                 boxing: (BOOL)doBox
{
   if (DBUS_MESSAGE_TYPE_METHOD_RETURN == type)
   {
     // For method returns, we are interested in the return value.
     [self unmarshallReturnValueFromIterator: iter
                              intoInvocation: inv
                                      boxing: doBox];
   }
   else if (DBUS_MESSAGE_TYPE_METHOD_CALL == type)
   {
     // For method calls, we want to construct the invocation from the
     // arguments.
     [self unmarshallArgumentsFromIterator: iter
                            intoInvocation: inv
                                    boxing: doBox];
   }
}

- (void)marshallFromInvocation: (NSInvocation*)inv
                  intoIterator: (DBusMessageIter*)iter
                   messageType: (int)type
                        boxing: (BOOL)doBox
{
  if (DBUS_MESSAGE_TYPE_METHOD_RETURN == type)
  {
    // If we are constructing a method return message, we want to obtain the
    // return value.
    [self marshallReturnValueFromInvocation: inv
                               intoIterator: iter
                                     boxing: doBox];
  }
  else if (DBUS_MESSAGE_TYPE_METHOD_CALL == type)
  {
    // If we are constructing a method call, we want to marshall the arguments
    [self marshallArgumentsFromInvocation: inv
                             intoIterator: iter
                                   boxing: doBox];
  }
}
- (NSString*)methodDeclaration
{
  NSMutableString *declaration = [NSMutableString stringWithString: @"- "];
  NSString *returnType = nil;
  NSUInteger outCount = [outArgs count];
  NSEnumerator *argEnum = nil;
  DKArgument *arg = nil;
  NSUInteger count = 0;

  if (0 == outCount)
  {
    if ([self isOneway])
    {
      returnType = @"oneway void";
    }
    else
    {
      returnType = @"void";
    }

  }
  else if (outCount > 1)
  {
    returnType = @"NSArray*";
  }
  else
  {
    returnType = [NSString stringWithFormat: @"%@*",
      NSStringFromClass([(DKArgument*)[outArgs objectAtIndex: 0] objCEquivalent])];
  }

  [declaration appendFormat: @"(%@) %@", returnType, name];

  argEnum = [inArgs objectEnumerator];
  while (nil != (arg = [argEnum nextObject]))
  {
    NSString *argType = @"id";
    NSString *argName = [arg name];
    Class theClass = [arg objCEquivalent];
    if (theClass != Nil)
    {
      argType = [NSStringFromClass(theClass) stringByAppendingString: @"*"];
    }

    if (nil == argName)
    {
      argName = [[NSString alloc] initWithFormat: @"argument%ld", count];
    }
    [declaration appendFormat:@": (%@)%@ ", argType, argName];
    [argName release];
    count++;
  }
  if ([self isDeprecated])
  {
    [declaration appendString: @"__attribute__((deprecated));"];
  }
  else
  {
    [declaration replaceCharactersInRange: NSMakeRange(([declaration length]), 0)
                               withString: @";"];
  }
  return declaration;
}


- (void)dealloc
{
  [interface release];
  [inArgs release];
  [outArgs release];
  [super dealloc];
}
@end
