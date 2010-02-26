/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-02-26 00:55:00
 */

/**
 * Copyright (C) 2009  Lance Fetters (aka. ashikase)
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *
 * 3. The name of the author may not be used to endorse or promote
 *    products derived from this software without specific prior
 *    written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
 * IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */


#import "SpringBoardHooks.h"

#import <CoreFoundation/CoreFoundation.h>
#import <QuartzCore/QuartzCore.h>

#import <SpringBoard/SBAlertWindow.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBAwayController.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SBDisplay.h>
#import <SpringBoard/SBDisplayStack.h>
#import <SpringBoard/SBPowerDownController.h>
#import <SpringBoard/SBSearchController.h>
#import <SpringBoard/SBSearchView.h>
#import <SpringBoard/SBStatusBar.h>
#import <SpringBoard/SBStatusBarController.h>
#import <SpringBoard/SBUIController.h>
#import <SpringBoard/SBVoiceControlAlert.h>
#import <SpringBoard/SpringBoard.h>

@interface UIKeyboard : UIView
@end

@interface UIWebClip
@property(retain) NSURL *pageURL;
+ (id)webClipWithIdentifier:(id)identifier;
@end

@interface SPSearchResult : NSObject
@property(assign, nonatomic) int domain;
@end

#import "Kirikae.h"
#import "KirikaeActivator.h"
#import "SpringBoardController.h"


static Kirikae *kirikae = nil;

static BOOL animationsEnabled = YES;

//static NSString *deactivatingApp = nil;

static NSString *killedApp = nil;

// FIXME: Find a better way to prevent dismissal when quitting an application
//        (when animations are disabled)
static BOOL shouldDismiss = NO;

//==============================================================================

static void loadPreferences()
{
    // Animate switching
    Boolean valid;
    animationsEnabled = CFPreferencesGetAppBooleanValue(CFSTR("animationsEnabled"), CFSTR(APP_ID), &valid);
    if (!valid)
        animationsEnabled = YES;

    // Invocation type
    // NOTE: This setting is from pre-libactivator; convert and remove
    CFPropertyListRef propList = CFPreferencesCopyAppValue(CFSTR("invocationMethod"), CFSTR(APP_ID));
    if (propList) {
        NSString *eventName = nil;
        if ([(NSString *)propList isEqualToString:@"homeSingleTap"])
            eventName = LAEventNameMenuPressSingle;
        else if ([(NSString *)propList isEqualToString:@"homeDoubleTap"])
            eventName = LAEventNameMenuPressDouble;
        else if ([(NSString *)propList isEqualToString:@"homeShortHold"])
            eventName = LAEventNameMenuHoldShort;
        else if ([(NSString *)propList isEqualToString:@"powerShortHold"])
            eventName = LAEventNameLockHoldShort;
        CFRelease(propList);

        // Register the event type with libactivator
        [[LAActivator sharedInstance] assignEvent:[LAEvent eventWithName:eventName] toListenerWithName:@APP_ID];

        // Remove the preference, as it is no longer used
        CFPreferencesSetAppValue(CFSTR("invocationMethod"), NULL, CFSTR(APP_ID));
        CFPreferencesAppSynchronize(CFSTR(APP_ID));
    }
}

//==============================================================================

NSMutableArray *displayStacks = nil;

// Display stack names
#define SBWPreActivateDisplayStack        [displayStacks objectAtIndex:0]
#define SBWActiveDisplayStack             [displayStacks objectAtIndex:1]
#define SBWSuspendingDisplayStack         [displayStacks objectAtIndex:2]
#define SBWSuspendedEventOnlyDisplayStack [displayStacks objectAtIndex:3]

%hook SBDisplayStack

- (id)init
{
    id stack = %orig;
    [displayStacks addObject:stack];
    return stack;
}

- (void)dealloc
{
    [displayStacks removeObject:self];
    %orig;
}

%end

//==============================================================================

