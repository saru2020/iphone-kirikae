/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-02-26 01:40:12
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


#import "FavoritePickerController.h"

#import "Application.h"
#import "ApplicationCell.h"
#import "HtmlDocController.h"
#import "Preferences.h"
#import "RootController.h"

// SpringBoardServices
extern NSString * SBSCopyLocalizedApplicationNameForDisplayIdentifier(NSString *identifier);
extern NSString * SBSCopyIconImagePathForDisplayIdentifier(NSString *identifier);

#define HELP_FILE "favorites.html"


@interface UIProgressHUD : UIView
- (id)initWithWindow:(id)fp8;
- (void)setText:(id)fp8;
- (void)show:(BOOL)fp8;
- (void)hide;
@end

@interface UIWebClip : NSObject
@property(copy) NSString *identifier;
@property(copy) NSString *title;
@property(retain) UIImage *iconImage;
+ (id)webClips;
+ (UIWebClip *)webClipWithIdentifier:(id)identifier;
@end

//________________________________________________________________________________
//________________________________________________________________________________

// For applications
static NSInteger compareDisplayNames(NSString *a, NSString *b, void *context)
{
    NSInteger ret;

    NSString *name_a = SBSCopyLocalizedApplicationNameForDisplayIdentifier(a);
    NSString *name_b = SBSCopyLocalizedApplicationNameForDisplayIdentifier(b);
    ret = [name_a caseInsensitiveCompare:name_b];
    [name_a release];
    [name_b release];

    return ret;
}

// For web clips
static NSInteger compareTitles(NSString *a, NSString *b, void *context)
{
    NSString *name_a = [[UIWebClip webClipWithIdentifier:a] title];
    NSString *name_b = [[UIWebClip webClipWithIdentifier:b] title];

    return [name_a caseInsensitiveCompare:name_b];
}

//________________________________________________________________________________
//________________________________________________________________________________

static NSArray *applicationDisplayIdentifiers()
{
    // First, get a list of all possible application paths
    NSMutableArray *paths = [NSMutableArray array];

    // ... scan /Applications (System/Jailbreak applications)
    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *path in [fileManager directoryContentsAtPath:@"/Applications"]) {
        if ([path hasSuffix:@".app"] && ![path hasPrefix:@"."])
           [paths addObject:[NSString stringWithFormat:@"/Applications/%@", path]];
    }

    // ... scan /var/mobile/Applications (AppStore applications)
    for (NSString *path in [fileManager directoryContentsAtPath:@"/var/mobile/Applications"]) {
        for (NSString *subpath in [fileManager directoryContentsAtPath:
                [NSString stringWithFormat:@"/var/mobile/Applications/%@", path]]) {
            if ([subpath hasSuffix:@".app"])
                [paths addObject:[NSString stringWithFormat:@"/var/mobile/Applications/%@/%@", path, subpath]];
        }
    }

    // Then, go through paths and record valid application identifiers
    NSMutableArray *identifiers = [NSMutableArray array];

    for (NSString *path in paths) {
        NSBundle *bundle = [NSBundle bundleWithPath:path];
        if (bundle) {
            NSString *identifier = [bundle bundleIdentifier];

            // Filter out non-applications and apps that should remain hidden
            // FIXME: The proper fix is to only show non-hidden apps and apps
            //        that are in Categories; unfortunately, the design of
            //        Categories does not make it easy to determine what apps
            //        a given folder contains.
            if (identifier &&
                ![identifier hasPrefix:@"jp.ashikase.springjumps."] &&
                ![identifier hasPrefix:@"com.apple.mobileslideshow"] &&
                ![identifier hasPrefix:@"com.apple.mobileipod"] &&
                ![identifier isEqualToString:@"com.iptm.bigboss.sbsettings"] &&
                ![identifier isEqualToString:@"com.apple.webapp"])
            [identifiers addObject:identifier];
        }
    }

    // Finally, add identifiers for apps known to have multiple roles
    [identifiers addObject:[NSString stringWithString:@"com.apple.mobileslideshow-Camera"]];
    [identifiers addObject:[NSString stringWithString:@"com.apple.mobileslideshow-Photos"]];
    if ([[[UIDevice currentDevice] model] hasPrefix:@"iPhone"]) {
        // iPhone
        [identifiers addObject:[NSString stringWithString:@"com.apple.mobileipod-MediaPlayer"]];
    } else {
        // iPod Touch
        [identifiers addObject:[NSString stringWithString:@"com.apple.mobileipod-AudioPlayer"]];
        [identifiers addObject:[NSString stringWithString:@"com.apple.mobileipod-VideoPlayer"]];
    }

    return identifiers;
}

//________________________________________________________________________________
//________________________________________________________________________________

@interface FavoritePickerController (Private)
- (void)switchToApplications;
@end

@implementation FavoritePickerController

@synthesize delegate;

- (id)init
{
    self = [super init];
    if (self) {
        // Try to retrieve cached list of applications and webclips
        Application *application = (Application *)[UIApplication sharedApplication];
        apps = [application.applicationIdentifiers copy];
        webClips = [application.webClipIdentifiers copy];
        NSLog(@"=== INST, apps: %@", apps);
    }
    return self;
}

