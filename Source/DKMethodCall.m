/** Implementation of the DKMethodCall class for calling D-Bus methods.

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
   */

#import "DKMethodCall.h"
#import "DKProxy+Private.h"
#import "DKEndpoint.h"
#import "DKEndpointManager.h"
#import "DKMethod.h"

#import <Foundation/NSDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSString.h>
#import <Foundation/NSThread.h>

#ifndef DARLING
#import <GNUstepBase/NSDebug+GNUstepBase.h>
#else
#import "config.h"
#endif

#include <sched.h>
#include <string.h>

@interface DKMethodCall (Private)
- (BOOL) serialize;
@end

@implementation DKMethodCall
- (id) initWithProxy: (DKProxy*)aProxy
              method: (DKMethod*)aMethod
          invocation: (NSInvocation*)anInvocation
{
  return [self initWithProxy: aProxy
                      method: aMethod
                  invocation: anInvocation
                     timeout: 0];
}
- (id) initWithProxy: (DKProxy*)aProxy
              method: (DKMethod*)aMethod
          invocation: (NSInvocation*)anInvocation
             timeout: (NSTimeInterval)aTimeout
{
  DBusMessage *theMessage = NULL;
  DKEndpoint *theEndpoint = [aProxy _endpoint];
  const char* dest = [[aProxy _service] UTF8String];
  const char* path = [[aProxy _path] UTF8String];
  const char* interface = [[aMethod interface] UTF8String];
  const char* methodName = [[aMethod name] UTF8String];

  if (((nil == aProxy) || (nil == aMethod)) || (nil == anInvocation))
  {
    [self release];
    return nil;
  }
  theMessage = dbus_message_new_method_call(dest,
    path,
    interface,
    methodName);
  if (NULL == theMessage)
  {
    [self release];
    return nil;
  }

  /*
   * Initialize the superclass. Since we need the DBusPendingCall, we cannot use
   * the resource preallocation feature. The superclass takes owenership of the
   * DBusMessage.
   */
  if (nil == (self = [super initWithDBusMessage: theMessage
                                    forEndpoint: theEndpoint
                           preallocateResources: NO]))
  {
    dbus_message_unref(theMessage);
    return nil;
  }

  dbus_message_unref(theMessage);

  ASSIGN(invocation,anInvocation);
  ASSIGN(method,aMethod);
  if (0 == aTimeout)
  {
    // Default timeout
    timeout = -1;
  }

  /*
   * Convert NSTimeInterval (seconds, floating point) into D-Bus representation
   * (milliseconds, integer).
   */
  timeout = (NSInteger)(aTimeout * 1000.0);

  if (NO == [self serialize])
  {
    [self release];
    return nil;
  }
  return self;
}

- (BOOL)serialize
{
  BOOL didSucceed = YES;
  DBusMessageIter iter;

  dbus_message_iter_init_append(msg, &iter);
  NS_DURING
  {
    [method marshallFromInvocation: invocation
                      intoIterator: &iter
                       messageType: DBUS_MESSAGE_TYPE_METHOD_CALL];
  }
  NS_HANDLER
  {
    NSWarnMLog(@"Could not marshall arguments into D-Bus message. Exception raised: %@",
      localException);
    didSucceed = NO;
  }
  NS_ENDHANDLER
  return didSucceed;
}
- (BOOL)hasObjectReturn
{
  return  (0 == strcmp(@encode(id), [[invocation methodSignature] methodReturnType]));
}

