/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-02-21 15:17:28
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


#import "Kirikae.h"

#import <objc/runtime.h>

//#import <SpringBoard/SBStatusBarController.h>
#import <SpringBoard/SBSearchController.h>
#import <SpringBoard/SBSearchView.h>
#import <SpringBoard/SBStatusBarController.h>

#import "FavoritesController.h"
#import "SpotlightController.h"
#import "SpringBoardController.h"
#import "SpringBoardHooks.h"
#import "TaskListController.h"

@interface UITabBarController (Private)
- (id)_transitionView;
@end

//______________________________________________________________________________
//______________________________________________________________________________

@implementation UITabBarController (Kirikae)

- (void)setTabBarHidden:(BOOL)hidden animate:(BOOL)animate
{
    // NOTE: This doesn't actually hide the tabbar; currently it slides it down
    //       so that only the top portion (20px) is left visible

    // Determine the necessary transform/frame sizes
    CGRect tranFrame;
    CGRect wrapFrame;
    CGAffineTransform transform;
    float alpha;
    if (hidden) {
        // Hide tabbar, make transform/wrapper views "fullscreen"
        transform = CGAffineTransformMakeTranslation(0, self.tabBar.frame.size.height - 20);
        alpha = 0.65f;
        tranFrame = CGRectMake(0, 0, 320.0f, 480.0f);
        wrapFrame = CGRectMake(0, 20.0f, 320.0f, 460.0f);
    } else {
        // Show tabbar, restore transform/wrapper view to normal size
        transform = CGAffineTransformIdentity;
        alpha = 1.0f;
        tranFrame = CGRectMake(0, 0, 320.0f, 431.0f);
        wrapFrame = CGRectMake(0, 0, 320.0f, 411.0f);
    }

    // Set the transition/wrapper frames
	UIView *transitionView = [self _transitionView];
    UIView *wrapperView = [[transitionView subviews] objectAtIndex:0];
    transitionView.frame = tranFrame;
    wrapperView.frame = wrapFrame;

    // Show/hide the tabbar, optionally animated
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:(animate ? 0.2f : 0)];
    self.tabBar.transform = transform;
    self.tabBar.alpha = alpha;
    [UIView commitAnimations];
}

@end

//______________________________________________________________________________
//______________________________________________________________________________

@implementation KKTabBarController

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

    // FIXME: Find a better way to handle this
    SBSearchView *searchView = [[objc_getClass("SBSearchController") sharedInstance] searchView];
    searchView.frame = CGRectMake(0, 0, 320.0f, 350.0f);
}

@end

//______________________________________________________________________________
//______________________________________________________________________________

typedef enum {
    KKInitialViewActive,
    KKInitialViewFavorites,
    KKInitialViewSpotlight,
    KKInitialViewSpringBoard,
    KKInitialViewLastUsed
} KKInitialView;

static KKInitialView initialView = KKInitialViewActive;

static BOOL showActive = YES;
static BOOL showFavorites = YES;
static BOOL showSpotlight = NO;
static BOOL showSpringBoard = NO;

%hook KirikaeDisplay

