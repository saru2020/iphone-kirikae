/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-02-23 00:18:05
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


#import "SpectrumSlider.h"

#import "QuartzCore/QuartzCore.h"


@implementation SpectrumSlider

@dynamic value;
@synthesize slider;
@synthesize saturation;
@synthesize brightness;

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
    [slider release];
    [super dealloc];
}

#pragma mark - Drawing related

#define kNumLocations 7

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextClearRect(context, rect);

    // Create an array of color points
    CGFloat locations[kNumLocations] = {0.0f, 60.0f/360.0f, 120.0f/360.0f, 0.5f, 240.0f/360.0f, 300.0f/360.0f, 1.0f};
    CGColorRef *colors = (CGColorRef *)malloc(kNumLocations * sizeof(CGColorRef));
    for (int i = 0; i < kNumLocations; i++)
        colors[i] = [[UIColor colorWithHue:locations[i] saturation:saturation brightness:brightness alpha:1.0f] CGColor];
    CFArrayRef colorsArray = CFArrayCreate(NULL, (void *)colors, kNumLocations, &kCFTypeArrayCallBacks);
    free(colors);

    // Create a gradient using the above colors
    CGGradientRef gradient = CGGradientCreateWithColors(NULL, colorsArray, locations);

    // Draw the gradient across the entire width of the view
    CGPoint start = CGPointMake(0, 0);
    CGPoint end = CGPointMake(rect.size.width - 1, 0);
    CGContextDrawLinearGradient(context, gradient, start, end, 0);

    // Clean-up
    CFRelease(colorsArray);
    CGGradientRelease(gradient);
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

- (void)setSaturation:(float)saturation_
{
    if (saturation != saturation_) {
        saturation = saturation_;
        [self setNeedsDisplay];
    }
}

- (void)setBrightness:(float)brightness_
{
    if (brightness != brightness_) {
        brightness = brightness_;
        [self setNeedsDisplay];
    }
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */