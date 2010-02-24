/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-02-23 14:12:23
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


#import "ColorsController.h"

#import <CoreGraphics/CGGeometry.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

#import "Constants.h"
#import "ColorPickerController.h"
#import "Preferences.h"


@implementation ColorsController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        self.title = @"Color";
    }
    return self;
}

#pragma mark - UITableViewDataSource

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 5;
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdToggle = @"ColorCell";
    static NSString *cellTitles[] = {@"Background", @"Header Text", @"Header Text Shadow", @"Item Text", @"Separator"};

    // Try to retrieve from the table view a now-unused cell with the given identifier
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdToggle];
    if (cell == nil) {
        // Cell does not exist, create a new one
        cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdToggle] autorelease];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;

        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40.0f, 36.0f)];
        view.layer.cornerRadius = 10.0f;
        view.layer.borderWidth = 1.0f;
        view.layer.borderColor = [[UIColor blackColor] CGColor];
        cell.accessoryView = view;
        [view release];
    }
    cell.text = cellTitles[indexPath.section];

    Preferences *prefs = [Preferences sharedInstance];
    unsigned int color;
    switch (indexPath.section) {
        case 0:
            color = prefs.backgroundColor;
            break;
        case 1:
            color = prefs.headerTextColor;
            break;
        case 2:
            color = prefs.headerTextShadowColor;
            break;
        case 3:
            color = prefs.itemTextColor;
            break;
        case 4:
            color = prefs.separatorColor;
            break;
        default:
            color = 0;
    }

    float h = ((color >> 21) & 0x1ff) / 360.0f;
    float s = ((color >> 14) & 0x7f) / 100.0f;
    float b = ((color >> 7) & 0x7f) / 100.0f;
    float a = (color & 0x7f) / 100.0f;
    cell.accessoryView.backgroundColor = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];

    return cell;
}

#pragma mark - UITableViewCellDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    Preferences *prefs = [Preferences sharedInstance];
    unsigned int color;
    switch (indexPath.section) {
        case 0:
            color = prefs.backgroundColor;
            break;
        case 1:
            color = prefs.headerTextColor;
            break;
        case 2:
            color = prefs.headerTextShadowColor;
            break;
        case 3:
            color = prefs.itemTextColor;
            break;
        case 4:
            color = prefs.separatorColor;
            break;
        default:
            color = 0;
    }

    unsigned short h = (color >> 21) & 0x1ff;
    unsigned char s = (color >> 14) & 0x7f;
    unsigned char b = (color >> 7) & 0x7f;
    unsigned char a = color & 0x7f;

    // NOTE: alloc and init are on different lines as otherwise the color
    //       picker's init method conflicts with UIColor (as alloc returns
    //       an id type)
    ColorPickerController *vc = [ColorPickerController alloc];
    vc = [[vc initWithHue:h saturation:s brightness:b alpha:a] autorelease];
    vc.delegate = self;
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - ColorPickerController delegate

- (void)colorPickerController:(ColorPickerController *)controller didUpdateColorWithHue:(unsigned short)h
    saturation:(unsigned char)s brightness:(unsigned char)b alpha:(unsigned char)a
{
    // Save the new color value and update the table
    unsigned int color = (h << 21) | (s << 14) | (b << 7) | a;
    Preferences *prefs = [Preferences sharedInstance];
    NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
    switch (indexPath.section) {
        case 0:
            prefs.backgroundColor = color;
            break;
        case 1:
            prefs.headerTextColor = color;
            break;
        case 2:
            prefs.headerTextShadowColor = color;
            break;
        case 3:
            prefs.itemTextColor = color;
            break;
        case 4:
            prefs.separatorColor = color;
            break;
        default:
            break;
    }

    [self.tableView reloadData];
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
