/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-02-26 01:37:00
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

#import <objc/runtime.h>
#import <libactivator/libactivator.h>

#import "AppearanceController.h"
#import "Constants.h"
#import "DocumentationController.h"
#import "HtmlDocController.h"
#import "Preferences.h"
#import "TabsController.h"

//==============================================================================

@interface KirikaeSettingsViewController : LAListenerSettingsViewController
{
}
@end

@implementation KirikaeSettingsViewController

- (id)init
{
    self = [super init];
    if (self) {
        // FIXME: Currently "Home Button - Single Press" is hidden; must
        //        manually add it to the list of options
 
        // Get list of all events (private variable)
        NSMutableDictionary *_events = nil;
        object_getInstanceVariable(self, "_events", (void **)&_events);

        // Get name of group containing "Single Press"
        NSString *group = [[LAActivator sharedInstance]
            localizedGroupForEventName:LAEventNameMenuPressSingle];

        // Add "Single Press" to list of allowed events
        [[_events objectForKey:group] addObject:LAEventNameMenuPressSingle];
    }
    return self;
}

@end

//==============================================================================

@implementation RootController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        self.title = @"Kirikae";
        self.navigationItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Back"
            style:UIBarButtonItemStyleBordered target:nil action:nil] autorelease];
    }
    return self;
}

- (void)viewDidLoad
{
    // Create and add footer view
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320.0f, 188.0f)];

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
    static int rows[] = {3, 1};
    return rows[section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdSimple = @"SimpleCell";
    static NSString *reuseIdRightValue = @"RightValueCell";
    static NSString *reuseIdSubtitle = @"SubtitleCell";

    UITableViewCell *cell = nil;
    if (indexPath.section == 0) {
        if (indexPath.row == 1) {
            // Try to retrieve from the table view a now-unused cell with the given identifier
            cell = [tableView dequeueReusableCellWithIdentifier:reuseIdRightValue];
            if (cell == nil) {
                // Cell does not exist, create a new one
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdRightValue] autorelease];
                cell.selectionStyle = UITableViewCellSelectionStyleGray;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
            cell.textLabel.text = @"Control";
            cell.detailTextLabel.text = @"(via Activator)";
        } else {
            static NSString *cellTitles[] = {@"Appearance", nil, @"Tabs"};

            // Try to retrieve from the table view a now-unused cell with the given identifier
            cell = [tableView dequeueReusableCellWithIdentifier:reuseIdSimple];
            if (cell == nil) {
                // Cell does not exist, create a new one
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdSimple] autorelease];
                cell.selectionStyle = UITableViewCellSelectionStyleGray;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
            cell.textLabel.text = cellTitles[indexPath.row];
        }
    } else {
        // Try to retrieve from the table view a now-unused cell with the given identifier
        cell = [tableView dequeueReusableCellWithIdentifier:reuseIdSubtitle];
        if (cell == nil) {
            // Cell does not exist, create a new one
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdSubtitle] autorelease];
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
            cell.textLabel.text = @"Documentation";
            cell.detailTextLabel.text = @"Usage, Issues, Todo, etc.";
        }

    return cell;
}

#pragma mark - UITableViewCellDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIViewController *vc = nil;

    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0:
                // Appearance
                vc = [[[AppearanceController alloc] initWithStyle:1] autorelease];
                break;
            case 1:
                // Control
                vc = [[[KirikaeSettingsViewController alloc] init] autorelease];
                [(KirikaeSettingsViewController *)vc setListenerName:@APP_ID];
                break;
            case 2:
                // Tabs
                vc = [[[TabsController alloc] initWithStyle:1] autorelease];
                break;
            default:
                break;
        }
    } else {
        // Documentation
        vc = [[[DocumentationController alloc] initWithStyle:1] autorelease];
    }

    if (vc)
        [[self navigationController] pushViewController:vc animated:YES];
}

#pragma mark - UIButton delegate

- (void)openDonationLink
{
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=gaizin%40gmail%2ecom&lc=US&currency_code=USD&bn=PP%2dDonationsBF%3abtn_donateCC_LG%2egif%3aNonHostedGuest"]];
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
