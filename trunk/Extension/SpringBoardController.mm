/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-02-24 23:10:32
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

#import <substrate.h>

#import <QuartzCore/QuartzCore.h>

#import <SpringBoard/SBButtonBar.h>
#import <SpringBoard/SBIconList.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SBSearchController.h>>
#import <SpringBoard/SBSearchView.h>>
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
        NSBundle *bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:@"/Applications/Kirikae.app"]];
        UIImage *image = [[UIImage alloc] initWithContentsOfFile:[bundle pathForResource:@"springboard_tab" ofType:@"png"]];
        UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:@"SpringBoard" image:image tag:2];
        self.tabBarItem = item;
        [item release];
        [image release];
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

    // Set the background image
    NSBundle *bundle = [NSBundle bundleWithPath:@"/Applications/Kirikae.app"];
    UIImage *image = [UIImage imageWithContentsOfFile:[bundle pathForResource:@"springboard_background" ofType:@"png"]];
    if (image) {
        // NOTE: The image is shifted up by 20 pixels to account for statusbar
        UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
        imageView.frame = CGRectMake(0, -20.0f, 320.0f, 480.0f);
        [self.view addSubview:imageView];
        [imageView release];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    // FIXME: Is it really necessary to get the content view each time?
    //        Does the instance change?
    SBUIController *uiCont = [objc_getClass("SBUIController") sharedInstance];
    contentView = uiCont.contentView;

    if (![contentView.superview isMemberOfClass:objc_getClass("SBAppWindow")])
        // Content view is inside a container view
        // NOTE: WinterBoard does this in order to add a background image
        contentViewHasWrapper = YES;

    // Use dock's alpha value as indicator of scatter status
    // NOTE: Cannot use SBIconList, as only the current list will be
    //       scattered; when the current view is the Spotlight page, no
    //       list is scattered.
    // FIXME: Would it be better to instead use topApplication == nil?
    //       
    SBButtonBar *dock = [[objc_getClass("SBIconModel") sharedInstance] buttonBar];
    wasScattered = (dock.alpha == 0);
    if (wasScattered)
        [uiCont restoreIconList:NO];

    [self.view addSubview:contentView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [self.tabBarController setTabBarHidden:YES animate:YES];
    contentView.frame = CGRectMake(0, -20.0f, 320.0f, 480.0f);

    // Resizing the wrapper view causes the Spotlight view to resize as well
    // (by height +/- 49 pixels - the height of the tab bar); for some reason,
    // switching from SpringBoard tab to Spotlight tab causes the Spotlight view
    // to remain shrunken, and will continue to shrink with each unhide.
    // FIXME: Find a better way to handle this
    SBSearchView *searchView = [[objc_getClass("SBSearchController") sharedInstance] searchView];
    searchView.frame = CGRectMake(0, 0, 320.0f, 350.0f);
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.tabBarController setTabBarHidden:NO animate:YES];
}

- (void)viewDidDisappear:(BOOL)animated
{
    if (wasScattered)
        // Re-scatter the icons and dock
        [[objc_getClass("SBUIController") sharedInstance] scatterIconListAndBar:NO];

    // Readd content view to SpringBoard
    contentView.frame = CGRectMake(0, 0, 320.0f, 480.0f);
    UIWindow *appWindow = [[objc_getClass("SBUIController") sharedInstance] window];
    if (contentViewHasWrapper)
        [[[appWindow subviews] objectAtIndex:0] addSubview:contentView];
    else
        [appWindow insertSubview:contentView atIndex:0];
    contentView = nil;
}

@end

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
