/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-09-21 14:00:24
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
#import <QuartzCore/CABase.h>

#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBAlertItemsController.h>
#import <SpringBoard/SBAwayController.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SBDisplayStack.h>
#import <SpringBoard/SBStatusBarController.h>
#import <SpringBoard/SBUIController.h>
#import <SpringBoard/SBVoiceControlAlert.h>
#import <SpringBoard/SpringBoard.h>

#import "TaskMenuPopup.h"

struct GSEvent;


#define HOME_SHORT_PRESS 0
#define HOME_DOUBLE_TAP 1
static int invocationMethod = HOME_DOUBLE_TAP;

static NSMutableArray *activeApps = nil;

//static NSMutableDictionary *statusBarStates = nil;
//static NSString *deactivatingApp = nil;

static NSString *killedApp = nil;

//static BOOL animateStatusBar = YES;
static BOOL animationsEnabled = YES;

//______________________________________________________________________________
//______________________________________________________________________________

static void loadPreferences()
{
    CFPropertyListRef propList = CFPreferencesCopyAppValue(CFSTR("invocationMethod"), CFSTR(APP_ID));
    if (propList) {
        // NOTE: Defaults to HOME_SHORT_PRESS
        if ([(NSString *)propList isEqualToString:@"homeDoubleTap"])
            invocationMethod = HOME_DOUBLE_TAP;
        CFRelease(propList);
    }

    propList = CFPreferencesCopyAppValue(CFSTR("animationsEnabled"), CFSTR(APP_ID));
    if (propList) {
        if (CFGetTypeID(propList) == CFBooleanGetTypeID())
            animationsEnabled = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
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

//______________________________________________________________________________
//______________________________________________________________________________

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

//______________________________________________________________________________
//______________________________________________________________________________

// The alert window displays instructions when the home button is held down
static NSTimer *invocationTimer = nil;
static BOOL invocationTimerDidFire = NO;
static id alert = nil;

static void cancelInvocationTimer()
{
    // Disable and release timer (may be nil)
    [invocationTimer invalidate];
    [invocationTimer release];
    invocationTimer = nil;
}

// NOTE: Only hooked when invocationMethod == HOME_SHORT_PRESS
HOOK(SpringBoard, menuButtonDown$, void, GSEvent *event)
{
    // FIXME: If already invoked, should not set timer... right? (needs thought)
    if (![[objc_getClass("SBAwayController") sharedAwayController] isLocked]) {
        // Not locked
        if (!alert)
            // Task menu is not visible; setup toggle-delay timer
            invocationTimer = [[NSTimer scheduledTimerWithTimeInterval:0.7f
                target:self selector:@selector(invokeKirikae)
                userInfo:nil repeats:NO] retain];
        invocationTimerDidFire = NO;
    }

    CALL_ORIG(SpringBoard, menuButtonDown$, event);
}

// NOTE: Only hooked when invocationMethod == HOME_SHORT_PRESS
HOOK(SpringBoard, menuButtonUp$, void, GSEvent *event)
{
    if (!invocationTimerDidFire)
        cancelInvocationTimer();

    CALL_ORIG(SpringBoard, menuButtonUp$, event);
}

// NOTE: Only hooked when invocationMethod == HOME_DOUBLE_TAP
HOOK(SpringBoard, handleMenuDoubleTap, void)
{
    if (![[objc_getClass("SBAwayController") sharedAwayController] isLocked]) {
        // Not locked
        if (alert == nil) {
            // Popup not active; invoke and return
            [self invokeKirikae];
            return;
        } else {
            // Popup is active; dismiss and perform normal behaviour
            [self dismissKirikae];
        }
    }

    CALL_ORIG(SpringBoard, handleMenuDoubleTap);
}

HOOK(SpringBoard, _handleMenuButtonEvent, void)
{
    // Handle single tap
    if (alert) {
        // Task menu is visible
        // FIXME: with short press, the task menu may have just been invoked...
        if (invocationTimerDidFire == NO)
            // Hide and destroy the task menu
            [self dismissKirikae];

        // NOTE: _handleMenuButtonEvent is responsible for resetting the home tap count
        Ivar ivar = class_getInstanceVariable([self class], "_menuButtonClickCount");
        unsigned int *_menuButtonClickCount = (unsigned int *)((char *)self + ivar_getOffset(ivar));
        *_menuButtonClickCount = 0x8000;
    } else {
        CALL_ORIG(SpringBoard, _handleMenuButtonEvent);
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

    // NOTE: The initial capacity value was chosen to hold the default active
    //       apps (MobilePhone and MobileMail) plus two others
    activeApps = [[NSMutableArray alloc] initWithCapacity:4];

#if 0
    // Create a dictionary to store the statusbar state for active apps
    // FIXME: Determine a way to do this without requiring extra storage
    statusBarStates = [[NSMutableDictionary alloc] initWithCapacity:5];
#endif

    // Initialize task menu popup
    initTaskMenuPopup();

    CALL_ORIG(SpringBoard, applicationDidFinishLaunching$, application);
}

HOOK(SpringBoard, dealloc, void)
{
    [killedApp release];
    [activeApps release];
    [displayStacks release];
    CALL_ORIG(SpringBoard, dealloc);
}

static void $SpringBoard$invokeKirikae(SpringBoard *self, SEL sel)
{
    if (alert)
        // Kirikae is already visible
        // NOTE: This check is needed when called by external invokers
        return;

    if (invocationMethod == HOME_SHORT_PRESS)
        invocationTimerDidFire = YES;

    id app = [SBWActiveDisplayStack topApplication];
    NSString *identifier = [app displayIdentifier];

    // Display task menu popup
    NSMutableArray *array = [NSMutableArray arrayWithArray:activeApps];
    if (identifier) {
        // Is an application
        // This array will be used for "other apps", so remove the active app
        [array removeObject:identifier];

        // SpringBoard should always be first in the list of other applications
        [array insertObject:@"com.apple.springboard" atIndex:0];
    } else {
        // Is SpringBoard
        identifier = @"com.apple.springboard";
    }

    alert = [[objc_getClass("KirikaeAlert") alloc] initWithCurrentApp:identifier otherApps:array];
    [(SBAlert *)alert activate];
}

static void $SpringBoard$dismissKirikae(SpringBoard *self, SEL sel)
{
    // FIXME: If feedback types other than simple and task-menu are added,
    //        this method will need to be updated

    // Hide and release alert window (may be nil)
    [[alert display] dismiss];
    [alert release];
    alert = nil;
}

static void $SpringBoard$switchToAppWithDisplayIdentifier$(SpringBoard *self, SEL sel, NSString *identifier)
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

static void $SpringBoard$quitAppWithDisplayIdentifier$(SpringBoard *self, SEL sel, NSString *identifier)
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

//______________________________________________________________________________
//______________________________________________________________________________

HOOK(SBApplication, launchSucceeded$, void, BOOL unknownFlag)
{
    NSString *identifier = [self displayIdentifier];
    if (![activeApps containsObject:identifier])
        // Track active status of application
        [activeApps addObject:identifier];

    CALL_ORIG(SBApplication, launchSucceeded$, unknownFlag);
}

HOOK(SBApplication, exitedAbnormally, void)
{
#if 0
    if (animationsEnabled && ![self isSystemApplication])
        [[NSFileManager defaultManager] removeItemAtPath:[self defaultImage:"Default"] error:nil];
#endif

    CALL_ORIG(SBApplication, exitedAbnormally);
}

HOOK(SBApplication, exitedCommon, void)
{
    // Application has exited (either normally or abnormally);
    // remove from active applications list
    NSString *identifier = [self displayIdentifier];
    [activeApps removeObject:identifier];

#if 0
    // ... also remove status bar state data from states list
    [statusBarStates removeObjectForKey:identifier];
#endif

    CALL_ORIG(SBApplication, exitedCommon);
}

HOOK(SBApplication, deactivate, BOOL)
{
#if 0
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
#endif

    return CALL_ORIG(SBApplication, deactivate);

}

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

// NOTE: Only hooked when invocationMethod == HOME_SHORT_PRESS
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

void initSpringBoardHooks()
{
    loadPreferences();

    Class $SBDisplayStack(objc_getClass("SBDisplayStack"));
    LOAD_HOOK($SBDisplayStack, @selector(init), SBDisplayStack$init);
    LOAD_HOOK($SBDisplayStack, @selector(dealloc), SBDisplayStack$dealloc);

#if 0
    Class $SBStatusBarController(objc_getClass("SBStatusBarController"));
    LOAD_HOOK($SBStatusBarController, @selector(setStatusBarMode:orientation:duration:fenceID:animation:),
        SBStatusBarController$setStatusBarMode$mode$orientation$duration$fenceID$animation$);

    if (!animationsEnabled) {
        Class $SBUIController(objc_getClass("SBUIController"));
        LOAD_HOOK($SBUIController, @selector(animateLaunchApplication:), SBUIController$animateLaunchApplication$);
    }
#endif

    Class $SpringBoard(objc_getClass("SpringBoard"));
    LOAD_HOOK($SpringBoard, @selector(applicationDidFinishLaunching:), SpringBoard$applicationDidFinishLaunching$);
    LOAD_HOOK($SpringBoard, @selector(dealloc), SpringBoard$dealloc);

    if (invocationMethod == HOME_DOUBLE_TAP) {
        LOAD_HOOK($SpringBoard, @selector(handleMenuDoubleTap), SpringBoard$handleMenuDoubleTap);
    } else {
        LOAD_HOOK($SpringBoard, @selector(menuButtonDown:), SpringBoard$menuButtonDown$);
        LOAD_HOOK($SpringBoard, @selector(menuButtonUp:), SpringBoard$menuButtonUp$);
    }
    LOAD_HOOK($SpringBoard, @selector(_handleMenuButtonEvent), SpringBoard$_handleMenuButtonEvent);

    if (!animationsEnabled)
        LOAD_HOOK($SpringBoard, @selector(frontDisplayDidChange), SpringBoard$frontDisplayDidChange);

    class_addMethod($SpringBoard, @selector(invokeKirikae), (IMP)&$SpringBoard$invokeKirikae, "v@:");
    class_addMethod($SpringBoard, @selector(dismissKirikae), (IMP)&$SpringBoard$dismissKirikae, "v@:");
    class_addMethod($SpringBoard, @selector(switchToAppWithDisplayIdentifier:), (IMP)&$SpringBoard$switchToAppWithDisplayIdentifier$, "v@:@");
    class_addMethod($SpringBoard, @selector(quitAppWithDisplayIdentifier:), (IMP)&$SpringBoard$quitAppWithDisplayIdentifier$, "v@:@");

    Class $SBApplication(objc_getClass("SBApplication"));
    LOAD_HOOK($SBApplication, @selector(launchSucceeded:), SBApplication$launchSucceeded$);
    LOAD_HOOK($SBApplication, @selector(deactivate), SBApplication$deactivate);
    LOAD_HOOK($SBApplication, @selector(exitedAbnormally), SBApplication$exitedAbnormally);
    LOAD_HOOK($SBApplication, @selector(exitedCommon), SBApplication$exitedCommon);
    LOAD_HOOK($SBApplication, @selector(_relaunchAfterAbnormalExit:), SBApplication$_relaunchAfterAbnormalExit$);
#if 0
    LOAD_HOOK($SBApplication, @selector(pathForDefaultImage:), SBApplication$pathForDefaultImage$);
#endif

    if (invocationMethod == HOME_SHORT_PRESS) {
        Class $SBVoiceControlAlert = objc_getMetaClass("SBVoiceControlAlert");
        LOAD_HOOK($SBVoiceControlAlert, @selector(shouldEnterVoiceControl), SBVoiceControlAlert$shouldEnterVoiceControl);
    }
}

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
