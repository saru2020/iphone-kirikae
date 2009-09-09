/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-09-09 23:01:26
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


#import "FavoritesController.h"

#import <QuartzCore/CALayer.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBIconModel.h>
#import <UIKit/UINavigationBarBackground.h>
#import <UIKit/UITableViewCellDeleteConfirmationControl.h>
#import <UIKit/UIViewController-UITabBarControllerItem.h>

#import "SpringBoardHooks.h"
#import "TaskListCell.h"


@implementation FavoritesController

- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle
{
    self = [super initWithNibName:nibName bundle:bundle];
    if (self) {
        // Setup tab bar button
        UITabBarItem *item = [[UITabBarItem alloc] initWithTabBarSystemItem:1 tag:1]; // UITabBarSystemItemFavorites
        [self setTabBarItem:item];
        [item release];

        // Read favorites from preferences
        CFPropertyListRef propList = CFPreferencesCopyAppValue(CFSTR("favorites"), CFSTR(APP_ID));
        if (propList) {
            if (CFGetTypeID(propList) == CFArrayGetTypeID())
                favorites = [[NSArray alloc] initWithArray:(NSArray *)propList];
            CFRelease(propList);
        }
    }
    return self;
}

- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    CGSize size = view.frame.size;
    const float statusBarHeight = 0;

    // Create a table, which acts as the main body of the popup
    UITableView *table = [[UITableView alloc] initWithFrame:
        CGRectMake(0, statusBarHeight, size.width, size.height - statusBarHeight - 44)
        style:0];
    [table setDataSource:self];
    [table setDelegate:self];
    [table setRowHeight:68];
    [view addSubview:table];
    [table release];

    self.view = view;
    [view release];
}

- (void)dealloc
{
    [favorites release];
    [super dealloc];
}

#pragma mark - UITableViewDataSource

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(int)section
{
    return  @"Favorites";
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    return [favorites count];
}

- (float)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *identifier = [favorites objectAtIndex:indexPath.row];
    SBApplicationIcon *icon = [[objc_getClass("SBIconModel") sharedInstance] iconForDisplayIdentifier:identifier];
    SBIconBadge *badge = MSHookIvar<SBIconBadge *>(icon, "_badge");
    return (badge ? 76.0f : 68.0f);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdentifier = @"TaskMenuCell";

    // Try to retrieve from the table view a now-unused cell with the given identifier
    TaskListCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil) {
        // Cell does not exist, create a new one
        cell = [[[TaskListCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdentifier] autorelease];
        [cell setSelectionStyle:2];
    }

    // Get the display identifier of the application for this cell
    NSString *identifier = [favorites objectAtIndex:indexPath.row];

    // Get the application icon object
    SBApplicationIcon *icon = [[objc_getClass("SBIconModel") sharedInstance] iconForDisplayIdentifier:identifier];

    // Set the cell's text to the name of the application
    [cell setText:[icon displayName]];

    // Set the cell's image to the application's icon image
    [cell setImage:[icon icon]];

    // Set the cell's badge image (if applicable)
    SBIconBadge *&badge = MSHookIvar<SBIconBadge *>(icon, "_badge");
    if (badge) {
        UIGraphicsBeginImageContext([badge frame].size);
        [[badge layer] renderInContext:UIGraphicsGetCurrentContext()];
        [cell setBadge:UIGraphicsGetImageFromCurrentImageContext()];
        UIGraphicsEndImageContext();
    }

    return cell;
}

#pragma mark - UITableViewCellDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Switch to selected application
    SpringBoard *springBoard = [objc_getClass("SpringBoard") sharedApplication];
    [springBoard switchToAppWithDisplayIdentifier:[favorites objectAtIndex:indexPath.row]];
}

@end

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
