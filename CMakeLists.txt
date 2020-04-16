project(DBusKit)

include(darling_framework)

find_package(PkgConfig REQUIRED)
pkg_check_modules(PC_DBUS dbus-1)

include_directories(
	${CMAKE_CURRENT_SOURCE_DIR}/include
	${PC_DBUS_INCLUDE_DIRS}
)

set(DBusKit_sources
	Source/DKArgument.m
	Source/DKBoxingUtils.m
	Source/DKEndpoint.m
	Source/DKEndpointManager.m
	Source/DKInterface.m
	Source/DKIntrospectionNode.m
	Source/DKIntrospectionParserDelegate.m
	Source/DKMessage.m
	Source/DKMethodCall.m
	Source/DKMethod.m
	Source/DKMethodReturn.m
	Source/DKNonAutoInvalidatingPort.m
	Source/DKNotificationCenter.m
	Source/DKNumber.m
	Source/DKObjectPathNode.m
	Source/DKOutgoingProxy.m
	Source/DKPort.m
	Source/DKPortNameServer.m
	Source/DKProperty.m
	Source/DKPropertyMethod.m
	Source/DKProxy.m
	Source/DKSignalEmission.m
	Source/DKSignal.m
	Source/DKStruct.m
	Source/DKVariant.m
	# Source/NSConnection+DBus.m
	Source/DKConnection.m
)

add_framework(DBusKit
	FAT
	CURRENT_VERSION
	PRIVATE
	SOURCES
		${DBusKit_sources}
	VERSION "A"
	DEPENDENCIES
		objc
		system
		Foundation
		# native libraries
		dbus
)