static BOOL canInvoke()
{
    // Should not invoke if either lock screen or power-off screen is active
    SBAwayController *awayCont = [objc_getClass("SBAwayController") sharedAwayController];
    return !([awayCont isLocked]
            || [awayCont isMakingEmergencyCall]
            || [[objc_getClass("SBIconController") sharedInstance] isEditing]
            || [[objc_getClass("SBPowerDownController") sharedInstance] isOrderedFront]);
}

%hook SpringBoard

- (void)_handleMenuButtonEvent
{
    if (kirikae != nil) {
        // Kirikae is invoked; hide and destroy
        [self dismissKirikae];

        // NOTE: _handleMenuButtonEvent is responsible for resetting the home tap count
        unsigned int &_menuButtonClickCount = MSHookIvar<unsigned int>(self, "_menuButtonClickCount");
        _menuButtonClickCount = 0x8000;
    } else {
        %orig;
    }
}

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    // NOTE: SpringBoard creates four stacks at startup
    // NOTE: Must create array before calling original implementation
    displayStacks = [[NSMutableArray alloc] initWithCapacity:4];

    %orig;
}

- (void)dealloc
{
    [killedApp release];
    [displayStacks release];
    %orig;
}

%new(@@:)
- (Kirikae *)kirikae
{
    return kirikae;
}

%new(v@:)
- (void)invokeKirikae
{
    if (kirikae != nil)
        // Kirikae is already invoked
        // NOTE: This check is needed when called by external invokers
        return;

    if (!canInvoke())
        // Currently in a state where invocation is prohibited
        return;

    // Create and show Kirikae view
    kirikae = [[objc_getClass("Kirikae") alloc] init];
    [kirikae activate];
}

%new(v@:)
- (void)dismissKirikae
{
    // FIXME: If feedback types other than simple and task-menu are added,
    //        this method will need to be updated

    // Hide and release kirikae window (may be nil)
    [[kirikae display] dismiss];
    [kirikae release];
    kirikae = nil;
}

