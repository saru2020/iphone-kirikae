/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-02-24 10:51:42
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

#import <substrate.h>

#import <QuartzCore/CALayer.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBIconBadge.h>
#import <SpringBoard/SBIconModel.h>

#import "SpringBoardHooks.h"
#import "TaskListCell.h"


@interface TaskListController (Private)
- (NSString *)displayIdentifierAtIndexPath:(NSIndexPath *)indexPath;
@end

static UIColor *colorFromPreferenceValue(unsigned int value)
{
    float h = ((value >> 21) & 0x1ff) / 360.0f;
    float s = ((value >> 14) & 0x7f) / 100.0f;
    float b = ((value >> 7) & 0x7f) / 100.0f;
    float a = (value & 0x7f) / 100.0f;

    return [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
}

//==============================================================================

static unsigned int headerTextColor;
static unsigned int headerTextShadowColor;
static unsigned int itemTextColor;

@implementation TaskListController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Setup tab bar button
        UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:@"Active" image:[UIImage imageNamed:@"Kirikae_Active.png"] tag:0];
        self.tabBarItem = item;
        [item release];

        // Cache the images used for the terminate button
        NSBundle *bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:@"/Applications/Kirikae.app"]];
        termImage = [[UIImage alloc] initWithContentsOfFile:
            [bundle pathForResource:@"terminate_btn" ofType:@"png"]];
        termPressedImage = [[UIImage alloc] initWithContentsOfFile:
            [bundle pathForResource:@"terminate_btn_pressed" ofType:@"png"]];

        // Determine the row height and badge padding to use
        Boolean valid;
        BOOL useLargeRows = CFPreferencesGetAppBooleanValue(CFSTR("useLargeRows"), CFSTR(APP_ID), &valid);
        if (!valid)
            useLargeRows = YES;

        if (useLargeRows) {
            rowHeight = 60.0f;
            badgePadding = 8.0f;
        } else {
            rowHeight = 44.0f;
            badgePadding = 4.0f;
        }

        // Determine whether to use themed or unthemed icons
        useThemedIcons = CFPreferencesGetAppBooleanValue(CFSTR("useThemedIcons"), CFSTR(APP_ID), &valid);
        if (!valid)
            useThemedIcons = YES;

        // Determine color to use for table background
        unsigned int backgroundColor = CFPreferencesGetAppIntegerValue(CFSTR("backgroundColor"), CFSTR(APP_ID), &valid);
        if (!valid)
            backgroundColor = 0x00003264; // White

        self.tableView.backgroundColor = colorFromPreferenceValue(backgroundColor);

        // Determine color to use for header text
        headerTextColor = CFPreferencesGetAppIntegerValue(CFSTR("headerTextColor"), CFSTR(APP_ID), &valid);
        if (!valid)
            headerTextColor = 0x00003264; // White
            
        // Determine color to use for header text shadow
        headerTextShadowColor = CFPreferencesGetAppIntegerValue(CFSTR("headerTextShadowColor"), CFSTR(APP_ID), &valid);
        if (!valid)
            headerTextShadowColor = 0x00001664; // 44% White
            
        // Determine color to use for cell text
        itemTextColor = CFPreferencesGetAppIntegerValue(CFSTR("itemTextColor"), CFSTR(APP_ID), &valid);
        if (!valid)
            itemTextColor = 0x00000064; // Black
            
        // Determine color to use for cell separator
        unsigned int separatorColor = CFPreferencesGetAppIntegerValue(CFSTR("separatorColor"), CFSTR(APP_ID), &valid);
        if (!valid)
            separatorColor = 0x00002c64; // 88% White

        self.tableView.separatorColor = colorFromPreferenceValue(separatorColor);
    }
    return self;
}

- (void)dealloc
{
    // NOTE: Should already be released and nullified, but just in case
    [fgAppId release];
    [bgAppIds release];

    [termImage release];
    [termPressedImage release];

    [super dealloc];
}

- (void)viewWillAppear:(BOOL)animated
{
    // Get foreground application
    SpringBoard *springBoard = (SpringBoard *)[UIApplication sharedApplication];
    fgAppId = [[[springBoard topApplication] displayIdentifier] copy];

    // Get list of background applications
    bgAppIds = [[NSMutableArray alloc] init];
    for (SBApplication *app in [springBoard _accessibilityRunningApplications])
        [bgAppIds addObject:app.displayIdentifier];

    // Do not show foreground application in list of background applications
    [bgAppIds removeObject:fgAppId];
}

