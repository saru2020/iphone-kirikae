/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-12-19 22:42:44
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

#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBAlertItemsController.h>
#import <SpringBoard/SBAwayController.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SBDisplayStack.h>
#import <SpringBoard/SBPowerDownController.h>
#import <SpringBoard/SBSearchController.h>
#import <SpringBoard/SBSearchView.h>
#import <SpringBoard/SBStatusBarController.h>
#import <SpringBoard/SBUIController.h>
#import <SpringBoard/SBVoiceControlAlert.h>
#import <SpringBoard/SpringBoard.h>

@interface SPSearchResult : NSObject
@property(assign, nonatomic) int domain;
@end

#import "Kirikae.h"
#import "SpringBoardController.h"


//static BOOL animateStatusBar = YES;
static BOOL animationsEnabled = YES;

typedef enum {
    KKInvocationMethodNone,
    KKInvocationMethodMenuSingleTap,
    KKInvocationMethodMenuDoubleTap,
    KKInvocationMethodMenuShortHold,
    KKInvocationMethodLockShortHold
} KKInvocationMethod;

static KKInvocationMethod invocationMethod = KKInvocationMethodMenuDoubleTap;


//static NSMutableDictionary *statusBarStates = nil;
//static NSString *deactivatingApp = nil;

static NSString *killedApp = nil;

//______________________________________________________________________________
//______________________________________________________________________________

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

//______________________________________________________________________________
//______________________________________________________________________________

NSMutableArray *displayStacks = nil;

// Display stack names
#define SBWPreActivateDisplayStack        [displayStacks objectAtIndex:0]
#define SBWActiveDisplayStack             [displayStacks objectAtIndex:1]
#define SBWSuspendingDisplayStack         [displayStacks objectAtIndex:2]
#define SBWSuspendedEventOnlyDisplayStack [displayStacks objectAtIndex:3]

HOOK(SBDisplayStack, init, id)
{
    id stack = CALL_ORIG(SBDisplayStack, init);
    [displayStacks addObject:stack];
    return stack;
}

HOOK(SBDisplayStack, dealloc, void)
{
    [displayStacks removeObject:self];
    CALL_ORIG(SBDisplayStack, dealloc);
}

//______________________________________________________________________________
//______________________________________________________________________________

#if 0
HOOK(SBStatusBarController, setStatusBarMode$mode$orientation$duration$fenceID$animation$,
    void, int mode, int orientation, float duration, int fenceID, int animation)
{
    if (!animateStatusBar) {
        duration = 0;
        // Reset the flag to default (animation enabled)
        animateStatusBar = YES;
    }
    CALL_ORIG(SBStatusBarController, setStatusBarMode$mode$orientation$duration$fenceID$animation$,
            mode, orientation, duration, fenceID, animation);
}

#endif

//______________________________________________________________________________
//______________________________________________________________________________

static NSTimer *invocationTimer = nil;
static BOOL invocationTimerDidFire = NO;
static Kirikae *kirikae = nil;

static BOOL canInvoke()
{
    // Should not invoke if either lock screen or power-off screen is active
    return !([[objc_getClass("SBAwayController") sharedAwayController] isLocked]
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

// NOTE: Only hooked when invocationMethod == KKInvocationMethodMenuShortHold
HOOK(SpringBoard, _setMenuButtonTimer$, void, id timer)
{
    if (timer)
        startInvocationTimer();
    else if (!invocationTimerDidFire)
        cancelInvocationTimer();

    CALL_ORIG(SpringBoard, _setMenuButtonTimer$, timer);
}

// NOTE: Only hooked when invocationMethod == KKInvocationMethodLockShortHold
HOOK(SpringBoard, lockButtonDown$, void, GSEventRef event)
{
    startInvocationTimer();
    CALL_ORIG(SpringBoard, lockButtonDown$, event);
}

// NOTE: Only hooked when invocationMethod == KKInvocationMethodLockShortHold
HOOK(SpringBoard, lockButtonUp$, void, GSEventRef event)
{
    if (!invocationTimerDidFire) {
        cancelInvocationTimer();

        if (kirikae != nil)
            // Kirikae is invoked; dismiss
            [self dismissKirikae];
        else
            return CALL_ORIG(SpringBoard, lockButtonUp$, event);
    }

    // Reset the lock button state
    [self _unsetLockButtonBearTrap];
    [self _setLockButtonTimer:nil];
}

// NOTE: Only hooked when invocationMethod == KKInvocationMethodMenuDoubleTap
HOOK(SpringBoard, allowMenuDoubleTap, BOOL)
{
    return YES;
}

HOOK(SpringBoard, handleMenuDoubleTap, void)
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

    CALL_ORIG(SpringBoard, handleMenuDoubleTap);
}

HOOK(SpringBoard, _handleMenuButtonEvent, void)
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
            CALL_ORIG(SpringBoard, _handleMenuButtonEvent);
        }
    }
}

// NOTE: Only hooked when animationsEnabled == NO
HOOK(SpringBoard, frontDisplayDidChange, void)
{
    [self dismissKirikae];
    CALL_ORIG(SpringBoard, frontDisplayDidChange);
}

HOOK(SpringBoard, applicationDidFinishLaunching$, void, id application)
{
    // NOTE: SpringBoard creates four stacks at startup:
    displayStacks = [[NSMutableArray alloc] initWithCapacity:5];

#if 0
    // Create a dictionary to store the statusbar state for active apps
    // FIXME: Determine a way to do this without requiring extra storage
    statusBarStates = [[NSMutableDictionary alloc] initWithCapacity:5];
#endif

    CALL_ORIG(SpringBoard, applicationDidFinishLaunching$, application);
}

HOOK(SpringBoard, dealloc, void)
{
    [killedApp release];
    [displayStacks release];
    CALL_ORIG(SpringBoard, dealloc);
}

METH(SpringBoard, kirikae, Kirikae *)
{
    return kirikae;
}

METH(SpringBoard, invokeKirikae, void)
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

METH(SpringBoard, dismissKirikae, void)
{
    // FIXME: If feedback types other than simple and task-menu are added,
    //        this method will need to be updated

    // Hide and release kirikae window (may be nil)
    [[kirikae display] dismiss];
    [kirikae release];
    kirikae = nil;
}

