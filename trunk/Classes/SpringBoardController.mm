/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-12-19 21:58:31
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


#import "SpringBoardController.h"

#import <QuartzCore/QuartzCore.h>

#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBButtonBar.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBIconList.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SBUIController.h>

#import "Kirikae.h"
#import "SpringBoardHooks.h"
#import "TaskListCell.h"


@implementation SpringBoardController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        // Setup tab bar button
        UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:@"SpringBoard" image:[UIImage imageNamed:@"Kirikae_Active.png"] tag:4];
        [self setTabBarItem:item];
        [item release];
    }
    return self;
}

- (void)loadView
{
    [super loadView];

    // Create a container view in order to set background color
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = [UIColor blackColor];
    self.view = view;
    [view release];
}

- (void)viewWillAppear:(BOOL)animated
{
    // FIXME: Is it really necessary to get the content view each time?
    //        Does the instance change?
    contentView = [[objc_getClass("SBUIController") sharedInstance] contentView];

    UIView *view = contentView.superview;
    if (![view isMemberOfClass:objc_getClass("SBAppWindow")])
        // Content view is inside a container view
        // NOTE: WinterBoard does this in order to add a background image
        contentView = view;

    // Get current icon list
    SBIconController *iconCont = [objc_getClass("SBIconController") sharedInstance];
    initialIconList = [[iconCont currentIconList] retain];

    // Check if list is currently scattered
    wasScattered = [initialIconList isScattered];
    if (wasScattered) {
        SBButtonBar *buttonBar = [[objc_getClass("SBIconModel") sharedInstance] buttonBar];

        // Unscatter list and unhide dock
        [initialIconList unscatter:NO startTime:CACurrentMediaTime()];
        buttonBar.alpha = 1.0f;

        // Add icon view and dock to content view
        [contentView addSubview:iconCont.contentView];
        [contentView addSubview:buttonBar.superview];
    }
    [self.view addSubview:contentView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [self.tabBarController setTabBarHidden:YES animate:YES];
    contentView.frame = CGRectMake(0, -20.0f, 320.0f, 480.0f);
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.tabBarController setTabBarHidden:NO animate:YES];
}

- (void)viewDidDisappear:(BOOL)animated
{
    if (wasScattered) {
        SBButtonBar *buttonBar = [[objc_getClass("SBIconModel") sharedInstance] buttonBar];

        // Icons/dock were scattered/hidden, unscatter/unhide
        [initialIconList scatter:NO startTime:CACurrentMediaTime()];
        buttonBar.alpha = 0;

        // Remove icon view and dock from content view
        [[[objc_getClass("SBUIController") sharedInstance] contentView] removeFromSuperview];
        [buttonBar.superview removeFromSuperview];

        // Rescatter list and rehide dock
        [initialIconList scatter:NO startTime:CACurrentMediaTime()];
        [buttonBar setAlpha:0.0f];
    }
    [initialIconList release];
    initialIconList = nil;

    // Readd content view to SpringBoard
    contentView.frame =  CGRectMake(0, 0, 320.0f, 480.0f);
    UIWindow *appWindow = [[objc_getClass("SBUIController") sharedInstance] window];
    [appWindow insertSubview:contentView atIndex:0];
    contentView = nil;
}

@end

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
