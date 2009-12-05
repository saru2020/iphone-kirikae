/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-12-05 12:16:44
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


HOOK(SBSearchController, tableView$didSelectRowAtIndexPath$, void, UITableView *tableView, NSIndexPath *indexPath)
{
    int section = indexPath.section;
    int offset = 0;

    SpringBoard *springBoard = (SpringBoard *)[objc_getClass("SpringBoard") sharedApplication];
    if ([self _sectionIsApp:&section appOffset:&offset]) {
        // Application selected; launch via Kirikae's method
        NSMutableArray *&matchingLaunchingIcons = MSHookIvar<NSMutableArray *>(self, "_matchingLaunchingIcons");
        SBApplicationIcon *icon = [matchingLaunchingIcons objectAtIndex:offset];
        [springBoard switchToAppWithDisplayIdentifier:[icon displayIdentifier]];
    } else {
        // Call the original implementation to launch the selected item
        CALL_ORIG(SBSearchController, tableView$didSelectRowAtIndexPath$, tableView, indexPath);
    }

    // Hide Kirikae
    [springBoard dismissKirikae];
}

//______________________________________________________________________________
//______________________________________________________________________________

@implementation SpotlightController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        // Setup tab bar button
        UITabBarItem *item = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemSearch tag:2];
        [self setTabBarItem:item];
        [item release];

        // Hook methods, if not already hooked
        if (_SBSearchController$tableView$didSelectRowAtIndexPath$ == NULL) {
            Class $SBSearchController = objc_getClass("SBSearchController");
            LOAD_HOOK($SBSearchController, @selector(tableView:didSelectRowAtIndexPath:), SBSearchController$tableView$didSelectRowAtIndexPath$);
        }
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
}

- (void)viewDidAppear:(BOOL)animated
{
    // Get keyboard associated with search view and add to tab controller
    // NOTE: Really only need to adjust the initial position the first time the
    //       keyboard is shown after respring
    UIKeyboard *&keyboard = MSHookIvar<UIKeyboard *>(searchView, "_keyboard");
    CGRect frame = keyboard.frame;
    frame.origin.y = 480.0f;
    keyboard.frame = frame;
    [self.tabBarController.view addSubview:keyboard];

    // Set search button to always be enabled (so keyboard can be cancelled)
    UISearchBar *&bar = MSHookIvar<UISearchBar *>(searchView, "_searchBar");
    bar.searchField.enablesReturnKeyAutomatically = NO;

    // Make search bar active to show keyboard
    // NOTE: Without the delay, the keyboard does not animate in (possibly due
    //       to viewDidAppear being a part of a separate animation)?
    [bar performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.1f];
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

    // Release control of keyboard
    // NOTE: Failing to remove animations causes normal Spotlight animation to fail
    // FIXME: Where is this animation coming from?
    UIKeyboard *&keyboard = MSHookIvar<UIKeyboard *>(searchView, "_keyboard");
    [keyboard removeFromSuperview];
    [keyboard.layer removeAllAnimations];

    // Release search view
    // FIXME: Again, is it necessary to do ewith each showing/hiding?
    //        Does the search view instance ever change?
    [searchView release];
    searchView = nil;
}

@end

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
