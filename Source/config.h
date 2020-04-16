/** Configuration dependent information for DBusKit.
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

/*
 * Correct location of runtime.h, if requested.
 */
// #ifdef INCLUDE_RUNTIME_H
#  include <objc/runtime.h>
// #endif

/*
#ifndef HAVE_OBJC_ENCODING_H
#  define  HAVE_OBJC_ENCODING_H @HAVE_OBJC_ENCODING_H@
#endif

#ifndef USE_SEL_GETTYPEENCODING
# define USE_SEL_GETTYPEENCODING @USE_SEL_GETTYPEENCODING@
# if USE_SEL_GETTYPEENCODING
#   define sel_getType_np sel_getTypeEncoding
# endif
#endif
*/

#ifndef DISABLE_TYPED_SELECTORS
# define DISABLE_TYPED_SELECTORS 1
#endif

#ifndef HAVE_LIBCLANG
# define HAVE_LIBCLANG 0
#endif

#ifndef HAVE_FUNC_ATTRIBUTE_VISIBILITY
#  define HAVE_FUNC_ATTRIBUTE_VISIBILITY 1
#endif


// For Darling build

#if 0
#define NSDebugLog NSLog
#define NSDebugMLog NSLog
#define NSDebugFLog NSLog
#define NSWarnMLog NSLog
#define GSOnceMLog NSLog
#else
#define NSDebugLog(...)
#define NSDebugMLog(...)
#define NSDebugFLog(...)
#define NSWarnMLog(...)
#define GSOnceMLog(...)
#endif

#define objc_skip_argspec(types) NSGetSizeAndAlignment(types, NULL, NULL)

static inline const char *objc_skip_type_qualifiers(const char *types) {
    for (;; types++) {
        switch (types[0]) {
        case 'r':
        case 'n':
        case 'N':
        case 'o':
        case 'O':
        case 'R':
        case 'V':
            break;
        default:
            return types;
        }
    }
}

#import <CoreFoundation/GNUstep.h>

@interface NSObject (Responsibility)
- (void) subclassResponsibility: (SEL) selector;
- (void) shouldNotImplement: (SEL) selector;
@end