%new(v@:@)
- (void)switchToAppWithDisplayIdentifier:(NSString *)displayId
{
    SBApplication *fromApp = [SBWActiveDisplayStack topApplication];
    NSString *fromDisplayId = fromApp ? fromApp.displayIdentifier : @"com.apple.springboard";

    // FIXME: If possible, find a better method/place for checking if web clip
    UIWebClip *clip = [UIWebClip webClipWithIdentifier:displayId];
    NSURL *url = nil;
    if (![clip.pageURL.absoluteString isEqualToString:@"about:blank"]) {
        url = clip.pageURL;
        displayId = @"com.apple.mobilesafari";
    }

    // Make sure that the target app is not the same as the current app
    // NOTE: This is checked as there is no point in proceeding otherwise
    if (![fromDisplayId isEqualToString:displayId] || url != nil) {
        // Is either a different application or is a web clip; switch

        // NOTE: Save the identifier for later use
        //deactivatingApp = [fromDisplayId copy];

        BOOL switchingToSpringBoard = [displayId isEqualToString:@"com.apple.springboard"];

        SBApplication *app = [[objc_getClass("SBApplicationController") sharedInstance]
            applicationWithDisplayIdentifier:displayId];
        if (app) {
            if (url != nil)
                [app setActivationSetting:0x4 value:url];

            // FIXME: Handle case when app == nil
            if ([fromDisplayId isEqualToString:@"com.apple.springboard"]) {
                // Switching from SpringBoard; simply activate the target app
                [app setDisplaySetting:0x4 flag:YES]; // animate
                if (!animationsEnabled)
                    // NOTE: animationStart can be used to delay or skip the act/deact
                    //       animation. Based on current uptime, setting it to a future
                    //       value will delay the animation; setting it to a past time
                    //       skips the animation. Setting it to now, or leaving it
                    //       unset, causes the animation to begin immediately.
                    // NOTE: The proper way to set this would be via CACurrentMediaTime(),
                    //       but using 1 (not 0) appears to work okay.
                    [app setActivationSetting:0x1000 value:[NSNumber numberWithDouble:1]]; // animationStart

                // Activate the target application
                [SBWPreActivateDisplayStack pushDisplay:app];
            } else {
                // Switching from another app
                if (!switchingToSpringBoard) {
                    // Switching to another app; setup app-to-app
                    [app setActivationSetting:0x40 flag:YES]; // animateOthersSuspension
                    [app setActivationSetting:0x20000 flag:YES]; // appToApp
                    [app setDisplaySetting:0x4 flag:YES]; // animate

                    if (!animationsEnabled)
                        [app setActivationSetting:0x1000 value:[NSNumber numberWithDouble:1]]; // animationStart

                    // Activate the target application (will wait for
                    // deactivation of current app)
                    [SBWPreActivateDisplayStack pushDisplay:app];
                }

                // Deactivate the current application

                // If Backgrounder is installed, enable backgrounding for current application
                if ([self respondsToSelector:@selector(setBackgroundingEnabled:forDisplayIdentifier:)])
                    [self setBackgroundingEnabled:YES forDisplayIdentifier:fromDisplayId];

                // NOTE: Must set animation flag for deactivation, otherwise
                //       application window does not disappear (reason yet unknown)
                [fromApp setDeactivationSetting:0x2 flag:YES]; // animate

                if (!animationsEnabled)
                    [fromApp setDeactivationSetting:0x8 value:[NSNumber numberWithDouble:1]]; // animationStart

                // Deactivate by moving from active stack to suspending stack
                [SBWActiveDisplayStack popDisplay:fromApp];
                [SBWSuspendingDisplayStack pushDisplay:fromApp];
            }

            if (!switchingToSpringBoard) {
                // If CategoriesSB is installed, dismiss any open categories
                SBUIController *uiCont = [objc_getClass("SBUIController") sharedInstance];
                if ([uiCont respondsToSelector:@selector(categoriesSBCloseAll)])
                    [uiCont performSelector:@selector(categoriesSBCloseAll)];
            }
        }

        if (!animationsEnabled) {
            // NOTE: With animations off, wait until other app appears before
            //       dismissing. This is to avoid an ugly flash between the old
            //       and new app.
            shouldDismiss = YES;
            return;
        }
    }

    // Hide the task menu
    [self dismissKirikae];
}

%new(v@:@)
- (void)quitAppWithDisplayIdentifier:(NSString *)identifier
{
    if ([identifier isEqualToString:@"com.apple.springboard"]) {
        // Is SpringBoard
        [self relaunchSpringBoard];
    } else {
        // Is an application
        SBApplication *app = [[objc_getClass("SBApplicationController") sharedInstance]
            applicationWithDisplayIdentifier:identifier];
        if (app) {
            if ([identifier isEqualToString:@"com.apple.mobilephone"]
                    || [identifier isEqualToString:@"com.apple.mobilemail"]
                    || [identifier isEqualToString:@"com.apple.mobilesafari"]
                    || [identifier hasPrefix:@"com.apple.mobileipod"]
                    || [identifier isEqualToString:@"com.googlecode.mobileterminal"]) {
                // Is an application with native backgrounding capability
                // FIXME: Either find a way to detect which applications support
                //        native backgrounding, or use a timer to ensure
                //        termination.
                [app kill];

                // Save identifier to prevent possible auto-relaunch
                [killedApp release];
                killedApp = [identifier copy];
            } else {
                if ([self respondsToSelector:@selector(setBackgroundingEnabled:forDisplayIdentifier:)])
                    // Disable backgrounding for the application
                    [self setBackgroundingEnabled:NO forDisplayIdentifier:identifier];

                if ([SBWActiveDisplayStack containsDisplay:app]) {
                    // Application is current app
                    // NOTE: Must set animation flag for deactivation, otherwise
                    //       application window does not disappear (reason yet unknown)
                    [app setDeactivationSetting:0x2 flag:YES]; // animate
                    if (!animationsEnabled)
                        [app setDeactivationSetting:0x8 value:[NSNumber numberWithDouble:1]]; // animationStart

                    // Remove from active display stack
                    [SBWActiveDisplayStack popDisplay:app];
                }

                // Deactivate the application
                [SBWSuspendingDisplayStack pushDisplay:app];
            }
        }
    }
}

