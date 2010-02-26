APPLICATION_NAME = Preferences
APP_ID = jp.ashikase.kirikae

Preferences_BUNDLE_NAME = Kirikae
Preferences_OBJC_FILES = main.m \
						 AppearanceController.m \
						 ApplicationCell.m \
						 Application.m \
						 ColorsController.m \
						 ColorPickerController.m \
						 DocumentationController.m \
						 FavoritePickerController.m \
						 FavoritesController.m \
						 GradientSlider.m \
						 HtmlDocController.m \
						 Preferences.m \
						 RootController.m \
						 SpectrumSlider.m \
						 TabsController.m \
						 ToggleButton.m
Preferences_CFLAGS = -std=gnu99 -DAPP_ID=\"$(APP_ID)\"
Preferences_LDFLAGS = -lactivator
Preferences_FRAMEWORKS = UIKit CoreGraphics
Preferences_PRIVATE_FRAMEWORKS = SpringBoardServices

include ../framework/makefiles/common.mk
include ../framework/makefiles/application.mk
