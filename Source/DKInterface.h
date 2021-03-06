/** Interface for DKInterface class encapsulating D-Bus interface information.
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

#import "DKIntrospectionNode.h"

@class DKNotificationCenter, NSString, NSMutableDictionary, NSMapTable, DKMethod, DKProperty, DKSignal;

/**
 * DKInterface encapsulates information about D-Bus interfaces. Interfaces
 * members are methods, signals and properties. DKInterface also maintains a
 * lookup table mapping Objective-C selectors to D-Bus methods.
 */
@interface DKInterface: DKIntrospectionNode
{
  NSMutableDictionary *methods;
  NSMutableDictionary *signals;
  NSMutableDictionary *properties;
  NSMapTable *selectorToMethodMap;
}

/**
 * Returns an interface set up with all methods defined in the Objective-C
 * class given. This does not include methods defined in superclasses.
 */
+ (id)interfaceForObjCClass: (Class)theClass;

/**
 * Returns an interface set up with all methods defined in the Objective-C
 * protocols given. This does not include methods declared by protocols adopted.
 * by this protocol.
 */
+ (id)interfaceForObjCProtocol: (Protocol*)theProtocol;

/**
 * Returns all methods in the interface
 */
- (NSDictionary*)methods;

/**
 * Returns all signals in the interface
 */
- (NSDictionary*)signals;

/**
 * Returns all properties in the interface
 */
- (NSDictionary*)properties;

/**
 * Adds a method to the interface.
 */
- (void) addMethod: (DKMethod*)method;

/**
 * Adds a signal to the interface.
 */
- (void) addSignal: (DKSignal*)signal;

/**
 * Adds a property to the interface.
 */
- (void) addProperty: (DKProperty*)property;

/**
 * Removes a signal from the interface
 */
- (void)removeSignalNamed: (NSString*)signalName;

/**
 * Install the method as responding to the selector into the interface specific
 * dispatch table. It will be added to the interface if it is not already
 * present.
 */
- (void) installMethod: (DKMethod*)method
           forSelector: (SEL)selector;

/**
 * Add all methods present in the interface to the dispatch table, utilizing
 * their default selector names.
 */
- (void)installMethods;

/**
 * Add accessor and mutator methods for all properties to the dispatch table if
 * no method with the same name exists.
 */
- (void)installProperties;

/**
 * Registers all signals in the interface for use with the default
 * DKNotificationCenter.
 */
- (void)registerSignals;

/**
 * Registers all signals in the interface for use with the named
 * DKNotificationCenter.
 */
- (void)registerSignalsWithNotificationCenter: (DKNotificationCenter*)center;

/**
 * Returns the method installed for this selector.
 */
- (DKMethod*) DBusMethodForSelector: (SEL)selector;

/**
 * Returns the description of all methods in the interface as a protocol
 * declaration suitable for an Objective-C header file. Defaults to creating
 * Objective-C 2 compliant protocol declarations.
 */
- (NSString*)protocolDeclaration;


/**
 * Returns the description of all methods in the interface as a protocol
 * declaration. Set useObjC2 to NO if separate method declarations for property
 * mutators and accessors are required.
 */
- (NSString*)protocolDeclarationForObjC2: (BOOL)useObjC2;

/**
 * Returns the Objective-C protocol that corresponds to the interface (if any).
 * The protocol must be registered with the Objective-C runtime.
 */
- (Protocol*)protocol;

/**
 * Returns the interface name with all dots replaced by underscores.
 */
- (NSString*)mangledName;

/**
 * Returns the name of the Objective-C protocol corresponding to the interface.
 * This will utilize the org.gnustep.objc.protocol annotation key if available
 * and return the -mangledName otherwise.
 */
- (NSString*)protocolName;
@end