- (void)handleReplyFromPendingCall: (DBusPendingCall*)pending
                             async: (BOOL)didAsyncOperation
{
  DBusMessage *reply = dbus_pending_call_steal_reply(pending);
  int msgType;
  DBusError error;
  NSException *errorException = nil;
  DBusMessageIter iter;
  // This is the future we are going to use for asynchronous resolution.
  id future = nil;

  // Bad things would happen if we tried this
  NSAssert(!(didAsyncOperation && (NO == [self hasObjectReturn])),
    @"Filling asynchronous return values for non-objects is impossible.");

  if (NULL == reply)
  {
    [NSException raise: @"DKDBusMethodReplyException"
                format: @"Could not obtain reply for pending D-Bus method call."];
  }

  msgType = dbus_message_get_type(reply);

  // Only accept error messages or method replies:
  if (NO == ((msgType == DBUS_MESSAGE_TYPE_METHOD_RETURN)
    || (msgType == DBUS_MESSAGE_TYPE_ERROR)))
  {
    [NSException raise: @"DKDBusMethodReplyException"
                format: @"Invalid message type (%ld) in D-Bus reply", (long)msgType];
  }

  // Handle the error case:
  if (msgType == DBUS_MESSAGE_TYPE_ERROR)
  {
    NSString *errorName = nil;
    NSString *errorMessage = nil;
    NSDictionary *infoDict = nil;

    dbus_error_init(&error);
    dbus_set_error_from_message(&error, reply);
    if (dbus_error_is_set(&error))
    {
      NSString *exceptionName = @"DKDBusRemoteErrorException";
      NSString *exceptionReason = @"A remote object returned an error upon a method call.";
      errorName = [NSString stringWithUTF8String: error.name];
      errorMessage = [NSString stringWithUTF8String: error.message];

      // Check whether the error actually comes from another object exported by
      // DBusKit. If so, we can set the exception name to something the user
      // expects.
      if (([errorName hasPrefix: @"org.gnustep.objc.exception."])
	&& ([errorName length] > 28))
      {
	exceptionName = [errorName substringFromIndex: 27];
	exceptionReason = errorMessage;
      }
      infoDict = [[NSDictionary alloc] initWithObjectsAndKeys:
        errorMessage, errorName,
	invocation, @"invocation", nil];
      errorException = [NSException exceptionWithName: exceptionName
                                               reason: exceptionReason
                                             userInfo: infoDict];
      [infoDict release];
    }
    else
    {
      errorException = [NSException exceptionWithName: @"DKDBusMethodReplyException"
                                               reason: @"Undefined error in D-Bus method reply"
                                             userInfo: nil];
    }
      if (didAsyncOperation)
      {
	// TODO: Pass the exception to the future. It will raise once user code
	// tries to reference the object.
	return;
      }
      else
      {
	[errorException raise];
      }
    }


  // Implicit else if (type == DBUS_MESSAGE_TYPE_METHOD_RETURN)

  if (YES == didAsyncOperation)
  {
    // Extract the future from the invocation, we need it for later use:
    [invocation getReturnValue: &future];
  }


  // We need to catch possible exceptions in order to pass them to the future if
  // we are operating asynchronously.
  NS_DURING
  {
    // dbus_message_iter_init() will return NO if there are no arguments to
    // unmarshall.
    if (YES == (BOOL)dbus_message_iter_init(reply, &iter))
    {
      [method unmarshallFromIterator: &iter
                      intoInvocation: invocation
                         messageType: DBUS_MESSAGE_TYPE_METHOD_RETURN];
    }
  }
  NS_HANDLER
  {
    errorException = localException;
  }
  NS_ENDHANDLER

  if (YES == didAsyncOperation)
  {
    id realObject = nil;
    if (nil != errorException)
    {
      //TODO: Pass the exception to the future.
    }

    // Extract the real returned object from the invocation:
    [invocation getReturnValue: &realObject];

    // TODO: Pass the object to the future. Message sends to the future will no
    // longer block.
  }
  else
  {
    if (nil != errorException)
    {
      [errorException raise];
    }

  }
}

/**
 * Helper method to schedule sending of the message on the worker thread.
 */
- (BOOL)sendWithPendingCallAt: (DBusPendingCall**)pending
{
  return (BOOL)dbus_connection_send_with_reply([endpoint DBusConnection],
    msg,
    pending,
    timeout);

}
- (void)sendAsynchronously
{
  // If the endpoint manager is in synchronizing mode, we don't bother doing an
  // asynchronous call.
  if (([[DKEndpointManager sharedEndpointManager] isSynchronizing])
    || ([[NSThread currentThread] isEqual: [[DKEndpointManager sharedEndpointManager] workerThread]]))
  {
    [self sendSynchronously];
  }
  //TODO: Implement asynchronous behaviour.
}

- (void)sendSynchronously
{
  DBusPendingCall *pending = NULL;
  // -1 means default timeout
  BOOL couldSend = NO;
  NSInteger count = 0;
  DKEndpointManager *manager = [DKEndpointManager sharedEndpointManager];
  IMP isSynchronizing = [manager methodForSelector: @selector(isSynchronizing)];
  couldSend = [manager boolReturnForPerformingSelector: @selector(sendWithPendingCallAt:)
                                                target: self
                                                  data: (void*)&pending
                                         waitForReturn: YES];
  if (NO == couldSend)
  {
    [NSException raise: @"DKDBusOutOfMemoryException"
                format: @"Out of memory when sending D-Bus message."];

  }

  if (NULL == pending)
  {
    [NSException raise: @"DKDBusDisconnectedException"
                format: @"Disconnected from D-Bus when sending message."];

  }

  do
  {
    // Determine wether the manager is in synchronized mode and we need to use
    // the runloop.
    BOOL useCurrentRunLoop = ((BOOL)(uintptr_t)isSynchronizing(manager, @selector(isSynchronizing))
    || ([[NSThread currentThread] isEqual: [manager workerThread]]));

    // If we are using the worker thread, we can yield aggressively until the
    // call completes.
    if (((++count % 16) == 0)
      && (NO == useCurrentRunLoop))
    {
      sched_yield();
    }
    else if (useCurrentRunLoop)
    {
      // Otherwise, we need to the runloop to complete our request.
      [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
    }
  } while (NO == (BOOL)dbus_pending_call_get_completed(pending));

  //Now we are sure that we don't need the message any more.
  if (NULL != msg)
  {
    dbus_message_unref(msg);
    msg = NULL;
  }

  NS_DURING
  {
    [self handleReplyFromPendingCall: pending
                               async: NO];
  }
  NS_HANDLER
  {
    // Throw away the pending call
    if (NULL != pending)
    {
      dbus_pending_call_unref(pending);
      pending = NULL;
    }
    [localException raise];
  }
  NS_ENDHANDLER
  if (NULL != pending)
  {
    dbus_pending_call_unref(pending);
    pending = NULL;
  }
}
@end
