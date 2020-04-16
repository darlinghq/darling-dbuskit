/*
  This file is part of Darling.

  Copyright (C) 2020 Lubos Dolezel

  Darling is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Darling is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

/** Category on NSConnection to facilitate D-Bus integration
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: July 2010

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

#import "DBusKit/DKConnection.h"
#import "DBusKit/DKPort.h"
#import "DKProxy+Private.h"

@interface DKPort (DKPortPrivate)
- (BOOL)hasValidRemote;
- (void)_setObject: (id)obj
            atPath: (NSString*)path;
@end

@implementation DKConnection

- (NSDistantObject *)rootProxy
{
  return (NSDistantObject*)[self proxyAtPath: @"/"];
}

- (void)setRootObject: (id)obj
{
  [self setObject: obj
           atPath: @"/"];
}

- (void)setObject: (id)obj
           atPath: (NSString*)path
{
  id rp = [self receivePort];
  [(DKPort*)rp _setObject: obj
                   atPath: path];
}

- (DKProxy*)proxyAtPath: (NSString*)path
{
  id sp = [self sendPort];
  if (NO == [sp hasValidRemote])
  {
    return nil;
  }

  return [DKProxy proxyWithPort: sp
                           path: path];
}
@end
