/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-09-21 20:38:06
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


#import "RootController.h"

#include <stdlib.h>

#import <CoreGraphics/CGGeometry.h>

#import <Foundation/Foundation.h>

#import "Constants.h"
#import "DocumentationController.h"
#import "HtmlDocController.h"
#import "FavoritesController.h"
#import "Preferences.h"


@implementation RootController

@synthesize displayIdentifiers;


- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        self.title = @"Kirikae";
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back"
            style:UIBarButtonItemStyleBordered target:nil action:nil];
    }
    return self;
}

- (void)dealloc
{
    [displayIdentifiers release];
    [super dealloc];
}

- (void)viewDidLoad
{
    // Create and add footer view
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320.0f, 234.0f)];

    // Donation button
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button addTarget:self action:@selector(openDonationLink) forControlEvents:UIControlEventTouchUpInside];
    UIImage *image = [UIImage imageNamed:@"donate.png"];
    [button setImage:image forState:UIControlStateNormal];
    button.frame = CGRectMake((320.0f - image.size.width) / 2.0f, view.bounds.size.height - image.size.height, image.size.width, image.size.height);
    [view addSubview:button];

    // Author label
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    [label setText:@"by Lance Fetters (ashikase)"];
    [label setTextColor:[UIColor colorWithRed:0.3f green:0.34f blue:0.42f alpha:1.0f]];
    [label setShadowColor:[UIColor whiteColor]];
    [label setShadowOffset:CGSizeMake(1, 1)];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setFont:[UIFont systemFontOfSize:16.0f]];
    CGSize size = [label.text sizeWithFont:label.font];
    [label setFrame:CGRectMake((320.0f - size.width) / 2.0f, view.bounds.size.height - image.size.height - size.height - 2.0f, size.width, size.height)];
    [view addSubview:label];
    [label release];

    self.tableView.tableFooterView = view;
    [view release];
}

- (void)viewWillAppear:(BOOL)animated
{
    // Reset the table by deselecting the current selection
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}

#pragma mark - UITableViewDataSource

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    static int rows[] = {2, 1};
    return rows[section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdSimple = @"SimpleCell";
    static NSString *reuseIdToggle = @"ToggleCell";

    UITableViewCell *cell = nil;

    if (indexPath.section == 0 && indexPath.row == 0) {
        // Try to retrieve from the table view a now-unused cell with the given identifier
        cell = [tableView dequeueReusableCellWithIdentifier:reuseIdToggle];
        if (cell == nil) {
            // Cell does not exist, create a new one
            cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdToggle] autorelease];
            [cell setSelectionStyle:0];

            UISwitch *toggle = [[UISwitch alloc] init];
            [cell setText:@"Animate switching"];
            [toggle setOn:[[Preferences sharedInstance] animationsEnabled]];
            [toggle addTarget:self action:@selector(switchToggled:) forControlEvents:4096]; // ValueChanged
            [cell setAccessoryView:toggle];
            [toggle release];
        }
    } else {
        static NSString *cellTitles[][3] = {
            {nil, @"Favorites", nil},
            {@"Documentation", nil, nil}
        };

        // Try to retrieve from the table view a now-unused cell with the given identifier
        cell = [tableView dequeueReusableCellWithIdentifier:reuseIdSimple];
        if (cell == nil) {
            // Cell does not exist, create a new one
            cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdSimple] autorelease];
            [cell setSelectionStyle:2]; // Gray
            [cell setAccessoryType:1]; // Simple arrow
        }
        [cell setText:cellTitles[indexPath.section][indexPath.row]];
    }

    return cell;
}

#pragma mark - UITableViewCellDelegate

- (float)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (indexPath.section == 2 && indexPath.row == 0) ? 22.0f : 44.0f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIViewController *vc = nil;

    if (indexPath.section == 0) {
        // Favorites
        vc = [[[FavoritesController alloc] initWithStyle:1] autorelease];
    } else if (indexPath.section == 1) {
        // Documentation
        vc = [[[DocumentationController alloc] initWithStyle:1] autorelease];
    }

    if (vc)
        [[self navigationController] pushViewController:vc animated:YES];
}

#pragma mark - Switch delegate

- (void)switchToggled:(UISwitch *)control
{
    [[Preferences sharedInstance] setAnimationsEnabled:[control isOn]];
}

#pragma mark - UIButton delegate

- (void)openDonationLink
{
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=gaizin%40gmail%2ecom&lc=US&currency_code=USD&bn=PP%2dDonationsBF%3abtn_donateCC_LG%2egif%3aNonHostedGuest"]];
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
