/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-02-24 00:08:05
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


#import "AppearanceController.h"

#import <CoreGraphics/CGGeometry.h>

#import <Foundation/Foundation.h>

#import "ColorsController.h"
#import "Constants.h"
#import "Preferences.h"
#import "ToggleButton.h"


@implementation AppearanceController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        self.title = @"Appearance";
    }
    return self;
}

#pragma mark - UITableViewDataSource

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(int)section
{
    return (section == 0) ? @"General" : @"Theming";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(int)section
{
    return (section == 0) ? @"* Changing this option requires restarting SpringBoard. Will restart upon exit." : nil;
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    return (section == 0) ? 3 : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdSimple = @"SimpleCell";
    static NSString *reuseIdToggle = @"ToggleCell";
    static NSString *cellTitles[] = {@"Animate switching *", @"Use Large Rows", @"Use Themed Icons"};

    UITableViewCell *cell = nil;
    if (indexPath.section == 1) {
        // Try to retrieve from the table view a now-unused cell with the given identifier
        cell = [tableView dequeueReusableCellWithIdentifier:reuseIdSimple];
        if (cell == nil) {
            // Cell does not exist, create a new one
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdSimple] autorelease];
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        cell.textLabel.text = @"Colors";
    } else {
        // Try to retrieve from the table view a now-unused cell with the given identifier
        cell = [tableView dequeueReusableCellWithIdentifier:reuseIdToggle];
        if (cell == nil) {
            // Cell does not exist, create a new one
            cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdToggle] autorelease];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

            // FIXME: Assigning accessoryView twice
            UISwitch *toggle = [[UISwitch alloc] init];
            [toggle addTarget:self action:@selector(switchToggled:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
            [toggle release];

            ToggleButton *button = [ToggleButton button];
            [button addTarget:self action:@selector(buttonToggled:) forControlEvents:UIControlEventTouchUpInside];
            cell.accessoryView = button;
        }
        cell.text = cellTitles[indexPath.row];

        UIButton *button = (UIButton *)cell.accessoryView;
        NSString *keys[] = {kAnimationsEnabled, kUseLargeRows, kUseThemedIcons};
        button.selected = [[Preferences sharedInstance] integerForKey:keys[indexPath.row]];
    }

    return cell;
}

#pragma mark - UITableViewCellDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1) {
        // Colors
        UIViewController *vc = [[[ColorsController alloc] initWithStyle:UITableViewStyleGrouped] autorelease];
        [self.navigationController pushViewController:vc animated:YES];
    }
}

#pragma mark - Switch delegate

- (void)buttonToggled:(UIButton *)button
{
    // Update selected state of button
    button.selected = !button.selected;

    // Save the preference
    NSIndexPath *indexPath = [self.tableView indexPathForCell:(UITableViewCell *)[button superview]];
    NSString *keys[] = {kAnimationsEnabled, kUseLargeRows, kUseThemedIcons};
    [[Preferences sharedInstance] setBool:button.selected forKey:keys[indexPath.row]];
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
