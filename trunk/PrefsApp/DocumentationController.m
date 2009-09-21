/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-09-21 18:12:29
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


#import "DocumentationController.h"

#include <stdlib.h>

#import <CoreGraphics/CGGeometry.h>

#import <Foundation/Foundation.h>

#import "Constants.h"
#import "HtmlDocController.h"
#import "FavoritesController.h"
#import "Preferences.h"


@implementation DocumentationController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        self.title = @"Documentation";
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back"
            style:UIBarButtonItemStyleBordered target:nil action:nil];
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    // Reset the table by deselecting the current selection
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}

#pragma mark - UITableViewDataSource

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(int)section
{
    return nil;
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    return 4;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdSafari = @"SafariCell";
    static NSString *reuseIdSimple = @"SimpleCell";

    UITableViewCell *cell = nil;

    if (indexPath.row == 3) {
        // Try to retrieve from the table view a now-unused cell with the given identifier
        cell = [tableView dequeueReusableCellWithIdentifier:reuseIdSafari];
        if (cell == nil) {
            // Cell does not exist, create a new one
            cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdSafari] autorelease];
            [cell setSelectionStyle:2]; // Gray

            UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
            [label setText:@"(via Safari)"];
            [label setTextColor:[UIColor colorWithRed:0.2f green:0.31f blue:0.52f alpha:1.0f]];
            [label setFont:[UIFont systemFontOfSize:16.0f]];
            CGSize size = [label.text sizeWithFont:label.font];
            [label setFrame:CGRectMake(0, 0, size.width, size.height)];

            [cell setAccessoryView:label];
            [label release];
        }

        [cell setText:@"Project Homepage"];
    } else {
        static NSString *cellTitles[] = {@"How to Use", @"Release Notes", @"Known Issues"};

        // Try to retrieve from the table view a now-unused cell with the given identifier
        cell = [tableView dequeueReusableCellWithIdentifier:reuseIdSimple];
        if (cell == nil) {
            // Cell does not exist, create a new one
            cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdSimple] autorelease];
            [cell setSelectionStyle:2]; // Gray
            [cell setAccessoryType:1]; // Simple arrow
        }
        [cell setText:cellTitles[indexPath.row]];
    }

    return cell;
}

#pragma mark - UITableViewCellDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *fileNames[] = { @"usage.mdwn", @"release_notes.mdwn", @"known_issues.mdwn" };
    static NSString *titles[] = { @"How to Use", @"Release Notes", @"Known Issues" };

    if (indexPath.row == 3) {
        // Project Homepage
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@DEVSITE_URL]];
    } else {
    UIViewController *vc = [[[HtmlDocController alloc]
            initWithContentsOfFile:fileNames[indexPath.row] title:titles[indexPath.row]]
            autorelease];
        [(HtmlDocController *)vc setTemplateFileName:@"template.html"];
        [[self navigationController] pushViewController:vc animated:YES];
    }
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