METH(SpringBoard, switchToAppWithDisplayIdentifier$, void, NSString *identifier)
{
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
                if (![identifier isEqualToString:@"com.apple.springboard"]) {
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

    if (animationsEnabled)
        // Hide the task menu
        [self dismissKirikae];
}

METH(SpringBoard, quitAppWithDisplayIdentifier$, void, NSString *identifier)
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

METH(SpringBoard, topApplication, SBApplication *)
{
    return [SBWActiveDisplayStack topApplication];
}

//______________________________________________________________________________
//______________________________________________________________________________

#if 0
// NOTE: Only hooked when animationsEnabled == NO
HOOK(SBUIController, animateLaunchApplication$, void, id app)
{
    if ([app pid] != -1) {
        // Application is backgrounded

        // FIXME: Find a better solution for the Categories "transparent-window" issue
        if ([[app displayIdentifier] hasPrefix:@"com.bigboss.categories."]) {
            // Make sure SpringBoard dock and icons are hidden
            [[objc_getClass("SBIconController") sharedInstance] scatter:NO startTime:CFAbsoluteTimeGetCurrent()];
            [self showButtonBar:NO animate:NO action:NULL delegate:nil];
        }

        // Prevent status bar from fading in
        animateStatusBar = NO;

        // Launch without animation
        NSArray *state = [statusBarStates objectForKey:[app displayIdentifier]];
        [app setDisplaySetting:0x10 value:[state objectAtIndex:0]]; // statusBarMode
        [app setDisplaySetting:0x20 value:[state objectAtIndex:1]]; // statusBarOrienation
        // FIXME: Originally Activating (and not Active)
        [SBWActiveDisplayStack pushDisplay:app];
    } else {
        // Normal launch
        CALL_ORIG(SBUIController, animateLaunchApplication$, app);
    }
}
#endif

// NOTE: Only hooked when showSpotlight == YES
HOOK(SBUIController, activateApplicationAnimated$, void, SBApplication *application)
{
    if (kirikae != nil) {
        SpringBoard *springBoard = (SpringBoard *)[UIApplication sharedApplication];

        NSString *displayId = application.displayIdentifier;
        if ([displayId hasPrefix:@"com.bigboss.categories."] ||
                [displayId hasPrefix:@"jp.ashikase.springjumps."]) {
            // Is a category folder or a springjump, perform normal action
            CALL_ORIG(SBUIController, activateApplicationAnimated$, application);

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
        CALL_ORIG(SBUIController, activateApplicationAnimated$, application);
    }
}

//______________________________________________________________________________
//______________________________________________________________________________

HOOK(SBApplication, activate, void)
{
    // NOTE: This gets called on both initial launch and when resumed
    //       from background.
    CALL_ORIG(SBApplication, activate);

    // Inform Kirikae of application activation (Kirikae may be nil)
    [kirikae handleApplicationActivation:self.displayIdentifier];
}

#if 0
HOOK(SBApplication, exitedAbnormally, void)
{
    if (animationsEnabled && ![self isSystemApplication])
        [[NSFileManager defaultManager] removeItemAtPath:[self defaultImage:"Default"] error:nil];

    CALL_ORIG(SBApplication, exitedAbnormally);
}
#endif

HOOK(SBApplication, exitedCommon, void)
{
    // Inform Kirikae of application termination (Kirikae may be nil)
    [kirikae handleApplicationTermination:self.displayIdentifier];

    // Remove status bar state data from states list
    //NSString *identifier = self.displayIdentifier;
    //[statusBarStates removeObjectForKey:identifier];

    CALL_ORIG(SBApplication, exitedCommon);
}

#if 0
HOOK(SBApplication, deactivate, BOOL)
{
    NSString *identifier = [self displayIdentifier];
    if ([identifier isEqualToString:deactivatingApp]) {
        [[objc_getClass("SpringBoard") sharedApplication] dismissKirikae];
        [deactivatingApp release];
        deactivatingApp = nil;
    }

    // Store the status bar state of the current application
    SBStatusBarController *sbCont = [objc_getClass("SBStatusBarController") sharedStatusBarController];
    NSNumber *mode = [NSNumber numberWithInt:[sbCont statusBarMode]];
    NSNumber *orientation = [NSNumber numberWithInt:[sbCont statusBarOrientation]];
    [statusBarStates setObject:[NSArray arrayWithObjects:mode, orientation, nil] forKey:identifier];

    return CALL_ORIG(SBApplication, deactivate);

}
#endif

// NOTE: Only hooked for firmware < 3.1
HOOK(SBApplication, _relaunchAfterAbnormalExit$, void, BOOL flag)
{
    if ([[self displayIdentifier] isEqualToString:killedApp]) {
        // We killed this app; do not let it relaunch
        [killedApp release];
        killedApp = nil;
    } else {
        CALL_ORIG(SBApplication, _relaunchAfterAbnormalExit$, flag);
    }
}

// NOTE: Only hooked for firmware >= 3.1
HOOK(SBApplication, _relaunchAfterExit, void)
{
    if ([[self displayIdentifier] isEqualToString:killedApp]) {
        // We killed this app; do not let it relaunch
        [killedApp release];
        killedApp = nil;
    } else {
        CALL_ORIG(SBApplication, _relaunchAfterExit);
    }
}

#if 0
// NOTE: Only hooked when animationsEnabled == YES
HOOK(SBApplication, pathForDefaultImage$, id, char *def)
{
    return ([self isSystemApplication] || ![activeApps containsObject:[self displayIdentifier]]) ?
        CALL_ORIG(SBApplication, pathForDefaultImage$, def) :
        [NSString stringWithFormat:@"%@/Library/Caches/Snapshots/%@-Default.jpg",
            [[self seatbeltProfilePath] stringByDeletingPathExtension], [self bundleIdentifier]];
}
#endif

//______________________________________________________________________________
//______________________________________________________________________________

// NOTE: Only hooked when showSpotlight == YES
HOOK(SBSearchController, _launchingURLForResult$withDisplayIdentifier$, id, SPSearchResult *result, NSString *displayId)
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
        ret = CALL_ORIG(SBSearchController, _launchingURLForResult$withDisplayIdentifier$, result, displayId);
    }

    // Hide Kirikae
    [springBoard dismissKirikae];

    return ret;
}

