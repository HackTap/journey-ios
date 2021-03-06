//
//  JCTextField.h
//  JourneyCapture
//
//  Created by Chris Sloey on 12/03/2014.
//  Copyright (c) 2014 FCD. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface JCTextField : UITextField
@property (readwrite, nonatomic) BOOL _pasteDisabled;
@property (readwrite, nonatomic) BOOL valid;
@property (readwrite, nonatomic) BOOL error;
@property (strong, nonatomic) UIView *invalidView;

@property (strong, nonatomic) UIColor *correctBorderColor;
@property (readwrite, nonatomic) float correctBorderWidth;
@property (readwrite, nonatomic) float correctCornerRadius;
@property (strong, nonatomic) UIColor *errorBorderColor;

@property (readwrite, nonatomic) BOOL pasteDisabled;

-(void)showError;
-(void)hideError;

-(void)showInvalid;
-(void)hideInvalid;

@end