%new(@@:)
- (SBApplication *)topApplication
{
    return [SBWActiveDisplayStack topApplication];
}

%end

//==============================================================================

%hook SBApplication

- (void)activate
{
    // NOTE: This method gets called on both initial launch and when resumed
    //       from background.
    %orig;

    // Inform Kirikae of application activation (Kirikae may be nil)
    [kirikae handleApplicationActivation:self.displayIdentifier];
}

#if 0
- (void)exitedAbnormally
{
    if (animationsEnabled && ![self isSystemApplication])
        [[NSFileManager defaultManager] removeItemAtPath:[self defaultImage:"Default"] error:nil];

    %orig;
}
#endif

- (void)exitedCommon
{
    // Inform Kirikae of application termination (Kirikae may be nil)
    [kirikae handleApplicationTermination:self.displayIdentifier];
    %orig;
}

#if 0
- (void)deactivate
{
    NSString *identifier = [self displayIdentifier];
    if ([identifier isEqualToString:deactivatingApp]) {
        [[objc_getClass("SpringBoard") sharedApplication] dismissKirikae];
        [deactivatingApp release];
        deactivatingApp = nil;
    }

    orig;
}
#endif

#if 0
// NOTE: Only hooked when animationsEnabled == YES
- (id)pathForDefaultImage:(char *)def
{
    return ([self isSystemApplication] || ![activeApps containsObject:[self displayIdentifier]]) ?
        %orig :
        [NSString stringWithFormat:@"%@/Library/Caches/Snapshots/%@-Default.jpg",
            [[self seatbeltProfilePath] stringByDeletingPathExtension], [self bundleIdentifier]];
}
#endif

%end

//==============================================================================

%hook SBUIController

- (void)lock:(BOOL)shouldLock
{
    if (shouldLock) {
        if (kirikae != nil) {
            SpringBoard *springBoard = (SpringBoard *)[objc_getClass("SpringBoard") sharedApplication];
            [springBoard dismissKirikae];
            return;
        }
    }

    %orig;
}

#if 0
// NOTE: Only hooked when animationsEnabled == NO
- (void)animateLaunchApplication:(SBApplication *)app
{
    if ([app pid] != -1) {
        // Application is backgrounded

        // FIXME: Find a better solution for the Categories "transparent-window" issue
        if ([[app displayIdentifier] hasPrefix:@"com.bigboss.categories."]) {
            // Make sure SpringBoard dock and icons are hidden
            [[objc_getClass("SBIconController") sharedInstance] scatter:NO startTime:CFAbsoluteTimeGetCurrent()];
            [self showButtonBar:NO animate:NO action:NULL delegate:nil];
        }

        // Launch without animation
        // FIXME: Originally Activating (and not Active)
        [SBWActiveDisplayStack pushDisplay:app];
    } else {
        // Normal launch
        %orig;
    }
}

#endif

%end

//==============================================================================

%hook SBVoiceControlAlert

+ (BOOL)shouldEnterVoiceControl
{
    BOOL flag = %orig;
    if (flag) {
        // Voice Control will appear; dismiss Kirikae
        SpringBoard *springBoard = (SpringBoard *)[objc_getClass("SpringBoard") sharedApplication];
        [springBoard dismissKirikae];
    }
    return flag;
}

%end

//==============================================================================

%hook SBStatusBarController

