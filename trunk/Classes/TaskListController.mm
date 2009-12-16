/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-12-13 22:03:49
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


#import "TaskListController.h"

#import <QuartzCore/CALayer.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBIconModel.h>

#import "SpringBoardHooks.h"
#import "TaskListCell.h"


@interface TaskListController (Private)
- (void)refresh;
- (NSString *)displayIdentifierAtIndexPath:(NSIndexPath *)indexPath;
@end

@implementation TaskListController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Setup tab bar button
        UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:@"Active" image:[UIImage imageNamed:@"Kirikae_Active.png"] tag:0];
        [self setTabBarItem:item];
        [item release];

        // Create array to hold list of "other" running applications
        otherApps = [[NSMutableArray alloc] init];

        // Get initial list of running applications
        [self refresh];
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    [self.tableView setRowHeight:60.0f];
}

- (void)dealloc
{
    [currentApp release];
    [otherApps release];

    [super dealloc];
}

#pragma mark - Private methods

- (void)refresh
{
    // Update current application
    [currentApp autorelease];
    currentApp = [[[(SpringBoard *)UIApp topApplication] displayIdentifier] retain];

    // Update list of other applications
    [otherApps removeAllObjects];
    for (SBApplication *app in [(SpringBoard *)UIApp _accessibilityRunningApplications])
        [otherApps addObject:app.displayIdentifier];

    // Do not show current application in list of other applications
    [otherApps removeObject:currentApp];
}

- (NSString *)displayIdentifierAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *displayId = nil;

    switch (indexPath.section) {
        case 0:
            displayId = @"com.apple.springboard";
            break;
        case 1:
            displayId = currentApp;
            break;
        case 2:
            displayId = [otherApps objectAtIndex:indexPath.row];
            break;
        default:
            break;
    }

    return displayId;
}

#pragma mark - UITableViewDataSource

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(int)section
{
    static NSString *titles[] =  {@"Home Screen", @"Current Application", @"Other Applications"};
    return (section == 1 && currentApp == nil) ? nil : titles[section];
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    int rows = 0;

    if (section == 2)
        rows = [otherApps count];
    else if (section == 0 || currentApp != nil)
        rows = 1;

    return rows;
}

- (float)tableView:(UITableView *)tableView_ heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SBIconBadge *badge = nil;

    NSString *displayId = (indexPath.section == 0) ? currentApp : [otherApps objectAtIndex:indexPath.row];
    if (displayId) {
        SBApplicationIcon *icon = [[objc_getClass("SBIconModel") sharedInstance] iconForDisplayIdentifier:displayId];
        badge = MSHookIvar<SBIconBadge *>(icon, "_badge");
    }

    return (badge ? 68.0f : 60.0f);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdentifier = @"TaskMenuCell";

    // Try to retrieve from the table view a now-unused cell with the given identifier
    TaskListCell *cell = (TaskListCell *)[tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil) {
        // Cell does not exist, create a new one
        cell = [[[TaskListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier] autorelease];
        [cell setSelectionStyle:UITableViewCellSelectionStyleGray];
    }

    // Get the display identifier of the application for this cell
    NSString *identifier = [self displayIdentifierAtIndexPath:indexPath];

    // Get the application icon object
    SBApplicationIcon *icon = [[objc_getClass("SBIconModel") sharedInstance] iconForDisplayIdentifier:identifier];

    // Set the cell's text to the name of the application
    [cell setText:[icon displayName]];

    // Set the cell's image to the application's icon image
    UIImage *image = nil;
    if (indexPath.section == 0) {
        // Is SpringBoard
        image = [UIImage imageNamed:@"applelogo.png"];
    } else {
        // Is an application
        image = [icon icon];

        SBIconBadge *badge = MSHookIvar<SBIconBadge *>(icon, "_badge");
        if (badge) {
            UIGraphicsBeginImageContext([badge frame].size);
            [[badge layer] renderInContext:UIGraphicsGetCurrentContext()];
            [cell setBadge:UIGraphicsGetImageFromCurrentImageContext()];
            UIGraphicsEndImageContext();
        }
    }
    [cell setImage:image];

    return cell;
}

- (void)tableView:(UITableView *)tableView
  commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Get the display identifier of the application for this cell
        NSString *identifier = [self displayIdentifierAtIndexPath:indexPath];

        Class $SpringBoard = objc_getClass("SpringBoard");
        SpringBoard *springBoard = (SpringBoard *)[$SpringBoard sharedApplication];
        [springBoard quitAppWithDisplayIdentifier:identifier];

        if (indexPath.section == 2) {
            [otherApps removeObjectAtIndex:indexPath.row];
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                withRowAnimation:UITableViewRowAnimationFade];
        } else {
            [springBoard dismissKirikae];
        }
    }
}

#pragma mark - UITableViewCellDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    SpringBoard *springBoard = (SpringBoard *)[objc_getClass("SpringBoard") sharedApplication];

    if (indexPath.section == 1)
        [springBoard dismissKirikae];
    else
        // Switch to selected application
        [springBoard switchToAppWithDisplayIdentifier:(indexPath.section == 0) ?
            @"com.apple.springboard" :
            [otherApps objectAtIndex:indexPath.row]];
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TaskListCell *cell = (TaskListCell *)[tableView cellForRowAtIndexPath:indexPath];
    return ([[cell text] isEqualToString:@"SpringBoard"]) ? @"Respring" : @"Quit";
}

@end

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
