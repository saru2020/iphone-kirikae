APPLICATION_NAME = Preferences
APP_ID = jp.ashikase.kirikae

Preferences_BUNDLE_NAME = Kirikae
Preferences_CFLAGS = -std=gnu99 -DMAX_PAGES=9
Preferences_OBJC_FILES = main.m \
						 AppearanceController.m \
						 ApplicationCell.m \
						 Application.m \
						 ControlController.m \
						 DocumentationController.m \
						 FavoritesController.m \
						 GeneralController.m \
						 HtmlDocController.m \
						 Preferences.m \
						 RootController.m \
						 ToggleButton.m
Preferences_CFLAGS = -DAPP_ID=\"$(APP_ID)\"
Preferences_LDFLAGS = -lactivator
Preferences_FRAMEWORKS = UIKit CoreGraphics
Preferences_PRIVATE_FRAMEWORKS = SpringBoardServices

include ../framework/makefiles/common.mk
include ../framework/makefiles/application.mk