//______________________________________________________________________________
//______________________________________________________________________________

HOOK(SBIcon, grabTimerFired, void)
{
    // Don't allow icons to be grabbed in the SpringBoard tab
    // NOTE: This is because the 'grabbed-icon' view is drawn on a different
    //       layer, and does not appear properly on the SpringBoard tab.
    if (kirikae == nil)
        CALL_ORIG(SBIcon, grabTimerFired);
}

//______________________________________________________________________________
//______________________________________________________________________________

@interface UIKeyboard : UIView
@end

HOOK(SBSearchView, setShowsKeyboard$animated$, void, BOOL show, BOOL animated)
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

    CALL_ORIG(SBSearchView, setShowsKeyboard$animated$, show, animated);
}

HOOK(SBSearchView, keyboardAnimationDidStop$finished$context$, void, id animation, id finished, void *context)
{
    CALL_ORIG(SBSearchView, keyboardAnimationDidStop$finished$context$, animation, finished, context);

    // NOTE: Failing to remove animations causes normal Spotlight animation to fail
    // NOTE: Do this even if kirikae == nil, as Kirikae may have disappeared
    //       before the keyboard animation finished (and thus *had been* invoked).
    // FIXME: Where is this animation coming from?
    UIKeyboard *&keyboard = MSHookIvar<UIKeyboard *>(self, "_keyboard");
    [keyboard.layer removeAllAnimations];
}

//______________________________________________________________________________
//______________________________________________________________________________

// NOTE: Only hooked when invocationMethod == KKInvocationMethodMenuShortHold
HOOK(SBVoiceControlAlert, shouldEnterVoiceControl, BOOL)
{
    BOOL flag = CALL_ORIG(SBVoiceControlAlert, shouldEnterVoiceControl);
    if (flag) {
        // Voice Control will appear; dismiss Kirikae
        SpringBoard *springBoard = (SpringBoard *)[objc_getClass("SpringBoard") sharedApplication];
        [springBoard dismissKirikae];
    }
    return flag;
}

//______________________________________________________________________________
//______________________________________________________________________________

// NOTE: Only hooked when invocationMethod == KKInvocationMethodLockShortHold
HOOK(SBPowerDownController, activate, void)
{
    // Power-off screen will appear; dismiss Kirikae
    SpringBoard *springBoard = (SpringBoard *)[objc_getClass("SpringBoard") sharedApplication];
    [springBoard dismissKirikae];
    CALL_ORIG(SBPowerDownController, activate);
}

//______________________________________________________________________________
//______________________________________________________________________________

