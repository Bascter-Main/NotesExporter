# Defaults may be overridden by the environment or make command line.
ARCHS ?= arm64 arm64e
TARGET ?= iphone:clang:latest:15.0

ifeq ($(strip $(THEOS)),)
$(error THEOS is not set. Export THEOS to your Theos installation directory)
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NotesExporter
NotesExporter_FILES = Tweak.m
NotesExporter_CFLAGS = -fobjc-arc
NotesExporter_FRAMEWORKS = UIKit Foundation CoreData

# Tweak.m uses Objective-C runtime method replacement, not Substrate hooks.
NotesExporter_USE_SUBSTRATE = 0
# Preserve the existing lookup behavior for injection into Apple Notes.
NotesExporter_LDFLAGS = -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk

# Keep the existing Payload layout for consumers of the staged dylib.
after-stage::
	@mkdir -p "$(THEOS_STAGING_DIR)/Payload"
	@cp "$(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/$(TWEAK_NAME).dylib" "$(THEOS_STAGING_DIR)/Payload/$(TWEAK_NAME).dylib"