- (void)setStatusBarMode:(int)mode orientation:(int)orientation duration:(double)duration
    fenceID:(int)fenceID animation:(int)animation startTime:(double)startTime
{
    // Prevent modifcation of the statusbar while Kirikae is invoked
    if (![(KirikaeDisplay *)[kirikae display] isInvoked])
        %orig;
}

%end

//==============================================================================

%hook SBStatusWindow

- (void)orderOut:(id)unknown
{
    if ([(KirikaeDisplay *)[kirikae display] isInvoked])
        // Prevent the black statusbar from being hidden while Kirikae is invoked
        for (id view in [[[self subviews] lastObject] subviews])
            // NOTE: It's probably not necessary to check orientation
            if ([view isMemberOfClass:[objc_getClass("SBStatusBar") class]] &&
               [view mode] == 2 && [view orientation] == 0) 
               return;

    %orig;
}

%end

//==============================================================================

%group GNoAnimation
// NOTE: Only hooked when animationsEnabled == NO

%hook SpringBoard

- (void)frontDisplayDidChange
{
    if (shouldDismiss) {
        [self dismissKirikae];
        shouldDismiss = NO;
    }
    %orig;
}

%end

%end // GNoAnimation

//==============================================================================

%group GFirmware30x
// NOTE: Only hooked for firmware < 3.1

%hook SBApplication

- (void)_relaunchAfterAbnormalExit:(BOOL)flag
{
    if ([[self displayIdentifier] isEqualToString:killedApp]) {
        // We killed this app; do not let it relaunch
        [killedApp release];
        killedApp = nil;
    } else {
        %orig;
    }
}

%end

%end // GFirmware30x

%group GFirmware31x
// NOTE: Only hooked for firmware >= 3.1

%hook SBApplication

- (void)_relaunchAfterExit
{
    if ([[self displayIdentifier] isEqualToString:killedApp]) {
        // We killed this app; do not let it relaunch
        [killedApp release];
        killedApp = nil;
    } else {
        %orig;
    }
}

%end

%end // GFirmware31x

//==============================================================================

%group GSpringBoardTab
// NOTE: Only hooked when showSpringBoard == YES

%hook SBIconController

- (void)launchIcon:(SBIcon *)icon
{
    if (kirikae != nil)
        // NOTE: Normally launch will not be called if another application is active
        //       (as technically SpringBoard shouldn't be accessible in such case).
        [icon launch];
    else
        %orig;
}

%end

%hook SBIcon

- (void)grabTimerFired
{
    // Don't allow icons to be grabbed in the SpringBoard tab
    // NOTE: This is because the 'grabbed-icon' view is drawn on a different
    //       layer, and does not appear properly on the SpringBoard tab.
    if (kirikae == nil)
        %orig;
}

%end

%end // GSpringBoardTab

//==============================================================================

%group GSpotSpringTabs
// NOTE: Only hooked when showSpotlight == YES or showSpringBoard == YES

%hook SBUIController

- (void)activateApplicationAnimated:(SBApplication *)application
{
    if (kirikae != nil) {
        SpringBoard *springBoard = (SpringBoard *)[UIApplication sharedApplication];

        NSString *displayId = application.displayIdentifier;
        if ([displayId hasPrefix:@"com.bigboss.categories."] ||
                [displayId hasPrefix:@"jp.ashikase.springjumps."]) {
            // Is a category folder or a springjump, perform normal action
            %orig;

            UITabBarController *tbCont = [(KirikaeDisplay *)kirikae.display tabBarController];
            if ([tbCont.selectedViewController isMemberOfClass:[SpringBoardController class]])
                // Make sure not to hide Kirikae
                return;
        } else {
            // Not folder/jump; switch via Kirikae's method
            [springBoard switchToAppWithDisplayIdentifier:displayId];
        }

        // Hide Kirikae
        [springBoard dismissKirikae];
    } else {
        %orig;
    }
}

%end

%hook SBSearchController

