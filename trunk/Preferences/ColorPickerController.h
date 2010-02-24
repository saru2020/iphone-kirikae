/**
 * Name: Kirikae
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: a task manager/switcher for iPhoneOS
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-02-24 00:55:29
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


@class SpectrumSlider;
@class GradientSlider;

@protocol ColorPickerControllerDelegate;

@interface ColorPickerController : UIViewController
{
    id<ColorPickerControllerDelegate> delegate;

    unsigned short hue;        // 0 - 360
    unsigned char saturation;  // 0 - 100
    unsigned char brightness;  // 0 - 100
    unsigned char alpha;       // 0 - 100

    UIView *colorView;

    SpectrumSlider *hueSlider;
    GradientSlider *saturationSlider;
    GradientSlider *brightnessSlider;
    GradientSlider *alphaSlider;

    UILabel *hueValueLabel;
    UILabel *saturationValueLabel;
    UILabel *brightnessValueLabel;
    UILabel *alphaValueLabel;

    BOOL valueChanged;
}

@property(nonatomic, assign) id<ColorPickerControllerDelegate> delegate;

- (id)initWithHue:(unsigned short)h saturation:(unsigned char)s brightness:(unsigned char)b alpha:(unsigned char)a;

@end

@protocol ColorPickerControllerDelegate <NSObject>
- (void)colorPickerController:(ColorPickerController *)controller didUpdateColorWithHue:(unsigned short)hue
    saturation:(unsigned char)saturation brightness:(unsigned char)brightness alpha:(unsigned char)alpha;
@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