- (void)loadView
{
	// Create a container view
    UIView *view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];

	// Create a navigation bar
	UINavigationBar *navBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, 320.0f, 44.0f)];
	navBar.barStyle = UIBarStyleBlackOpaque;
	navBar.delegate = self;

	// Add title and buttons to navigation bar
	navItem = [[UINavigationItem alloc] initWithTitle:@"Tap to add..."];
    navItem.leftBarButtonItem =
         [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
         target:self action:@selector(doneButtonTapped)] autorelease];;
    navItem.rightBarButtonItem =
         [[[UIBarButtonItem alloc] initWithTitle:@"Web Clips" style:UIBarButtonItemStylePlain
            target:self action:@selector(modeButtonTapped)] autorelease];;
	[navBar pushNavigationItem:navItem animated:NO];

	// Create a table
    float barHeight = navBar.bounds.size.height;
	itemsTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, barHeight, 320.0f, view.bounds.size.height - barHeight)];
	itemsTableView.dataSource = self;
	itemsTableView.delegate = self;
    
    [view addSubview:itemsTableView];
    [view addSubview:navBar]; 
    [navBar release];

    self.view = view;
    [view release];
}

- (void)dealloc
{
    [busyIndicator release];
    [webClips release];
    [apps release];

    [navItem release];
    [itemsTableView release];

    [super dealloc];
}

- (void)viewDidAppear:(BOOL)animated
{
    // Initially start with list of applications
    [self switchToApplications];
}

- (void)viewWillDisappear:(BOOL)animated
{
    // Cache the list of available applications and web clips
    Application *application = (Application *)[UIApplication sharedApplication];
    application.applicationIdentifiers = apps;
    application.webClipIdentifiers = webClips;
    NSLog(@"=== DISA, apps: %@", apps);
}

#pragma mark - Item enumeration

- (void)enumerateApplications
{
    // Get list of all available applications
    NSMutableArray *array = [NSMutableArray arrayWithArray:applicationDisplayIdentifiers()];

    // Remove items that are already favorited
    [array removeObjectsInArray:[[Preferences sharedInstance] objectForKey:kFavorites]];

    // Sort the remaining items and cache in root controller
    NSArray *sortedArray = [array sortedArrayUsingFunction:compareDisplayNames context:NULL];
    items = apps = [[NSMutableArray alloc] initWithArray:sortedArray];

    // Update the table
    [itemsTableView reloadData];

    // Remove the progress indicator
    [busyIndicator hide];
    [busyIndicator release];
    busyIndicator = nil;
}

- (void)enumerateWebClips
{
    // Get list of all available web clips
    NSMutableArray *array = [NSMutableArray array];
    for (UIWebClip *clip in [UIWebClip webClips])
        [array addObject:clip.identifier];

    // Remove items that are already favorited
    [array removeObjectsInArray:[[Preferences sharedInstance] objectForKey:kFavorites]];

    // Sort the remaining items and cache in root controller
    NSArray *sortedArray = [array sortedArrayUsingFunction:compareTitles context:NULL];
    items = webClips = [[NSMutableArray alloc] initWithArray:sortedArray];

    // Update the table
    [itemsTableView reloadData];

    // Remove the progress indicator
    [busyIndicator hide];
    [busyIndicator release];
    busyIndicator = nil;
}

- (void)switchToApplications
{
    navItem.rightBarButtonItem.title = @"Web Clips";

    items = apps;
    if (items == nil) {
        // Show a progress indicator
        busyIndicator = [[UIProgressHUD alloc] initWithWindow:[[UIApplication sharedApplication] keyWindow]];
        [busyIndicator setText:@"Loading applications..."];
        [busyIndicator show:YES];

        // Enumerate applications
        // NOTE: Must call via performSelector, or busy indicator does not show in time
        [self performSelector:@selector(enumerateApplications) withObject:nil afterDelay:0.1f];
    } else {
        // Application list already loaded
        [itemsTableView reloadData];
    }
}

- (void)switchToWebClips
{
    navItem.rightBarButtonItem.title = @"Apps";

    items = webClips;
    if (items == nil) {
        // Show a progress indicator
        busyIndicator = [[UIProgressHUD alloc] initWithWindow:[[UIApplication sharedApplication] keyWindow]];
        [busyIndicator setText:@"Loading web clips..."];
        [busyIndicator show:YES];

        // Enumerate applications
        // NOTE: Must call via performSelector, or busy indicator does not show in time
        [self performSelector:@selector(enumerateWebClips) withObject:nil afterDelay:0.1f];
    } else {
        // Web clips list already loaded
        [itemsTableView reloadData];
    }
}

#pragma mark - UITableViewDataSource

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    return [items count];
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

    NSString *identifier = [items objectAtIndex:indexPath.row];
    NSString *name = nil;
    UIImage *icon = nil;
    if (items == apps) {
        name = SBSCopyLocalizedApplicationNameForDisplayIdentifier(identifier);

        NSString *iconPath = SBSCopyIconImagePathForDisplayIdentifier(identifier);
        if (iconPath != nil) {
            icon = [UIImage imageWithContentsOfFile:iconPath];
            [iconPath release];
        }
    } else {
        UIWebClip *clip = [UIWebClip webClipWithIdentifier:identifier];
        name = clip.title;
        icon = clip.iconImage;
    }
    cell.textLabel.text = name;
    cell.imageView.image = icon;

    return cell;
}

#pragma mark - UITableViewCellDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Inform delegate that item has been selected
    if ([delegate respondsToSelector:@selector(favoritePickerController:didSelectItemWithIdentifier:)]) {
        NSString *identifier = [items objectAtIndex:indexPath.row];
        [delegate favoritePickerController:self didSelectItemWithIdentifier:identifier];
    }

    // Remove the item from the table
    [items removeObjectAtIndex:indexPath.row];
    [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
}

#pragma mark - Navigation bar delegates

- (void)doneButtonTapped
{
    [self.parentViewController dismissModalViewControllerAnimated:YES];
}

- (void)modeButtonTapped
{
    // Switch between displaying apps and web clips
    if (items == apps)
        // Switch to web clips
        [self switchToWebClips];
    else
        // Switch to apps
        [self switchToApplications];

    [itemsTableView reloadData];
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
