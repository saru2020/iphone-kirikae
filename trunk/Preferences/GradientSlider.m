/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-02-24 00:56:23
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


#import "GradientSlider.h"

#import <QuartzCore/QuartzCore.h>


@implementation GradientSlider

@dynamic value;
@synthesize slider;
@synthesize startColor;
@synthesize endColor;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.opaque = NO;
        self.layer.borderWidth = 1.0f;
        self.layer.borderColor = [[UIColor blackColor] CGColor];

        slider = [[UISlider alloc] initWithFrame:CGRectMake(0, (frame.size.height - 23.0f) / 2.0f, frame.size.width, 23.0f)];
        [slider setMinimumTrackImage:nil forState:UIControlStateNormal];
        [slider setMaximumTrackImage:nil forState:UIControlStateNormal];
        [slider setThumbImage:[UIImage imageNamed:@"gradient_slider_btn.png"] forState:UIControlStateNormal];
        [self addSubview:slider];
    }
    return self;
}

- (void)dealloc
{
    [endColor release];
    [startColor release];
    [slider release];

    [super dealloc];
}

#pragma mark - Drawing related

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextClearRect(context, rect);

    if (startColor != nil && endColor != nil) {
        // Create a gradient using the assigned colors
        const void *colorRefs[2] = {startColor.CGColor, endColor.CGColor};
        CFArrayRef colors = CFArrayCreate(NULL, colorRefs, 2, &kCFTypeArrayCallBacks);
        CGFloat locations[2] = {0.0f, 1.0f};
        CGGradientRef gradient = CGGradientCreateWithColors(NULL, colors, locations);

        // Draw the gradient across the entire width of the view
        CGPoint start = CGPointMake(0, 0);
        CGPoint end = CGPointMake(rect.size.width - 1, 0);
        CGContextDrawLinearGradient(context, gradient, start, end, 0);

        // Clean-up
        CFRelease(colors);
        CGGradientRelease(gradient);
    }
}

#pragma mark - Properties

- (float)value
{
    return slider.value;
}

- (void)setValue:(float)value
{
    slider.value = value;
}

- (void)setStartColor:(UIColor *)color
{
    if (startColor != color) {
        [startColor release];
        startColor = [color retain];
        [self setNeedsDisplay];
    }
}

- (void)setEndColor:(UIColor *)color
{
    if (endColor != color) {
        [endColor release];
        endColor = [color retain];
        [self setNeedsDisplay];
    }
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
