/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-02-24 00:55:19
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


#import "ColorPickerController.h"

#import <QuartzCore/QuartzCore.h>

#import "Constants.h"
#import "GradientSlider.h"
#import "Preferences.h"
#import "SpectrumSlider.h"
#import "ToggleButton.h"


@interface ColorPickerController (Private)
- (void)updateColor;
@end

//==============================================================================

@implementation ColorPickerController

@synthesize delegate;

- (id)initWithHue:(unsigned short)h saturation:(unsigned char)s brightness:(unsigned char)b alpha:(unsigned char)a;
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title = @"Select a Color";
        hue = h;
        saturation = s;
        brightness = b;
        alpha = a;
    }
    return self;
}

- (void)loadView
{
    // Create container view
    UIView *view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
    view.backgroundColor = [UIColor groupTableViewBackgroundColor];

    // Create color preview view
    colorView = [[UIView alloc] initWithFrame:CGRectMake(20.0f, 20.0f, 280.0f, 120.0f)];
    colorView.layer.cornerRadius = 10.0f;
    colorView.layer.borderWidth = 1.0f;
    colorView.layer.borderColor = [[UIColor blackColor] CGColor];
    [view addSubview:colorView];

    // Create a slider for hue
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 157.0f, 32.0f, 21.0f)];
    label.text = @"Hue";
    label.backgroundColor = [UIColor clearColor];
    [view addSubview:label];
    [label release];

    hueValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(256.0f, 157.0f, 44.0f, 21.0f)];
    hueValueLabel.text = @"255";
    hueValueLabel.textAlignment = UITextAlignmentRight;
    hueValueLabel.backgroundColor = [UIColor clearColor];
    [view addSubview:hueValueLabel];

    // NOTE: The maximum allowed value for hue is set to 359 degrees,
    //       since 360 degrees == 0 degrees (hue:1.0f == hue:0.0f)
    hueSlider = [[SpectrumSlider alloc] initWithFrame:CGRectMake(18.0f, 186.0f, 284.0f, 23.0f)];
    hueSlider.slider.maximumValue = 359.0f;
    hueSlider.value = hue;
    [hueSlider.slider addTarget:self action:@selector(updateColor) forControlEvents:UIControlEventValueChanged];
    [hueSlider.slider addTarget:self action:@selector(notifyDelegate) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:hueSlider];

    // Create a slider for saturation
    label = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 221.0f, 78.0f, 21.0f)];
    label.text = @"Saturation";
    label.backgroundColor = [UIColor clearColor];
    [view addSubview:label];
    [label release];

    saturationValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(256.0f, 221.0f, 44.0f, 21.0f)];
    saturationValueLabel.text = @"255";
    saturationValueLabel.textAlignment = UITextAlignmentRight;
    saturationValueLabel.backgroundColor = [UIColor clearColor];
    [view addSubview:saturationValueLabel];

    saturationSlider = [[GradientSlider alloc] initWithFrame:CGRectMake(18.0f, 250.0f, 284.0f, 23.0f)];
    saturationSlider.slider.maximumValue = 100.0f;
    saturationSlider.value = saturation;
    [saturationSlider.slider addTarget:self action:@selector(updateColor) forControlEvents:UIControlEventValueChanged];
    [saturationSlider.slider addTarget:self action:@selector(notifyDelegate) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:saturationSlider];

    // Create a slider for brightness
    label = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 283.0f, 81.0f, 21.0f)];
    label.text = @"Brightness";
    label.backgroundColor = [UIColor clearColor];
    [view addSubview:label];
    [label release];

    brightnessValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(256.0f, 283.0f, 44.0f, 21.0f)];
    brightnessValueLabel.text = @"255";
    brightnessValueLabel.textAlignment = UITextAlignmentRight;
    brightnessValueLabel.backgroundColor = [UIColor clearColor];
    [view addSubview:brightnessValueLabel];

    brightnessSlider = [[GradientSlider alloc] initWithFrame:CGRectMake(18.0f, 312.0f, 284.0f, 23.0f)];
    brightnessSlider.slider.maximumValue = 100.0f;
    brightnessSlider.value = brightness;
    [brightnessSlider.slider addTarget:self action:@selector(updateColor) forControlEvents:UIControlEventValueChanged];
    [brightnessSlider.slider addTarget:self action:@selector(notifyDelegate) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:brightnessSlider];

    // Create a slider for alpha
    label = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 342.0f, 44.0f, 21.0f)];
    label.text = @"Alpha";
    label.backgroundColor = [UIColor clearColor];
    [view addSubview:label];
    [label release];

    alphaValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(256.0f, 342.0f, 44.0f, 21.0f)];
    alphaValueLabel.text = @"255";
    alphaValueLabel.textAlignment = UITextAlignmentRight;
    alphaValueLabel.backgroundColor = [UIColor clearColor];
    [view addSubview:alphaValueLabel];

    alphaSlider = [[GradientSlider alloc] initWithFrame:CGRectMake(18.0f, 371.0f, 284.0f, 23.0f)];
    alphaSlider.slider.maximumValue = 100.0f;
    alphaSlider.value = alpha;
    [alphaSlider.slider addTarget:self action:@selector(updateColor) forControlEvents:UIControlEventValueChanged];
    [alphaSlider.slider addTarget:self action:@selector(notifyDelegate) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:alphaSlider];

    self.view = view;
    [view release];

    // Manually call color update method to set the intial gradient/preview colors
    [self updateColor];
}

- (void)dealloc
{
    [alphaSlider release];
    [brightnessSlider release];
    [saturationSlider release];
    [hueSlider release];
    [colorView release];

    [super dealloc];
}

#pragma mark - Color actions

- (void)updateColor
{
    // Get current values
    hue = hueSlider.value;
    saturation = saturationSlider.value;
    brightness = brightnessSlider.value;
    alpha = alphaSlider.value;

    float h = hue / 360.0f;
    float s = saturation / 100.0f;
    float b = brightness / 100.0f;
    float a = alpha / 100.0f;

    // Update the color preview
    colorView.backgroundColor = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];

    // Update hue slider gradient
    hueSlider.saturation = s;
    hueSlider.brightness = b;
    hueValueLabel.text = [NSString stringWithFormat:@"%d\u00B0", hue];

    // Update saturation slider gradient
    saturationSlider.startColor = [UIColor colorWithHue:h saturation:0.0f brightness:b alpha:1.0f];
    saturationSlider.endColor = [UIColor colorWithHue:h saturation:1.0f brightness:b alpha:1.0f];
    saturationValueLabel.text = [NSString stringWithFormat:@"%d%%", saturation];

    // Update brightness slider gradient
    brightnessSlider.startColor = [UIColor colorWithHue:h saturation:s brightness:0.0f alpha:1.0f];
    brightnessSlider.endColor = [UIColor colorWithHue:h saturation:s brightness:1.0f alpha:1.0f];
    brightnessValueLabel.text = [NSString stringWithFormat:@"%d%%", brightness];

    // Update alpha slider gradient
    alphaSlider.startColor = [UIColor colorWithHue:h saturation:s brightness:b alpha:0.0f];
    alphaSlider.endColor = [UIColor colorWithHue:h saturation:s brightness:b alpha:1.0f];
    alphaValueLabel.text = [NSString stringWithFormat:@"%d%%", alpha];

    // Note that the value has changed
    valueChanged = YES;
}

- (void)notifyDelegate
{
    // NOTE: Only notify the delegate if the value has actually changed
    // NOTE: UISlider sends *two* touch up inside events; this works around that
    // FIXME: It seems that value changed gets called twice as well, so this
    //        doesn't quite solve the issue.
    if (valueChanged) {
        if ([delegate respondsToSelector:@selector(colorPickerController:didUpdateColorWithHue:saturation:brightness:alpha:)])
            [delegate colorPickerController:self didUpdateColorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
        valueChanged = NO;
    }
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