%new(@@:{CGSize=ff})
- (id)initWithSize:(CGSize)size
{
    CGRect rect = CGRectMake(0, 0, size.width, size.height);

    objc_super $super = {self, objc_getClass("SBAlertDisplay")};
    self = objc_msgSendSuper(&$super, @selector(initWithFrame:), rect);
    if (self) {
        [self setBackgroundColor:[UIColor colorWithWhite:0.30 alpha:1]];

        // Preferences may have changed since last read; synchronize
        CFPreferencesAppSynchronize(CFSTR(APP_ID));

        // Determine whether or not to show Active tab
        CFPropertyListRef propList = CFPreferencesCopyAppValue(CFSTR("showActive"), CFSTR(APP_ID));
        if (propList) {
            if (CFGetTypeID(propList) == CFBooleanGetTypeID())
                showActive = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
            CFRelease(propList);
        }

        // Determine whether or not to show Favorites tab
        propList = CFPreferencesCopyAppValue(CFSTR("showFavorites"), CFSTR(APP_ID));
        if (propList) {
            if (CFGetTypeID(propList) == CFBooleanGetTypeID())
                showFavorites = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
            CFRelease(propList);
        }

        // Determine whether or not to show Spotlight tab
        propList = CFPreferencesCopyAppValue(CFSTR("showSpotlight"), CFSTR(APP_ID));
        if (propList) {
            if (CFGetTypeID(propList) == CFBooleanGetTypeID())
                showSpotlight = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
            CFRelease(propList);
        }

        // Determine whether or not to show SpringBoard tab
        propList = CFPreferencesCopyAppValue(CFSTR("showSpringBoard"), CFSTR(APP_ID));
        if (propList) {
            if (CFGetTypeID(propList) == CFBooleanGetTypeID())
                showSpringBoard = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
            CFRelease(propList);
        }

        // Create and setup tab bar controller and view controllers
        KKTabBarController *&tbCont = MSHookIvar<KKTabBarController *>(self, "tabBarController");
        tbCont = [[KKTabBarController alloc] init];
        NSMutableArray *&tabs = MSHookIvar<NSMutableArray *>(self, "tabs");
        tabs = [[NSMutableArray alloc] init];

        NSMutableArray *viewConts = [NSMutableArray array];
        UIViewController *cont = nil;

        // Active tab
        if (showActive) {
            [tabs addObject:@"active"];
            cont = [[TaskListController alloc] initWithStyle:UITableViewStylePlain];
            [viewConts addObject:cont];
            [cont release];
        }

        // Favorites tab
        if (showFavorites) {
            [tabs addObject:@"favorites"];
            cont = [[FavoritesController alloc] initWithStyle:UITableViewStylePlain];
            [viewConts addObject:cont];
            [cont release];
        }

        // Spotlight tab
        if (showSpotlight) {
            [tabs addObject:@"spotlight"];
            cont = [[SpotlightController alloc] initWithNibName:nil bundle:nil];
            [viewConts addObject:cont];
            [cont release];
        }

        // SpringBoard tab
        if (showSpringBoard) {
            [tabs addObject:@"springboard"];
            cont = [[SpringBoardController alloc] initWithNibName:nil bundle:nil];
            [viewConts addObject:cont];
            [cont release];
        }

        tbCont.viewControllers = viewConts;
        [self addSubview:tbCont.view];

        // Check preferences to determine which tab to start with
        unsigned int initialIndex = 0;
        propList = CFPreferencesCopyAppValue(CFSTR("initialView"), CFSTR(APP_ID));
        if (propList) {
            if (CFGetTypeID(propList) == CFStringGetTypeID()) {
                if ([(NSString *)propList isEqualToString:@"lastUsed"]) {
                    initialView = KKInitialViewLastUsed;

                    // Get name of last used view
                    CFRelease(propList);
                    propList = CFPreferencesCopyAppValue(CFSTR("lastUsedView"), CFSTR(APP_ID));
                } else if ([(NSString *)propList isEqualToString:@"favorites"] && showFavorites) {
                    initialView = KKInitialViewFavorites;
                } else if ([(NSString *)propList isEqualToString:@"spotlight"] && showSpotlight) {
                    initialView = KKInitialViewSpotlight;
                } else if ([(NSString *)propList isEqualToString:@"springboard"] && showSpringBoard) {
                    initialView = KKInitialViewSpringBoard;
                } else {
                    initialView = KKInitialViewActive;
                }

                initialIndex = [tabs indexOfObject:(NSString *)propList];
                if (initialIndex == NSNotFound)
                    initialIndex = 0;
            }
            if (propList != NULL)
                // Necessary to check due to "lastUsed" case
                // NOTE: CFRelease will purposely crash if passed NULL
                CFRelease(propList);
        }
        tbCont.selectedIndex = initialIndex;

        // Set the initial position of the view as off-screen
        CGRect frame = [[UIScreen mainScreen] bounds];
        frame.origin.y += frame.size.height;
        self.frame = frame;
    }
    return self;
}

%new(v@:)
- (void)dealloc
{
    [MSHookIvar<NSMutableArray *>(self, "tabs") release];
    [MSHookIvar<KKTabBarController *>(self, "tabBarController") release];

    objc_super $super = {self, objc_getClass("SBAlertDisplay")};
    self = objc_msgSendSuper(&$super, @selector(dealloc));
}

%new(@@:)
- (KKTabBarController *)tabBarController
{
    return MSHookIvar<KKTabBarController *>(self, "tabBarController");
}

%new(c@:)
- (BOOL)isInvoked
{
    return MSHookIvar<BOOL>(self, "invoked");
}

%new(v@:)
- (void)alertDisplayBecameVisible
{
    // Display a black status bar at top of (portrait) screen
    SBStatusBarController *sbCont = [objc_getClass("SBStatusBarController") sharedStatusBarController];
    [sbCont setStatusBarMode:2 orientation:0 duration:0.2f animation:0];

    // FIXME: The proper method for animating an SBAlertDisplay is currently
    //        unknown; for now, the following method seems to work well enough
    [UIView beginAnimations:nil context:NULL];
    [self setFrame:[[UIScreen mainScreen] bounds]];
    [UIView commitAnimations];

    // Mark Kirikae as being visible
    BOOL &invoked = MSHookIvar<BOOL>(self, "invoked");
    invoked = YES;

    // NOTE: There is no need to call the superclass's method, as its
    //       implementation does nothing
}

