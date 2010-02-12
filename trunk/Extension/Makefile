TWEAK_NAME = Kirikae
APP_ID = jp.ashikase.kirikae

Kirikae_OBJCC_FILES = main.mm \
					  FavoritesController.mm \
					  Kirikae.mm \
					  SpotlightController.mm \
					  SpringBoardController.mm \
					  SpringBoardHooks.mm \
					  TaskListCell.mm \
					  TaskListController.mm 
Kirikae_CFLAGS = -F$(SYSROOT)/System/Library/CoreServices -DAPP_ID=\"$(APP_ID)\"
Kirikae_FRAMEWORKS = UIKit CoreGraphics

include ../framework/makefiles/common.mk
include ../framework/makefiles/tweak.mk
