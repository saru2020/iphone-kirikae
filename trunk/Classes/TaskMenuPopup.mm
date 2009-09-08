/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-09-09 00:21:16
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


#import "TaskMenuPopup.h"

#import "Common.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

//#import <SpringBoard/SBStatusBarController.h>

#import "SpringBoardHooks.h"
#import "TaskListController.h"


static id $BGAlertDisplay$initWithSize$(SBAlertDisplay *self, SEL sel, CGSize size)
{
    CGRect rect = CGRectMake(0, 0, size.width, size.height);

    objc_super $super = {self, objc_getClass("SBAlertDisplay")};
    self = objc_msgSendSuper(&$super, @selector(initWithFrame:), rect);
    if (self) {
        [self setBackgroundColor:[UIColor colorWithWhite:0.30 alpha:1]];

        UITabBarController *&tbCont = MSHookIvar<UITabBarController *>(self, "tabBarController");
        tbCont = [[UITabBarController alloc] init];
        TaskListController *tlCont = [[TaskListController alloc] initWithNibName:nil bundle:NULL];
        tbCont.viewControllers = [NSArray arrayWithObjects:tlCont, nil];
        [tlCont release];
        [self addSubview:tbCont.view];

        // Set the initial position of the view as off-screen
        [self setOrigin:CGPointMake(0, size.height)];
    }
    return self;
}

static void $BGAlertDisplay$alertDisplayWillBecomeVisible(SBAlertDisplay *self, SEL sel)
{
    UITabBarController *&tbCont = MSHookIvar<UITabBarController *>(self, "tabBarController");
    TaskListController *tlCont = [tbCont.viewControllers objectAtIndex:0];
    [tlCont setCurrentApp:[[self alert] currentApp]];
    [tlCont setOtherApps:[NSMutableArray arrayWithArray:[[self alert] otherApps]]];
}

static void $BGAlertDisplay$alertDisplayBecameVisible(SBAlertDisplay *self, SEL sel)
{
#if 0
    // Task list displays a black status bar; save current status-bar settings
    SBStatusBarController *sbCont = [objc_getClass("SBStatusBarController") sharedStatusBarController];
    int &currentStatusBarMode = MSHookIvar<int>(self, "currentStatusBarMode");
    int &currentStatusBarOrientation = MSHookIvar<int>(self, "currentStatusBarOrientation");
    currentStatusBarMode = [sbCont statusBarMode];
    if (currentStatusBarMode != 2) {
        currentStatusBarOrientation = [sbCont statusBarOrientation];
        [sbCont setStatusBarMode:2 orientation:0 duration:0.4f animation:0];
    }
#endif

    // FIXME: The proper method for animating an SBAlertDisplay is currently
    //        unknown; for now, the following method seems to work well enough
    [UIView beginAnimations:nil context:NULL];
    [self setFrame:[[UIScreen mainScreen] bounds]];
    [UIView commitAnimations];

    // NOTE: There is no need to call the superclass's method, as its
    //       implementation does nothing
}

static void $BGAlertDisplay$dismiss(SBAlertDisplay *self, SEL sel)
{
#if 0
    int &currentStatusBarMode = MSHookIvar<int>(self, "currentStatusBarMode");
    if (currentStatusBarMode != 2) {
        // Restore the previous status-bar mode
        int &currentStatusBarOrientation = MSHookIvar<int>(self, "currentStatusBarOrientation");
        SBStatusBarController *sbCont = [objc_getClass("SBStatusBarController") sharedStatusBarController];
        [sbCont setStatusBarMode:currentStatusBarMode orientation:currentStatusBarOrientation
            duration:0.4f animation:0];
    }
#endif

    // FIXME: The proper method for animating an SBAlertDisplay is currently
    //        unknown; for now, the following method seems to work well enough
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:
        @selector(alertDidAnimateOut:finished:context:)];
    [self setOrigin:CGPointMake(0, [self bounds].size.height)];
    [UIView commitAnimations];
}

static void $BGAlertDisplay$alertDidAnimateOut$finished$context$(SBAlertDisplay *self, SEL sel,
    NSString *animationID, NSNumber *finished, void *context)
{
    // Continue dismissal by calling super's dismiss method
    objc_super $super = {self, objc_getClass("SBAlertDisplay")};
    objc_msgSendSuper(&$super, @selector(dismiss));

    [[self alert] deactivate];
}

//______________________________________________________________________________
//______________________________________________________________________________

