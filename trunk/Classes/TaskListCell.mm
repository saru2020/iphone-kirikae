/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-12-17 01:25:04
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

@synthesize iconImage;
@synthesize badgeImage;

- (void)dealloc
{
    [iconImage release];
    [badgeImage release];

    [super dealloc];
}

- (void)layoutSubviews
{
    BOOL useLargeRows = (self.bounds.size.height > 50.0f);

    // Call original layoutSubviews implementation
    [super layoutSubviews];

    // Set label position
    CGRect frame = self.textLabel.frame;
    frame.origin.x = useLargeRows ? 68.0f : 43.0f;
    self.textLabel.frame = frame;

    // Set accessory view position
    if (self.accessoryView != nil) {
        frame = self.accessoryView.frame;
        if ([self.accessoryView isKindOfClass:[UIButton class]])
            frame.origin.x = 281.0f;
        else if ([self.accessoryView isKindOfClass:[UIActivityIndicatorView class]])
            frame.origin.x = 290.0f;
        self.accessoryView.frame = frame;
    }

    // Set the size of the image canvas large enough to hold the icon image
    // NOTE: Size of icon is assumed to always be 59x62 (SpringBoard's default).
    //       This may cause issues if an extension changes this.
    CGSize size = CGSizeMake(59.0f, 62.0f);

    float yOffset = 0;
    if (badgeImage != nil) {
        // Increase the size of the canvas to make room for a badge
        size.width += 10.0f;
        size.height += 7.0f * 2.0f;
        if (!useLargeRows) {
            // Small rows use an enlarged badge to improve visibility
            CGSize bSize = badgeImage.size;
            size.width += bSize.width * 0.25f;
            size.height += bSize.height * 0.5f;
        }
        yOffset = (size.height - 62.0f) / 2.0f;
    }

    UIGraphicsBeginImageContext(size);

    // Draw the icon image
    [iconImage drawInRect:CGRectMake(0, yOffset, 59.0f, 62.0f)];

    // Draw the badge image
    if (badgeImage) {
        CGSize bSize = badgeImage.size;
        float bxOffset = 0;
        float byOffset = 0;
        if (!useLargeRows) {
            bxOffset = bSize.width * 0.25f;
            byOffset = bSize.height * 0.25f;
            bSize.width *= 1.5f;
            bSize.height *= 1.5f;
        }
        [badgeImage drawInRect:CGRectMake(69.0f - bSize.width + bxOffset, 0, bSize.width, bSize.height)];
    }

    // Use the composited image for the cell
    self.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // Set the size and position of the icon image view
    if (useLargeRows) {
        if (badgeImage == nil)
            self.imageView.frame = CGRectMake(5.0f, 5.0f, 50.0f, 50.0f);
        else
            self.imageView.frame = CGRectMake(5.0f, 3.0f, 58.0f, 61.0f);
    } else {
        if (badgeImage == nil)
            self.imageView.frame = CGRectMake(5.0f, 7.0f, 29.0f, 30.0f);
        else
            self.imageView.frame = CGRectMake(5.0f, 2.0f, 37.0f, 44.0f);
    }
}

@end

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
