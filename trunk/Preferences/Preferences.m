/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-02-23 16:24:23
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


#import "Preferences.h"

#import <Foundation/Foundation.h>


// Allowed values
static NSArray *allowedInitialViews = nil;

@implementation Preferences

@synthesize firstRun;
@synthesize animationsEnabled;
@synthesize useLargeRows;
@synthesize useThemedIcons;
@synthesize showActive;
@synthesize showFavorites;
@synthesize showSpotlight;
@synthesize showSpringBoard;
@synthesize initialView;
@synthesize favorites;

@synthesize backgroundColor;       
@synthesize headerTextColor;       
@synthesize headerTextShadowColor; 
@synthesize itemTextColor;         
@synthesize separatorColor;        

#pragma mark - Methods

+ (Preferences *)sharedInstance
{
    static Preferences *instance = nil;
    if (instance == nil)
        instance = [[Preferences alloc] init];
    return instance;
}

- (id)init
{
    self = [super init];
    if (self) {
        allowedInitialViews = [[NSArray alloc] initWithObjects:
            @"active", @"favorites", @"spotlight", @"springboard", @"lastUsed", nil];

        // Setup default values
        [self registerDefaults];

        // Load preference values into memory
        [self readFromDisk];

        // Retain a copy of the initial values of the preferences
        initialValues = [[self dictionaryRepresentation] retain];

        // The on-disk values at startup are the same as initialValues
        onDiskValues = [initialValues retain];
    }
    return self;
}

- (void)dealloc
{
    [onDiskValues release];
    [initialValues release];
    [allowedInitialViews release];

    [super dealloc];
}

#pragma mark - Other

- (NSDictionary *)dictionaryRepresentation
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:4];

    [dict setObject:[NSNumber numberWithBool:firstRun] forKey:@"firstRun"];
    [dict setObject:[NSNumber numberWithBool:animationsEnabled] forKey:@"animationsEnabled"];
    [dict setObject:[NSNumber numberWithBool:useLargeRows] forKey:@"useLargeRows"];
    [dict setObject:[NSNumber numberWithBool:useThemedIcons] forKey:@"useThemedIcons"];
    [dict setObject:[NSNumber numberWithBool:showActive] forKey:@"showActive"];
    [dict setObject:[NSNumber numberWithBool:showFavorites] forKey:@"showFavorites"];
    [dict setObject:[NSNumber numberWithBool:showSpotlight] forKey:@"showSpotlight"];
    [dict setObject:[NSNumber numberWithBool:showSpringBoard] forKey:@"showSpringBoard"];

    [dict setObject:[NSNumber numberWithUnsignedInt:backgroundColor] forKey:@"backgroundColor"];
    [dict setObject:[NSNumber numberWithUnsignedInt:headerTextColor] forKey:@"headerTextColor"];
    [dict setObject:[NSNumber numberWithUnsignedInt:headerTextShadowColor] forKey:@"headerTextShadowColor"];
    [dict setObject:[NSNumber numberWithUnsignedInt:itemTextColor] forKey:@"itemTextColor"];
    [dict setObject:[NSNumber numberWithUnsignedInt:separatorColor] forKey:@"separatorColor"];

    NSString *string = nil;
    @try {
        string = [allowedInitialViews objectAtIndex:initialView];
        [dict setObject:[string copy] forKey:@"initialView"];
    }
    @catch (NSException *exception) {
        // Ignore the exception (assumed to be NSRangeException)
    }

    [dict setObject:[favorites copy] forKey:@"favorites"];

    return dict;
}

#pragma mark - Status

- (BOOL)isModified
{
    return ![[self dictionaryRepresentation] isEqual:onDiskValues];
}

- (BOOL)needsRespring
{
    return ![[self dictionaryRepresentation] isEqual:initialValues];
}

#pragma mark - Read/Write methods

- (void)registerDefaults
{
    // NOTE: This method sets default values for options that are not already
    //       set in the application's on-disk preferences list.

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:4];

    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"firstRun"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"animationsEnabled"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"useLargeRows"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"useThemedIcons"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"showActive"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"showFavorites"];
    [dict setObject:[NSNumber numberWithBool:NO] forKey:@"showSpotlight"];
    [dict setObject:[NSNumber numberWithBool:NO] forKey:@"showSpringBoard"];
    [dict setObject:[NSString stringWithString:@"active"] forKey:@"initialView"];
    [dict setObject:[NSArray array] forKey:@"favorites"];

    [dict setObject:[NSNumber numberWithUnsignedInt:0xffffffff] forKey:@"backgroundColor"];
    [dict setObject:[NSNumber numberWithUnsignedInt:0xffffffff] forKey:@"headerTextColor"];
    [dict setObject:[NSNumber numberWithUnsignedInt:0x00000000] forKey:@"headerTextShadowColor"];
    [dict setObject:[NSNumber numberWithUnsignedInt:0x000000ff] forKey:@"itemTextColor"];
    [dict setObject:[NSNumber numberWithUnsignedInt:0x7f7f7fff] forKey:@"separatorColor"];

    [defaults registerDefaults:dict];
}

- (void)readFromDisk
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    firstRun = [defaults boolForKey:@"firstRun"];
    animationsEnabled = [defaults boolForKey:@"animationsEnabled"];
    useLargeRows = [defaults boolForKey:@"useLargeRows"];
    useThemedIcons = [defaults boolForKey:@"useThemedIcons"];
    showActive = [defaults boolForKey:@"showActive"];
    showFavorites = [defaults boolForKey:@"showFavorites"];
    showSpotlight = [defaults boolForKey:@"showSpotlight"];
    showSpringBoard = [defaults boolForKey:@"showSpringBoard"];

    backgroundColor = (unsigned int)[defaults integerForKey:@"backgroundColor"];
    headerTextColor = (unsigned int)[defaults integerForKey:@"headerTextColor"];
    headerTextColor = (unsigned int)[defaults integerForKey:@"headerTextShadowColor"];
    itemTextColor = (unsigned int)[defaults integerForKey:@"itemTextColor"];
    separatorColor = (unsigned int)[defaults integerForKey:@"separatorColor"];

    NSString *string = [defaults stringForKey:@"initialView"];
    unsigned int index = [allowedInitialViews indexOfObject:string];
    initialView = (index == NSNotFound) ? 0 : index;

    favorites = [[defaults arrayForKey:@"favorites"] retain];
}

- (void)writeToDisk
{
    NSDictionary *dict = [self dictionaryRepresentation];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setPersistentDomain:dict forName:[[NSBundle mainBundle] bundleIdentifier]];
    [defaults synchronize];

    // Update the list of on-disk values
    [onDiskValues release];
    onDiskValues = [dict retain];
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
