/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-09-12 16:36:06
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


@implementation TaskListCell

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
    [badgeView release];
    [super dealloc];
}

- (void)setBadge:(UIImage *)badge
{
    [badgeView setImage:badge];
    badgeView.bounds = CGRectMake(0, 0, badge.size.width, badge.size.height);
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    if (badgeView.image) {
        UIImageView *imageView = [self imageView];
        CGRect rect = [imageView frame];

        // Position badge at upper-right corner of icon image
        CGPoint corner = CGPointMake(rect.origin.x + rect.size.width - 1, rect.origin.y);
        badgeView.origin = CGPointMake(corner.x - [badgeView.image size].width + 11.0f, corner.y - 8.0f);
        [self.contentView bringSubviewToFront:badgeView];

        // Adjusting height of cell (for badge) causes left margin of cell to increase
        rect.origin.x -= 4.0f;
        [imageView setFrame:rect];
    }
}

@end

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
