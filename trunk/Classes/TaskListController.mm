/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-09-12 16:46:29
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
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBIconModel.h>
#import <UIKit/UINavigationBarBackground.h>
#import <UIKit/UIViewController-UITabBarControllerItem.h>

#import "SpringBoardHooks.h"
#import "TaskListCell.h"



@interface UINavigationBarBackground (ThreeO)
- (id)initWithFrame:(CGRect)frame withBarStyle:(int)style withTintColor:(UIColor *)color isTranslucent:(BOOL)translucent;
@end

@implementation TaskListController

@synthesize currentApp;
@synthesize otherApps;

- (id)initWithStyle:(int)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Setup tab bar button
        UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:@"Active" image:[UIImage imageNamed:@"Kirikae_Active.png"] tag:0];
        [self setTabBarItem:item];
        [item release];
    }
    return self;
}

- (void)dealloc
{
    [currentApp release];
    [otherApps release];

    [super dealloc];
}

- (void)loadView
{
    [super loadView];
    [self.tableView setRowHeight:68.0f];
}

#pragma mark - UITableViewDataSource

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(int)section
{
    return (section == 0) ? @"Current Application" : @"Other Applications";
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    return (section == 0) ? 1 : [otherApps count];
}

- (float)tableView:(UITableView *)tableView_ heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *identifier = (indexPath.section == 0) ? currentApp : [otherApps objectAtIndex:indexPath.row];
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
    NSString *identifier = (indexPath.section == 0) ? currentApp : [otherApps objectAtIndex:indexPath.row];

    // Get the application icon object
    SBApplicationIcon *icon = [[objc_getClass("SBIconModel") sharedInstance] iconForDisplayIdentifier:identifier];

    // Set the cell's text to the name of the application
    [cell setText:[icon displayName]];

    // Set the cell's image to the application's icon image
    UIImage *image = nil;
    if ([identifier isEqualToString:@"com.apple.springboard"]) {
        // Is SpringBoard
        image = [UIImage imageWithContentsOfFile:@"/System/Library/CoreServices/SpringBoard.app/applelogo.png"];
        image = [image _imageScaledToSize:CGSizeMake(59, 60) interpolationQuality:0];
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
        NSString *identifier = (indexPath.section == 0) ? currentApp : [otherApps objectAtIndex:indexPath.row];

        Class $SpringBoard(objc_getClass("SpringBoard"));
        SpringBoard *springBoard = [$SpringBoard sharedApplication];
        [springBoard quitAppWithDisplayIdentifier:identifier];

        if (indexPath.section == 0) {
            [springBoard dismissKirikae];
        } else {
            [otherApps removeObjectAtIndex:indexPath.row];
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                withRowAnimation:UITableViewRowAnimationFade];
        }
    }
}

#pragma mark - UITableViewCellDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    SpringBoard *springBoard = [objc_getClass("SpringBoard") sharedApplication];

    if (indexPath.section == 0)
        [springBoard dismissKirikae];
    else
        // Switch to selected application
        [springBoard switchToAppWithDisplayIdentifier:[otherApps objectAtIndex:indexPath.row]];
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TaskListCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    return ([[cell text] isEqualToString:@"SpringBoard"]) ? @"Respring" : @"Quit";
}

@end

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
