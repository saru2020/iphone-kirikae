/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-02-26 00:04:08
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

#import "ApplicationCell.h"
#import "HtmlDocController.h"
#import "Preferences.h"

// SpringBoardServices
extern NSString * SBSCopyLocalizedApplicationNameForDisplayIdentifier(NSString *identifier);
extern NSString * SBSCopyIconImagePathForDisplayIdentifier(NSString *identifier);

@interface UIWebClip : NSObject
@property(copy) NSString *identifier;
@property(copy) NSString *title;
@property(retain) UIImage *iconImage;
+ (id)webClips;
+ (UIWebClip *)webClipWithIdentifier:(id)identifier;
@end

//==============================================================================

@implementation FavoritesController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        self.title = @"Favorites";
        self.navigationItem.rightBarButtonItem =
             [[UIBarButtonItem alloc] initWithTitle:@"Add" style:5
                target:self action:@selector(addButtonTapped)];

        // Get a copy of the list of favorites
        favorites = [[NSMutableArray alloc]
            initWithArray:[[Preferences sharedInstance] objectForKey:kFavorites]];

        self.tableView.editing = YES;
    }
    return self;
}

- (void)dealloc
{
    [favorites release];
    [super dealloc];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.tableView reloadData];
    /// Reset the table by deselecting the current selection
    //[self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}

#pragma mark - UITableViewDataSource

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    return [favorites count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdentifier = @"FavoritesCell";

    // Try to retrieve from the table view a now-unused cell with the given identifier
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil) {
        // Cell does not exist, create a new one
        cell = [[[ApplicationCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdentifier] autorelease];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
    }

    NSString *identifier = [favorites objectAtIndex:indexPath.row];
    NSString *name = nil;
    UIImage *icon = nil;
    NSRange range = [identifier rangeOfString:@"."];
    if (range.location == NSNotFound && [identifier length] == 32) {
        // Identifier is 32 characters long and has no periods; assume web clip
        UIWebClip *clip = [UIWebClip webClipWithIdentifier:identifier];
        name = clip.title;
        icon = clip.iconImage;
    } else {
        // Application
        name = SBSCopyLocalizedApplicationNameForDisplayIdentifier(identifier);

        NSString *iconPath = SBSCopyIconImagePathForDisplayIdentifier(identifier);
        if (iconPath != nil) {
            icon = [UIImage imageWithContentsOfFile:iconPath];
            [iconPath release];
        }
    }
    cell.textLabel.text = name;
    cell.imageView.image = icon;


    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
	return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
	toIndexPath:(NSIndexPath *)destinationIndexPath
{
	int fromRow = sourceIndexPath.row;
	int toRow = destinationIndexPath.row;
	
    // Remove item from current position
	NSString *item = [[favorites objectAtIndex:fromRow] retain];
    [favorites removeObjectAtIndex:fromRow];

    // Insert cell at new position
    if (fromRow < toRow) {
        // Moving Down
        if (toRow == [favorites count])
            // Add to end of cell array
            [favorites addObject:item];
        else
            [favorites insertObject:item atIndex:toRow];
    } else {
        // Moving Up
        [favorites insertObject:item atIndex:toRow];
    }
    [item release];

    // Immediately save updated favorites to disk
    [[Preferences sharedInstance] setObject:favorites forKey:kFavorites];
}
 
- (BOOL)table:(UITableView*)table canDeleteRowAtIndexPath:(NSIndexPath *)indexPath
{
	return YES;
}

- (void)tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		// Remove the item from the table
        [favorites removeObjectAtIndex:indexPath.row];
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];

        // Immediately save updated favorites to disk
        [[Preferences sharedInstance] setObject:favorites forKey:kFavorites];
	}
}

#pragma mark - Navigation bar delegates

- (void)addButtonTapped
{
    // Create and show help page
    FavoritePickerController *picker = [[[FavoritePickerController alloc] init] autorelease];
    picker.delegate = self;
    [self presentModalViewController:picker animated:YES];
}

#pragma mark - Favorite picker delegate

- (void)favoritePickerController:(FavoritePickerController *)controller didSelectItemWithIdentifier:(NSString *)identifier
{
    // Update the list of favorites
    [favorites addObject:identifier];

    // Immediately save updated favorites to disk
    [[Preferences sharedInstance] setObject:favorites forKey:kFavorites];
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