- (void)viewDidAppear:(BOOL)animated
{
    SpringBoard *springBoard = (SpringBoard *)[UIApplication sharedApplication];
    [[springBoard kirikae] setDelegate:self];
}

- (void)viewWillDisappear:(BOOL)animated
{
    SpringBoard *springBoard = (SpringBoard *)[UIApplication sharedApplication];
    [[springBoard kirikae] setDelegate:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [fgAppId release];
    fgAppId = nil;

    [bgAppIds release];
    bgAppIds = nil;
}

#pragma mark - Private methods

- (NSString *)displayIdentifierAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *displayId = nil;

    switch (indexPath.section) {
        case 0:
            displayId = @"com.apple.springboard";
            break;
        case 1:
            displayId = fgAppId;
            break;
        case 2:
            displayId = [bgAppIds objectAtIndex:indexPath.row];
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

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    int rows = 0;

    if (section == 2)
        rows = [bgAppIds count];
    else if (section == 0 || fgAppId != nil)
        rows = 1;

    return rows;
}

- (float)tableView:(UITableView *)tableView_ heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    float height = rowHeight;

    if (indexPath.section != 0) {
        NSString *displayId = (indexPath.section == 1) ? fgAppId : [bgAppIds objectAtIndex:indexPath.row];
        SBApplicationIcon *icon = [[objc_getClass("SBIconModel") sharedInstance] iconForDisplayIdentifier:displayId];
        if (MSHookIvar<SBIconBadge *>(icon, "_badge"))
            // Make room for badge icon
            height += badgePadding;
    }

    return height;
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

    // Get the application icon object
    NSString *displayId = [self displayIdentifierAtIndexPath:indexPath];
    SBApplicationIcon *icon = [[objc_getClass("SBIconModel") sharedInstance] iconForDisplayIdentifier:displayId];

    // Set the cell's text to the name of the application
    cell.textLabel.text = [icon displayName];
    cell.textLabel.textColor = colorFromPreferenceValue(itemTextColor);

    // Set the cell's image to the application's icon image
    UIImage *image = nil;
    if (indexPath.section == 0) {
        // Is SpringBoard
        image = [UIImage imageNamed:@"applelogo.png"];
    } else {
        // Is an application (either foreground or background)
        if (useThemedIcons) {
            image = [icon icon];
        } else {
            SBApplication *app = [icon application];
            NSString *bundlePath = [app path];
            NSString *roleId = [app roleIdentifier];
            if (roleId != nil) {
                // NOTE: Should only be true for iPod/Video/Audio and Camera/Photos
                image = [UIImage imageWithContentsOfFile:
                    [NSString stringWithFormat:@"%@/icon-%@.png", bundlePath, roleId]];
            } else {
                // First try with uppercase filename
                image = [UIImage imageWithContentsOfFile:[bundlePath stringByAppendingPathComponent:@"Icon.png"]];
                if (image == nil)
                    // Try again with lowercase filename
                    image = [UIImage imageWithContentsOfFile:[bundlePath stringByAppendingPathComponent:@"icon.png"]];
            }
        }
    }
    cell.iconImage = image;

    // Set the cell's badge image (if applicable)
    SBIconBadge *&badge = MSHookIvar<SBIconBadge *>(icon, "_badge");
    if (badge) {
        UIGraphicsBeginImageContext(badge.frame.size);
        [badge.layer renderInContext:UIGraphicsGetCurrentContext()];
        cell.badgeImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }

    // Create close button to use as accessory for cell
    // NOTE: The button is aligned so that it will appear in the same spot
    //       as the activity indicator it is replaced with when tapped.
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0, 0, 40.0f, rowHeight);
    [button setImage:termImage forState:UIControlStateNormal];
    [button setImage:termPressedImage forState:UIControlStateHighlighted];
    [button addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
    cell.accessoryView = button;

    return cell;
}

- (void)tableView:(UITableView *)tableView
  commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
    }
}

