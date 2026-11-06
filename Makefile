TARGET := iphone:clang:latest:13.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = MubdiSpeed

MubdiSpeed_FILES = Rebind.c SpeedCore.c MubdiMenu.m
MubdiSpeed_CFLAGS = -fobjc-arc -O2 -Wno-deprecated-declarations
MubdiSpeed_FRAMEWORKS = UIKit Foundation QuartzCore
MubdiSpeed_INSTALL_PATH = @executable_path/Frameworks

include $(THEOS_MAKE_PATH)/library.mk
