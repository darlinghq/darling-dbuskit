/* Unit tests for DKInterface
   Copyright (C) 2012 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: January 2012

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
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSNull.h>
#import <UnitKit/UnitKit.h>

#import "../Source/DKInterface.h"
#import "../Source/DKProxy+Private.h"

#include <string.h>
@interface TestDKInterface: NSObject <UKTest>
@end

@protocol ExportableTestProtocol
- (void)shouldNotBeExported;
- (BOOL)application: (id)foo didSomethingWith: (NSString*)string;
@end

@interface ExportableTestObject: NSObject
- (void)shouldNotBeExported;
- (BOOL)application: (id)foo didSomethingWith: (NSString*)string;
@end


@implementation ExportableTestObject
- (void)shouldNotBeExported
{
}

- (BOOL)application: (id)foo didSomethingWith: (NSString*)string
{
  return YES;
}
@end

@implementation TestDKInterface
+ (void)initialize
{
  if ([TestDKInterface class] == self)
  {
    // Do this to initialize the global introspection method:
    [DKProxy class];
  }
}

- (void)testBuiltInIntrospectableInterface
{
  UKNotNil(_DKInterfaceIntrospectable);
  UKObjectsEqual(@"org.freedesktop.DBus.Introspectable", [_DKInterfaceIntrospectable name]);
  UKNotNil([_DKInterfaceIntrospectable DBusMethodForSelector: @selector(Introspect)]);
}
- (void)testXMLNode
{
  //We use our builtin introspection method for this.
  NSXMLNode *n = [_DKInterfaceIntrospectable XMLNode];
  NSXMLNode *methodNode = [n childAtIndex: 0];
  UKNotNil(n);
  UKNotNil(methodNode);

  UKObjectsEqual(@"interface", [(NSXMLElement*)n name]);
  UKObjectsEqual(@"org.freedesktop.DBus.Introspectable", [[(NSXMLElement*)n attributeForName: @"name"] stringValue]);
  UKObjectsEqual(@"method", [methodNode name]);
  // The internals of method nodes are tested in TestDKMethod.m
}

- (void)testInterfaceFromClassIntrospection
{
  DKInterface *theIf = [DKInterface interfaceForObjCClass: [ExportableTestObject class]];
  UKNotNil(theIf);
  UKObjectsEqual(@"org.gnustep.objc.class.ExportableTestObject", [theIf name]);
  UKNotNil([[theIf methods] objectForKey: @"applicationDidSomethingWith"]);
  UKNil([[theIf methods] objectForKey: @"shouldNotBeExported"]);
}

- (void)testInterfaceFromProtocolIntrospection
{
  DKInterface *theIf = [DKInterface interfaceForObjCProtocol: objc_getProtocol("ExportableTestProtocol")];
  UKNotNil(theIf);
  UKObjectsEqual(@"org.gnustep.objc.protocol.ExportableTestProtocol", [theIf name]);
  UKNotNil([[theIf methods] objectForKey: @"applicationDidSomethingWith"]);
  UKNil([[theIf methods] objectForKey: @"shouldNotBeExported"]);
}

@end