%new(v@:)
- (void)dismiss
{
    // Mark Kirikae as no longer being invoked
    BOOL &invoked = MSHookIvar<BOOL>(self, "invoked");
    invoked = NO;

    // Restore statusbar state
    SpringBoard *springBoard = (SpringBoard *)[UIApplication sharedApplication];
    SBApplication *app = [springBoard topApplication];
    SBStatusBarController *sbCont = [objc_getClass("SBStatusBarController") sharedStatusBarController];
    if (app != nil)
        // Set statusbar to use mode/orientation specified by top application
        [sbCont setStatusBarMode:[app statusBarMode] orientation:[app statusBarOrientation] duration:0.2f animation:0];
    else
        // No top application (is SpringBoard)
        // NOTE: This is needed as closing an app with a white/gray bar takes
        //       the bar with it, causing it to be hidden when returning to
        //       SpringBoard.
        [[sbCont statusBarWindow] setHidden:NO];

    // FIXME: The proper method for animating an SBAlertDisplay is currently
    //        unknown; for now, the following method seems to work well enough
    CGRect frame = [[UIScreen mainScreen] bounds];
    frame.origin.y += frame.size.height;

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:
        @selector(alertDidAnimateOut:finished:context:)];
    self.frame = frame;
    [UIView commitAnimations];
}

%new(v@:@@^v)
- (void)alertDidAnimateOut:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
    if (initialView == KKInitialViewLastUsed) {
        // Note which view is currently selected, save to preferences
        KKTabBarController *&tbCont = MSHookIvar<KKTabBarController *>(self, "tabBarController");
        NSMutableArray *&tabs = MSHookIvar<NSMutableArray *>(self, "tabs");
        NSString *lastUsedView = [tabs objectAtIndex:tbCont.selectedIndex];
        CFPreferencesSetAppValue(CFSTR("lastUsedView"), (CFStringRef)lastUsedView, CFSTR(APP_ID));
        CFPreferencesAppSynchronize(CFSTR(APP_ID));
    }

    // Continue dismissal by calling super's dismiss method
    objc_super $super = {self, objc_getClass("SBAlertDisplay")};
    objc_msgSendSuper(&$super, @selector(dismiss));

    [[self alert] deactivate];
}

%end

//______________________________________________________________________________
//______________________________________________________________________________

%hook Kirikae

%new(@@:{CGSize=ff})
- (id)alertDisplayViewWithSize:(CGSize)size
{
    return [[[objc_getClass("KirikaeDisplay") alloc] initWithSize:size] autorelease];
}

%new(@@:)
- (id)delegate
{
    return MSHookIvar<id>(self, "delegate");
}

%new(v@:@)
- (void)setDelegate:(id)delegate_
{
    id &delegate = MSHookIvar<id>(self, "delegate");
    delegate = delegate_;
}

%new(v@:@)
- (void)handleApplicationActivation:(NSString *)displayId
{
    id &delegate = MSHookIvar<id>(self, "delegate");
    if ([delegate respondsToSelector:@selector(kirikae:applicationDidActivate:)])
        [delegate kirikae:self applicationDidActivate:displayId];
}

%new(v@:@)
- (void)handleApplicationTermination:(NSString *)displayId
{
    id &delegate = MSHookIvar<id>(self, "delegate");
    if ([delegate respondsToSelector:@selector(kirikae:applicationDidTerminate:)])
        [delegate kirikae:self applicationDidTerminate:displayId];
}

%end

//______________________________________________________________________________
//______________________________________________________________________________

void initKirikae()
{
    unsigned int size, align;

    // Create custom alert-display class
    Class $KirikaeDisplay = objc_allocateClassPair(objc_getClass("SBAlertDisplay"), "KirikaeDisplay", 0);
    NSGetSizeAndAlignment("@", &size, &align);
    class_addIvar($KirikaeDisplay, "tabBarController", size, align, "@");
    class_addIvar($KirikaeDisplay, "tabs", size, align, "@");
    NSGetSizeAndAlignment("c", &size, &align);
    class_addIvar($KirikaeDisplay, "invoked", size, align, "c");
    NSGetSizeAndAlignment("i", &size, &align);
    class_addIvar($KirikaeDisplay, "currentStatusBarMode", size, align, "i");
    class_addIvar($KirikaeDisplay, "currentStatusBarOrientation", size, align, "i");
    objc_registerClassPair($KirikaeDisplay);

    // Create custom alert class
    Class $Kirikae = objc_allocateClassPair(objc_getClass("SBAlert"), "Kirikae", 0);
    NSGetSizeAndAlignment("@", &size, &align);
    class_addIvar($Kirikae, "delegate", size, align, "@");
    objc_registerClassPair($Kirikae);

    %init;
}

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
