/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-09-08 23:19:15
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


#import "TaskListCell.h"

#import "Common.h"


@implementation TaskListCell

@synthesize badge;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier];
    if (self) {
        badgeView = [[UIImageView alloc] initWithFrame:CGRectZero];
        [self.contentView addSubview:badgeView];
    }
    return self;
}

- (void)dealloc
{
    [badge release];
    [badgeView release];

    [super dealloc];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    if (badge) {
        // Determine position of upper-right corner of icon image
        UIImageView *imageView = MSHookIvar<UIImageView *>(self, "_imageView");
        CGRect imageRect = [imageView frame];
        CGPoint corner = CGPointMake(imageRect.origin.x + imageRect.size.width - 1, imageRect.origin.y);

        [badgeView setImage:badge];
        [badgeView setOrigin:CGPointMake(corner.x - badge.size.width + 11.0f, corner.y - 8.0f)];
        [self.contentView bringSubviewToFront:badgeView];
    }
}

@end

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