static id $BGAlert$initWithCurrentApp$otherApps$(SBAlert *self, SEL sel, NSString *currentApp, NSArray *otherApps)
{
    objc_super $super = {self, objc_getClass("SBAlert")};
    self = objc_msgSendSuper(&$super, @selector(init));
    if (self) {
        object_setInstanceVariable(self, "currentApp", reinterpret_cast<void *>([currentApp retain])); 
        object_setInstanceVariable(self, "otherApps", reinterpret_cast<void *>([otherApps retain])); 
    }
    return self;
}

static void $BGAlert$dealloc(SBAlert *self, SEL sel)
{
    id currentApp = nil, otherApps = nil;
    object_getInstanceVariable(self, "currentApp", reinterpret_cast<void **>(&currentApp));
    object_getInstanceVariable(self, "otherApps", reinterpret_cast<void **>(&otherApps));
    [currentApp release];
    [otherApps release];

    objc_super $super = {self, objc_getClass("SBAlert")};
    self = objc_msgSendSuper(&$super, @selector(dealloc));
}

static NSString * $BGAlert$currentApp(SBAlert *self, SEL sel)
{
    NSString *currentApp = nil;
    object_getInstanceVariable(self, "currentApp", reinterpret_cast<void **>(&currentApp));
    return currentApp;
}

static NSArray * $BGAlert$otherApps(SBAlert *self, SEL sel)
{
    NSArray *otherApps = nil;
    object_getInstanceVariable(self, "otherApps", reinterpret_cast<void **>(&otherApps));
    return otherApps;
}

static id $BGAlert$alertDisplayViewWithSize$(SBAlert *self, SEL sel, CGSize size)
{
    return [[[objc_getClass("KirikaeAlertDisplay") alloc] initWithSize:size] autorelease];
}

//______________________________________________________________________________
//______________________________________________________________________________

void initTaskMenuPopup()
{
    // Create custom alert-display class
    Class $SBAlertDisplay(objc_getClass("SBAlertDisplay"));
    Class $BGAlertDisplay = objc_allocateClassPair($SBAlertDisplay, "KirikaeAlertDisplay", 0);
    unsigned int size, align;
    NSGetSizeAndAlignment("@", &size, &align);
    class_addIvar($BGAlertDisplay, "tabBarController", size, align, "@");
    NSGetSizeAndAlignment("i", &size, &align);
    class_addIvar($BGAlertDisplay, "currentStatusBarMode", size, align, "i");
    class_addIvar($BGAlertDisplay, "currentStatusBarOrientation", size, align, "i");
    class_addMethod($BGAlertDisplay, @selector(initWithSize:),
            (IMP)&$BGAlertDisplay$initWithSize$, "@@:{CGSize=ff}");
    class_addMethod($BGAlertDisplay, @selector(alertDisplayWillBecomeVisible),
            (IMP)&$BGAlertDisplay$alertDisplayWillBecomeVisible, "v@:");
    class_addMethod($BGAlertDisplay, @selector(alertDisplayBecameVisible),
            (IMP)&$BGAlertDisplay$alertDisplayBecameVisible, "v@:");
    class_addMethod($BGAlertDisplay, @selector(dismiss),
            (IMP)&$BGAlertDisplay$dismiss, "v@:");
    class_addMethod($BGAlertDisplay, @selector(alertDidAnimateOut:finished:context:),
            (IMP)&$BGAlertDisplay$alertDidAnimateOut$finished$context$, "v@:@@^v");
    objc_registerClassPair($BGAlertDisplay);

    // Create custom alert class
    Class $SBAlert(objc_getClass("SBAlert"));
    Class $BGAlert = objc_allocateClassPair($SBAlert, "KirikaeAlert", 0);
    NSGetSizeAndAlignment("@", &size, &align);
    class_addIvar($BGAlert, "currentApp", size, align, "@");
    class_addIvar($BGAlert, "otherApps", size, align, "@");
    class_addMethod($BGAlert, @selector(initWithCurrentApp:otherApps:),
            (IMP)&$BGAlert$initWithCurrentApp$otherApps$, "@@:@@");
    class_addMethod($BGAlert, @selector(dealloc),
            (IMP)&$BGAlert$dealloc, "v@:");
    class_addMethod($BGAlert, @selector(currentApp),
            (IMP)&$BGAlert$currentApp, "@@:");
    class_addMethod($BGAlert, @selector(otherApps),
            (IMP)&$BGAlert$otherApps, "@@:");
    class_addMethod($BGAlert, @selector(alertDisplayViewWithSize:),
            (IMP)&$BGAlert$alertDisplayViewWithSize$, "@@:{CGSize=ff}");
    objc_registerClassPair($BGAlert);
}

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
