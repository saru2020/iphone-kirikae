/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-12-21 01:10:41
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


#import "SpotlightController.h"

#import <QuartzCore/QuartzCore.h>

#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBIconScrollView.h>
#import <SpringBoard/SBSearchController.h>
#import <SpringBoard/SBSearchView.h>

@interface UIKeyboard : UIView
@end

@interface UISearchBar (Private)
@property(readonly, retain) UITextField *searchField;
@end

#import "SpringBoardHooks.h"
#import "TaskListCell.h"


@implementation SpotlightController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        // Setup tab bar button
        UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:@"Spotlight" image:[UIImage imageNamed:@"Kirikae_Spotlight.png"] tag:2];
        [self setTabBarItem:item];
        [item release];
    }
    return self;
}

- (void)loadView
{
    [super loadView];

    // Create a container view in order to set background color
    // NOTE: Must use black background as that is what SBSearchView is designed to use
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = [UIColor blackColor];
    self.view = view;
    [view release];
}

- (void)viewWillAppear:(BOOL)animated
{
    // FIXME: Is it really necessary to get the search view each time?
    //        Does the instance change?
    searchView = [[[objc_getClass("SBSearchController") sharedInstance] searchView] retain];
    [self.view addSubview:searchView];

    // Set search button to always be enabled (so keyboard can be cancelled)
    UISearchBar *&bar = MSHookIvar<UISearchBar *>(searchView, "_searchBar");
    bar.searchField.enablesReturnKeyAutomatically = NO;
}

- (void)viewDidAppear:(BOOL)animated
{
    [self.view addSubview:searchView];
    [searchView setShowsSearchKeyWhenAnimatingKeyboard:YES];
    [searchView setShowsKeyboard:YES animated:YES];

    // Resizing the wrapper view causes the Spotlight view to resize as well
    // (by height +/- 49 pixels - the height of the tab bar); for some reason,
    // switching from SpringBoard tab to Spotlight tab causes the Spotlight view
    // to remain shrunken, and will continue to shrink with each unhide.
    // FIXME: Find a better way to handle this
    searchView.frame = CGRectMake(0, 0, 320.0f, 399.0f);
}

- (void)viewDidDisappear:(BOOL)animated
{
    // Reset keyboard search button
    UISearchBar *&bar = MSHookIvar<UISearchBar *>(searchView, "_searchBar");
    bar.searchField.enablesReturnKeyAutomatically = YES;

    // Readd search view to SpringBoard
    SBIconController *iconCont = [objc_getClass("SBIconController") sharedInstance];
	SBIconScrollView *scrollView = MSHookIvar<SBIconScrollView *>(iconCont, "_scrollView");
    [scrollView addSubview:searchView];

    [searchView setShowsKeyboard:NO animated:YES];
    [searchView setShowsSearchKeyWhenAnimatingKeyboard:NO];

    // Release search view
    // FIXME: Again, is it necessary to do ewith each showing/hiding?
    //        Does the search view instance ever change?
    [searchView release];
    searchView = nil;
}

@end

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
