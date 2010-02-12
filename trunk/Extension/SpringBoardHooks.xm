/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-01-16 01:21:20
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

@interface SPSearchResult : NSObject
@property(assign, nonatomic) int domain;
@end

#import "Kirikae.h"
#import "SpringBoardController.h"


static Kirikae *kirikae = nil;

static BOOL animationsEnabled = YES;

typedef enum {
    KKInvocationMethodNone,
    KKInvocationMethodMenuSingleTap,
    KKInvocationMethodMenuDoubleTap,
    KKInvocationMethodMenuShortHold,
    KKInvocationMethodLockShortHold
} KKInvocationMethod;

static KKInvocationMethod invocationMethod = KKInvocationMethodMenuDoubleTap;

//static NSString *deactivatingApp = nil;

static NSString *killedApp = nil;

//==============================================================================

static void loadPreferences()
{
    CFPropertyListRef propList = CFPreferencesCopyAppValue(CFSTR("animationsEnabled"), CFSTR(APP_ID));
    if (propList) {
        if (CFGetTypeID(propList) == CFBooleanGetTypeID())
            animationsEnabled = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
        CFRelease(propList);
    }

    propList = CFPreferencesCopyAppValue(CFSTR("invocationMethod"), CFSTR(APP_ID));
    if (propList) {
        // NOTE: Defaults to KKInvocationMethodMenuDoubleTap
        if ([(NSString *)propList isEqualToString:@"homeSingleTap"])
            invocationMethod = KKInvocationMethodMenuSingleTap;
        else if ([(NSString *)propList isEqualToString:@"homeShortHold"])
            invocationMethod = KKInvocationMethodMenuShortHold;
        else if ([(NSString *)propList isEqualToString:@"powerShortHold"])
            invocationMethod = KKInvocationMethodLockShortHold;
        else if ([(NSString *)propList isEqualToString:@"none"])
            invocationMethod = KKInvocationMethodNone;
        CFRelease(propList);
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

static NSTimer *invocationTimer = nil;
static BOOL invocationTimerDidFire = NO;

static BOOL canInvoke()
{
    // Should not invoke if either lock screen or power-off screen is active
    SBAwayController *awayCont = [objc_getClass("SBAwayController") sharedAwayController];
    return !([awayCont isLocked]
            || [awayCont isMakingEmergencyCall]
            || [[objc_getClass("SBIconController") sharedInstance] isEditing]
            || [[objc_getClass("SBPowerDownController") sharedInstance] isOrderedFront]);
}

static void startInvocationTimer()
{
    // FIXME: If already invoked, should not set timer... right? (needs thought)
    if (canInvoke()) {
        invocationTimerDidFire = NO;

        if (kirikae == nil) {
            // Kirikae is not invoked; setup toggle-delay timer
            SpringBoard *springBoard = (SpringBoard *)[objc_getClass("SpringBoard") sharedApplication];
            invocationTimer = [[NSTimer scheduledTimerWithTimeInterval:0.7f
                target:springBoard selector:@selector(invokeKirikae)
                userInfo:nil repeats:NO] retain];
        }
    }
}

static void cancelInvocationTimer()
{
    // Disable and release timer (may be nil)
    [invocationTimer invalidate];
    [invocationTimer release];
    invocationTimer = nil;
}

%hook SpringBoard

- (void)handleMenuDoubleTap
{
    if (kirikae != nil) {
        // Kirikae is invoked; dismiss and perform normal behaviour
        [self dismissKirikae];
    } else {
        // Kirikae not invoked
        if (invocationMethod == KKInvocationMethodMenuDoubleTap && canInvoke()) {
            // Invoke and return
            [self invokeKirikae];
            return;
        }
        // Fall-through
    }

    %orig;
}

- (void)_handleMenuButtonEvent
{
    if (kirikae != nil) {
        // Kirikae is invoked
        // FIXME: with short hold, the task menu may have just been invoked...
        if (invocationMethod != KKInvocationMethodMenuShortHold || invocationTimerDidFire == NO)
            // Hide and destroy the task menu
            [self dismissKirikae];

        // NOTE: _handleMenuButtonEvent is responsible for resetting the home tap count
        unsigned int &_menuButtonClickCount = MSHookIvar<unsigned int>(self, "_menuButtonClickCount");
        _menuButtonClickCount = 0x8000;
    } else {
        if (invocationMethod == KKInvocationMethodMenuSingleTap && canInvoke()) {
            [self invokeKirikae];

            // NOTE: _handleMenuButtonEvent is responsible for resetting the home tap count
            unsigned int &_menuButtonClickCount = MSHookIvar<unsigned int>(self, "_menuButtonClickCount");
            _menuButtonClickCount = 0x8000;
        } else {
            %orig;
        }
    }
}

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    // NOTE: SpringBoard creates four stacks at startup:
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
        // Lock screen or power-off screen is visible
        // NOTE: This is only necessary here for invocationMethod ==
        //       KKInvocationMethodNone, as canInvoke() is already called
        //       earlier for all other methods.
        return;

    // NOTE: Only used by KKInvocationMethodMenuShortHold and KKInvocationMethodLockShortHold
    invocationTimerDidFire = YES;

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
- (void)switchToAppWithDisplayIdentifier:(NSString *)identifier
{
    BOOL switchingToSpringBoard = [identifier isEqualToString:@"com.apple.springboard"];

    SBApplication *fromApp = [SBWActiveDisplayStack topApplication];
    NSString *fromIdent = fromApp ? [fromApp displayIdentifier] : @"com.apple.springboard";
    if (![fromIdent isEqualToString:identifier]) {
        // App to switch to is not the current app
        // NOTE: Save the identifier for later use
        //deactivatingApp = [fromIdent copy];

        SBApplication *toApp = [[objc_getClass("SBApplicationController") sharedInstance]
            applicationWithDisplayIdentifier:identifier];
        if (toApp) {
            // FIXME: Handle case when toApp == nil
            if ([fromIdent isEqualToString:@"com.apple.springboard"]) {
                // Switching from SpringBoard; simply activate the target app
                [toApp setDisplaySetting:0x4 flag:YES]; // animate
                if (!animationsEnabled)
                    // NOTE: animationStart can be used to delay or skip the act/deact
                    //       animation. Based on current uptime, setting it to a future
                    //       value will delay the animation; setting it to a past time
                    //       skips the animation. Setting it to now, or leaving it
                    //       unset, causes the animation to begin immediately.
                    // NOTE: The proper way to set this would be via CACurrentMediaTime(),
                    //       but using 1 (not 0) appears to work okay.
                    [toApp setActivationSetting:0x1000 value:[NSNumber numberWithDouble:1]]; // animationStart

                // Activate the target application
                [SBWPreActivateDisplayStack pushDisplay:toApp];
            } else {
                // Switching from another app
                if (!switchingToSpringBoard) {
                    // Switching to another app; setup app-to-app
                    [toApp setActivationSetting:0x40 flag:YES]; // animateOthersSuspension
                    [toApp setActivationSetting:0x20000 flag:YES]; // appToApp
                    [toApp setDisplaySetting:0x4 flag:YES]; // animate

                    if (!animationsEnabled)
                        [toApp setActivationSetting:0x1000 value:[NSNumber numberWithDouble:1]]; // animationStart

                    // Activate the target application (will wait for
                    // deactivation of current app)
                    [SBWPreActivateDisplayStack pushDisplay:toApp];
                }

                // Deactivate the current application

                // If Backgrounder is installed, enable backgrounding for current application
                if ([self respondsToSelector:@selector(setBackgroundingEnabled:forDisplayIdentifier:)])
                    [self setBackgroundingEnabled:YES forDisplayIdentifier:fromIdent];

                // NOTE: Must set animation flag for deactivation, otherwise
                //       application window does not disappear (reason yet unknown)
                [fromApp setDeactivationSetting:0x2 flag:YES]; // animate

                if (!animationsEnabled)
                    [fromApp setDeactivationSetting:0x8 value:[NSNumber numberWithDouble:1]]; // animationStart

                // Deactivate by moving from active stack to suspending stack
                [SBWActiveDisplayStack popDisplay:fromApp];
                [SBWSuspendingDisplayStack pushDisplay:fromApp];
            }
        }
    }

    if (!switchingToSpringBoard) {
        // If CategoriesSB is installed, dismiss any open categories
        SBUIController *uiCont = [objc_getClass("SBUIController") sharedInstance];
        if ([uiCont respondsToSelector:@selector(categoriesSBCloseAll)])
            [uiCont performSelector:@selector(categoriesSBCloseAll)];
    }

    if (animationsEnabled)
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

#if 0

%hook SBUIController

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

%end

#endif

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
    [self dismissKirikae];
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

%group GHomeHold
// NOTE: Only hooked when invocationMethod == KKInvocationMethodMenuShortHold

%hook SpringBoard

- (void)_setMenuButtonTimer:(id)timer
{
    if (timer)
        startInvocationTimer();
    else if (!invocationTimerDidFire)
        cancelInvocationTimer();
    %orig;
}

%end

%hook SBVoiceControlAlert

- (BOOL)shouldEnterVoiceControl
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

%end // GHomeHold

//==============================================================================

%group GHomeDoubleTap
// NOTE: Only hooked when invocationMethod == KKInvocationMethodMenuDoubleTap

%hook SpringBoard

- (BOOL)allowMenuDoubleTap
{
    return YES;
}

%end

%end // GHomeDoubleTap

//==============================================================================

%group GLockHold
// NOTE: Only hooked when invocationMethod == KKInvocationMethodLockShortHold

%hook SpringBoard

- (void)lockButtonDown:(GSEventRef)event
{
    startInvocationTimer();
    %orig;
}

- (void)lockButtonUp:(GSEventRef)event
{
    if (!invocationTimerDidFire) {
        cancelInvocationTimer();

        if (kirikae != nil)
            // Kirikae is invoked; dismiss
            [self dismissKirikae];
        else
            return %orig;
    }

    // Reset the lock button state
    [self _unsetLockButtonBearTrap];
    [self _setLockButtonTimer:nil];
}

%end

%hook SBPowerDownController

- (void)activate
{
    // Power-off screen will appear; dismiss Kirikae
    SpringBoard *springBoard = (SpringBoard *)[objc_getClass("SpringBoard") sharedApplication];
    [springBoard dismissKirikae];

    %orig;
}

%end

%end // GLockHold

//==============================================================================

void initSpringBoardHooks()
{
    loadPreferences();

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
    BOOL showSpotlight = NO;
    BOOL showSpringBoard = NO;
    CFPropertyListRef propList = CFPreferencesCopyAppValue(CFSTR("showSpotlight"), CFSTR(APP_ID));
    if (propList) {
        if (CFGetTypeID(propList) == CFBooleanGetTypeID())
            showSpotlight = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
        CFRelease(propList);
    }
    propList = CFPreferencesCopyAppValue(CFSTR("showSpringBoard"), CFSTR(APP_ID));
    if (propList) {
        if (CFGetTypeID(propList) == CFBooleanGetTypeID())
            showSpringBoard = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
        CFRelease(propList);
    }

    if (showSpotlight || showSpringBoard)
        %init(GSpotSpringTabs);

    if (showSpringBoard)
        %init(GSpringBoardTab);
#if 0
    if (!animationsEnabled)
        LOAD_HOOK($SBUIController, @selector(animateLaunchApplication:), SBUIController$animateLaunchApplication$);
#endif

    switch (invocationMethod) {
        case KKInvocationMethodMenuDoubleTap:
            %init(GHomeDoubleTap);
            break;
        case KKInvocationMethodMenuShortHold:
            %init(GHomeHold);
            break;
        case KKInvocationMethodLockShortHold:
            %init(GLockHold);
            break;
        case KKInvocationMethodNone:
        default:
            break;
    }

    // Initialize non-grouped hooks
    %init;

    // Initialize Kirikae* classes
    initKirikae();
}

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
