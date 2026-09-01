ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NotesExporter
NotesExporter_FILES = Tweak.m
NotesExporter_CFLAGS = -fobjc-arc
NotesExporter_FRAMEWORKS = UIKit Foundation CoreData
NotesExporter_LDFLAGS = -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk

after-stage::
	@mkdir -p $(THEOS_STAGING_DIR)/Payload
	@cp $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/NotesExporter.dylib $(THEOS_STAGING_DIR)/Payload/NotesExporter.dylib