#pragma mark - UITableViewCellDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 22.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    static NSString *titles[] =  {@"Home Screen", @"Foreground Application", @"Background Applications"};

    if (section == 1 && fgAppId == nil)
        // Foreground section and no current foreground app; hide header
        return nil;

    NSString *title = titles[section];

    // Create the background for the header
    UIView *view = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320.0f, 22.0f)] autorelease];;
    NSBundle *bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:@"/Applications/Kirikae.app"]];
    UIImage *image = [[UIImage alloc] initWithContentsOfFile:
        [bundle pathForResource:@"header_background" ofType:@"png"]];
    view.backgroundColor = [UIColor colorWithPatternImage:image];
    [image release];

    // Create the text label
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(12.0f, 0, 308.0f, 22.0f)];
    label.font = [UIFont boldSystemFontOfSize:18.0f];
    label.text = title;
    label.backgroundColor = [UIColor clearColor];
    label.shadowColor = colorFromPreferenceValue(headerTextShadowColor);
    label.shadowOffset = CGSizeMake(0, 1.0f);
    label.textColor = colorFromPreferenceValue(headerTextColor);
    [view addSubview:label];
    [label release];

    return view;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    SpringBoard *springBoard = (SpringBoard *)[objc_getClass("SpringBoard") sharedApplication];

    if (indexPath.section == 1)
        [springBoard dismissKirikae];
    else
        // Switch to selected application
        [springBoard switchToAppWithDisplayIdentifier:(indexPath.section == 0) ?
            @"com.apple.springboard" :
            [bgAppIds objectAtIndex:indexPath.row]];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleNone;
}

#pragma mark - Actions

- (void)buttonPressed:(UIButton *)button
{
    // Get the cell for the pressed button
    NSIndexPath *indexPath = [self.tableView indexPathForCell:(UITableViewCell *)[button superview]];

    // Create an activity indicator to display while waiting for app to quit
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [spinner startAnimating];
    cell.accessoryView = spinner;
    [spinner release];

    // Quit the selected application
    NSString *displayId = [self displayIdentifierAtIndexPath:indexPath];
    SpringBoard *springBoard = (SpringBoard *)[UIApplication sharedApplication];
    [springBoard quitAppWithDisplayIdentifier:displayId];
}

#pragma mark - Kirikae delegate methods

- (void)kirikae:(Kirikae *)kirikae applicationDidActivate:(NSString *)displayId
{
    // Mark beginning of animations
    [self.tableView beginUpdates];

    SpringBoard *springBoard = (SpringBoard *)[UIApplication sharedApplication];
    if ([displayId isEqualToString:[[springBoard topApplication] displayIdentifier]]) {
        // New foreground application
        if (fgAppId != nil) {
            // Application replaced current foreground application
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:1 inSection:1];
            [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                withRowAnimation:UITableViewRowAnimationFade];

            // Move previous application to background applications section
            [bgAppIds insertObject:fgAppId atIndex:0];
            indexPath = [NSIndexPath indexPathForRow:0 inSection:2];
            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                withRowAnimation:UITableViewRowAnimationFade];

            // Release the old identifier
            [fgAppId release];
        } else {
            // No previous foreground application (was SpringBoard)
            NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:1];
            [self.tableView reloadSections:indexSet
                withRowAnimation:UITableViewRowAnimationFade];
        }

        // Save the new identifier
        fgAppId = [displayId copy];
    } else {
        // Background application
        int row = [bgAppIds indexOfObject:displayId];
        if (row != NSNotFound) {
            // Already exists in background applications list; will move to top
            [bgAppIds removeObjectAtIndex:row];

            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:2];
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                withRowAnimation:UITableViewRowAnimationFade];
        }

        // Insert at top of list
        [bgAppIds insertObject:displayId atIndex:0];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:2];
        [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
            withRowAnimation:UITableViewRowAnimationFade];
    }

    // Commit animations
    [self.tableView endUpdates];
}

- (void)kirikae:(Kirikae *)kirikae applicationDidTerminate:(NSString *)displayId
{
    // Mark beginning of animations
    [self.tableView beginUpdates];

    int row = NSNotFound;
    if ([displayId isEqualToString:fgAppId]) {
        // Foreground application terminated
        [fgAppId release];
        fgAppId = nil;

        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:1];
        [self.tableView reloadSections:indexSet
            withRowAnimation:UITableViewRowAnimationFade];
    } else if ((row = [bgAppIds indexOfObject:displayId]) != NSNotFound) {
        // Backgroung application terminated
        [bgAppIds removeObjectAtIndex:row];

        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:2];
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
            withRowAnimation:UITableViewRowAnimationFade];
    }

    // Commit animations
    [self.tableView endUpdates];
}

@end

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