- (id)_launchingURLForResult:(SPSearchResult *)result withDisplayIdentifier:(NSString *)displayId
{
    id ret = nil;

    SpringBoard *springBoard = (SpringBoard *)[UIApplication sharedApplication];
    if ([result domain] == 0x14) {
        // Application selected; launch via Kirikae's method
        // NOTE: Only appears to happen when Spotbright is installed; otherwise
        //       activateApplicationAnimated is called instead of this method.
        [springBoard switchToAppWithDisplayIdentifier:displayId];
    } else {
        // If Backgrounder is installed, enable backgrounding for current application
        if ([springBoard respondsToSelector:@selector(setBackgroundingEnabled:forDisplayIdentifier:)]) {
            SBApplication *app = [springBoard topApplication];
            if (app)
                [springBoard setBackgroundingEnabled:YES forDisplayIdentifier:[app displayIdentifier]];
        }

        // Call the original implementation to launch the selected item
        ret = %orig;
    }

    // Hide Kirikae
    [springBoard dismissKirikae];

    return ret;
}

%end

%hook SBSearchView

- (void)setShowsKeyboard:(BOOL)show animated:(BOOL)animated
{
    if (kirikae != nil) {
        if (show && !self.isKeyboardVisible) {
            UIKeyboard *&keyboard = MSHookIvar<UIKeyboard *>(self, "_keyboard");
            // The very first time the keyboard is shown, its origin is set to
            // (0,0), causing the keyboard to animate from top of screen.
            // Set the frame manually to ensure that this doesn't happen.
            CGRect frame = keyboard.frame;
            frame.origin.y = 480.0f;
            keyboard.frame = frame;
            [[[(KirikaeDisplay *)kirikae.display tabBarController] view] addSubview:keyboard];
        }
    }

    %orig;
}

- (void)keyboardAnimationDidStop:(id)animation finished:(id)finished context:(void *)context
{
    %orig;

    // NOTE: Failing to remove animations causes normal Spotlight animation to fail
    // NOTE: Do this even if kirikae == nil, as Kirikae may have disappeared
    //       before the keyboard animation finished (and thus *had been* invoked).
    // FIXME: Where is this animation coming from?
    UIKeyboard *&keyboard = MSHookIvar<UIKeyboard *>(self, "_keyboard");
    [keyboard.layer removeAllAnimations];
}

%end

%end // GSpotSpringTabs

//==============================================================================

void initSpringBoardHooks()
{
    loadPreferences();

    // Create the libactivator event listener
    // NOTE: must load this *after* loading preferences, or else default
    //       invocation method may mistakenly be set when another pre-Activator
    //       method is already enabled.
    [KirikaeActivator load];

    if (!animationsEnabled)
        %init(GNoAnimation);

    // NOTE: This method name changed from 3.0(.1) -> 3.1
    if ([[[UIDevice currentDevice] systemVersion] hasPrefix:@"3.0"])
        %init(GFirmware30x);
    else
        %init(GFirmware31x);

#if 0
    LOAD_HOOK(SBApplication, pathForDefaultImage:, pathForDefaultImage$);
#endif

    // Check if Spotlight or SpringBoard tabs are enabled
    Boolean valid;
    BOOL showSpotlight = CFPreferencesGetAppBooleanValue(CFSTR("showSpotlight"), CFSTR(APP_ID), &valid);
    if (!valid)
        showSpotlight = NO;

    BOOL showSpringBoard = CFPreferencesGetAppBooleanValue(CFSTR("showSpringBoard"), CFSTR(APP_ID), &valid);
    if (!valid)
        showSpringBoard = NO;

    if (showSpotlight || showSpringBoard)
        %init(GSpotSpringTabs);

    if (showSpringBoard)
        %init(GSpringBoardTab);
#if 0
    if (!animationsEnabled)
        LOAD_HOOK($SBUIController, @selector(animateLaunchApplication:), SBUIController$animateLaunchApplication$);
#endif

    // Initialize non-grouped hooks
    %init;

    // Initialize Kirikae* classes
    initKirikae();
}

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