void initSpringBoardHooks()
{
    loadPreferences();

    GET_CLASS(SBDisplayStack);
    LOAD_HOOK(SBDisplayStack, init, init);
    LOAD_HOOK(SBDisplayStack, dealloc, dealloc);

#if 0
    Class $SBStatusBarController = objc_getClass("SBStatusBarController");
    LOAD_HOOK($SBStatusBarController, @selector(setStatusBarMode:orientation:duration:fenceID:animation:),
        SBStatusBarController$setStatusBarMode$mode$orientation$duration$fenceID$animation$);
#endif

    GET_CLASS(SpringBoard);
    LOAD_HOOK(SpringBoard, applicationDidFinishLaunching:, applicationDidFinishLaunching$);
    LOAD_HOOK(SpringBoard, dealloc, dealloc);
    LOAD_HOOK(SpringBoard, handleMenuDoubleTap, handleMenuDoubleTap);
    LOAD_HOOK(SpringBoard, _handleMenuButtonEvent, _handleMenuButtonEvent);
    if (!animationsEnabled)
        LOAD_HOOK(SpringBoard, frontDisplayDidChange, frontDisplayDidChange);
    ADD_METH(SpringBoard, kirikae, kirikae, "@@:");
    ADD_METH(SpringBoard, invokeKirikae, invokeKirikae, "v@:");
    ADD_METH(SpringBoard, dismissKirikae, dismissKirikae, "v@:");
    ADD_METH(SpringBoard, switchToAppWithDisplayIdentifier:, switchToAppWithDisplayIdentifier$, "v@:@");
    ADD_METH(SpringBoard, quitAppWithDisplayIdentifier:, quitAppWithDisplayIdentifier$, "v@:@");
    ADD_METH(SpringBoard, topApplication, topApplication, "@@:");

    GET_CLASS(SBApplication);
    LOAD_HOOK(SBApplication, activate, activate);

#if 0
    LOAD_HOOK(SBApplication, deactivate, deactivate);
    LOAD_HOOK(SBApplication, exitedAbnormally, exitedAbnormally);
#endif
    LOAD_HOOK(SBApplication, exitedCommon, exitedCommon);

    // NOTE: This method name changed from 3.0(.1) -> 3.1
    if ([[[UIDevice currentDevice] systemVersion] hasPrefix:@"3.0"])
        LOAD_HOOK(SBApplication, _relaunchAfterAbnormalExit:, _relaunchAfterAbnormalExit$);
    else
        LOAD_HOOK(SBApplication, _relaunchAfterExit, _relaunchAfterExit);

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

    if (showSpotlight || showSpringBoard) {
        // Spotlight and/or SpringBoard tab is enabled; set necessary hooks
        GET_CLASS(SBUIController);
        LOAD_HOOK(SBUIController, activateApplicationAnimated:, activateApplicationAnimated$);

        GET_CLASS(SBSearchController);
        LOAD_HOOK(SBSearchController, _launchingURLForResult:withDisplayIdentifier:, _launchingURLForResult$withDisplayIdentifier$);

        GET_CLASS(SBSearchView);
        LOAD_HOOK(SBSearchView, setShowsKeyboard:animated:, setShowsKeyboard$animated$);
        LOAD_HOOK(SBSearchView, keyboardAnimationDidStop:finished:context:, keyboardAnimationDidStop$finished$context$);
    }

    if (showSpringBoard) {
        GET_CLASS(SBIcon);
        LOAD_HOOK(SBIcon, grabTimerFired, grabTimerFired);
    }

#if 0
    if (!animationsEnabled)
        LOAD_HOOK($SBUIController, @selector(animateLaunchApplication:), SBUIController$animateLaunchApplication$);
#endif

    switch (invocationMethod) {
        case KKInvocationMethodMenuDoubleTap:
            LOAD_HOOK(SpringBoard, allowMenuDoubleTap, allowMenuDoubleTap);
            break;
        case KKInvocationMethodMenuShortHold:
            LOAD_HOOK(SpringBoard, _setMenuButtonTimer:, _setMenuButtonTimer$);
            {
                GET_CLASS(SBVoiceControlAlert);
                LOAD_HOOK(SBVoiceControlAlert, shouldEnterVoiceControl, shouldEnterVoiceControl);
            }
            break;
        case KKInvocationMethodLockShortHold:
            LOAD_HOOK(SpringBoard, lockButtonDown:, lockButtonDown$);
            LOAD_HOOK(SpringBoard, lockButtonUp:, lockButtonUp$);
            {
                GET_CLASS(SBPowerDownController);
                LOAD_HOOK(SBPowerDownController, activate, activate);
            }
            break;
        case KKInvocationMethodNone:
        default:
            break;
    }

    // Initialize Kirikae* classes
    initKirikae();
}

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
