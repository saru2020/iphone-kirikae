/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-09-12 16:36:59
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
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBIconModel.h>
#import <UIKit/UINavigationBarBackground.h>
#import <UIKit/UITableViewCellDeleteConfirmationControl.h>
#import <UIKit/UIViewController-UITabBarControllerItem.h>

#import "SpringBoardHooks.h"
#import "TaskListCell.h"


@implementation FavoritesController

- (id)initWithStyle:(int)style
{
    self = [super initWithStyle:style];
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

- (void)dealloc
{
    [favorites release];
    [super dealloc];
}

- (void)loadView
{
    [super loadView];

    if ([favorites count] == 0) {
        // No favorites
        [self.tableView setHidden:YES];

        // Create a notice to inform use how to add favorites
        // FIXME: Try to find a simpler/cleaner way to implement this
        //        ... or, consider making this dialog into a separate class
        UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
        self.view = view;
        [view release];

        view = [[UIView alloc] initWithFrame:CGRectMake(40.0f, 110.0f, 240.0f, 180.0f)];
        [view setBackgroundColor:[UIColor colorWithWhite:0.13f alpha:1.0f]];
        [view.layer setCornerRadius:10.0f];

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10.0f, 10.0f, view.bounds.size.width - 20.0f, 21.0f)];
        label.text = @"No Favorites";
        label.font = [UIFont boldSystemFontOfSize:17.0f];
        label.textAlignment = UITextAlignmentCenter;
        label.textColor = [UIColor whiteColor];
        label.backgroundColor = [UIColor clearColor];
        [view addSubview:label];
        [label release];

        UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(10.0f, 31.0f, view.bounds.size.width - 20.0f, 105.0f)];
        textView.text = @"Applications can be added to the list of favorites via the Kirikae preferences application.";
        textView.font = [UIFont systemFontOfSize:16.0f];
        textView.textAlignment = UITextAlignmentCenter;
        textView.textColor = [UIColor whiteColor];
        textView.backgroundColor = [UIColor clearColor];
        [textView setScrollEnabled:NO];
        [view addSubview:textView];
        [textView release];

        UIButton *btn = [UIButton buttonWithType:1];
        btn.frame = CGRectMake(20.0f, view.bounds.size.height - 47.0f, view.bounds.size.width - 40.0f, 37.0f);
        btn.backgroundColor = [UIColor clearColor];
        [btn setTitle:@"Open Preferences..." forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(openPreferences:) forControlEvents:UIControlEventTouchUpInside];
        [view addSubview:btn];

        [self.view addSubview:view];
        [view release];
    } else {
        // Adjust row height
        [self.tableView setRowHeight:68.0f];
    }
}

#pragma mark - UITableViewDataSource

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(int)section
{
    return @"Favorites";
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    return [favorites count];
}

- (float)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *identifier = [favorites objectAtIndex:indexPath.row];

    // Get the icon for this application
    SBIconModel *iconModel = [objc_getClass("SBIconModel") sharedInstance];
    SBApplicationIcon *icon = [iconModel iconForDisplayIdentifier:identifier];
    if (!icon) {
        // Application may have multiple roles; try again with default role
        SBApplicationController *appCont = [objc_getClass("SBApplicationController") sharedInstance];
        SBApplication *app = [appCont applicationWithDisplayIdentifier:identifier];
        icon = [iconModel iconForDisplayIdentifier:[NSString stringWithFormat:@"%@-%@", identifier, [app roleIdentifier]]];
    }

    // Return appropriate height depending on whether or not icon has a badge
    return (icon && MSHookIvar<SBIconBadge *>(icon, "_badge") != nil) ? 76.0f : 68.0f;
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
    SBIconModel *iconModel = [objc_getClass("SBIconModel") sharedInstance];
    SBApplicationIcon *icon = [iconModel iconForDisplayIdentifier:identifier];
    if (!icon) {
        // Application may have multiple roles; try again with default role
        // FIXME: This check is being done twice (also in height check)
        SBApplicationController *appCont = [objc_getClass("SBApplicationController") sharedInstance];
        SBApplication *app = [appCont applicationWithDisplayIdentifier:identifier];
        icon = [iconModel iconForDisplayIdentifier:[NSString stringWithFormat:@"%@-%@", identifier, [app roleIdentifier]]];
    }

    if (icon) {
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
    } else {
        // FIXME: Was unable to retrieve icon; invalid identifier?
        [cell setText:[NSString stringWithFormat:@"Error: %@", identifier]];
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

#pragma mark - Actions

- (void)openPreferences:(id)sender
{
    // Switch to the Kirikae preferences application
    SpringBoard *springBoard = [objc_getClass("SpringBoard") sharedApplication];
    [springBoard switchToAppWithDisplayIdentifier:@APP_ID];
}

@end

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
