//
//  AccountCreationViewController.m
//  VinylMap
//
//  Created by JASON HARRIS on 12/3/15.
//  Copyright © 2015 Toaster. All rights reserved.
//

#import "AccountCreationViewController.h"
#import <Masonry.h>
#import "DiscogsButton.h"

@interface AccountCreationViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UITextField *emailAddressField;
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) UITextField *confirmPassword;
@property (nonatomic, strong) UITextField *firstName;
@property (nonatomic, strong) UITextField *lastName;
@property (nonatomic, strong) UISwitch *acceptTerms;

@property (nonatomic, strong) DiscogsButton *createAccountButon;
@property (nonatomic, strong) DiscogsButton *cancelButton;
@property (nonatomic, strong) UIImageView *logoImage;

@property (nonatomic, assign) CGFloat textSize;
@property (nonatomic, assign) CGFloat itemWidth;
@property (nonatomic, assign) CGFloat separation;

@end

@implementation AccountCreationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //ORDER OF THESE ARE IMPORTANT
    self.textSize = 30;
    self.itemWidth = 0.9;
    self.separation = 0.25;
    [self setupBackground];
    [self setupLogoImage];
    [self setupTextFields];
    [self setupButtons];
    
    
}


#pragma mark - setting up the view

-(void)setupLogoImage
{
    self.logoImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"record_globe_image"]];
    [self.view addSubview:self.logoImage];
    [self.logoImage mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.top.equalTo(self.view).offset(self.textSize);
        make.height.and.width.equalTo(@(self.textSize * 3));
    }];
}


-(void)setupTextFields
{
    self.firstName = [[UITextField alloc] init];
    self.firstName.placeholder = @"first name";
    self.lastName = [[UITextField alloc] init];
    self.lastName.placeholder = @"last name";
    self.emailAddressField = [[UITextField alloc] init];
    self.emailAddressField.placeholder = @"email address";
    self.passwordField = [[UITextField alloc] init];
    self.passwordField.placeholder = @"password";
    self.passwordField.secureTextEntry = YES;
    self.confirmPassword = [[UITextField alloc] init];
    self.confirmPassword.placeholder = @"password";
    self.confirmPassword.secureTextEntry = YES;

    
    NSArray *textFieldArray = @[self.firstName , self.lastName , self.emailAddressField , self.passwordField , self.confirmPassword];
    UITextField *previousField;
    for (UITextField *textField in textFieldArray) {
        [self.view addSubview:textField];
        CGFloat grayNESS = 0.9;
        textField.backgroundColor = [[UIColor alloc] initWithRed:grayNESS green:grayNESS blue:grayNESS alpha:1];
        textField.borderStyle = UITextBorderStyleRoundedRect;
        [textField mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.equalTo(self.view).multipliedBy(self.itemWidth);
            make.height.equalTo(@(self.textSize));
            make.centerX.equalTo(self.view);
            
            if(previousField)
            {
                make.top.equalTo(previousField.mas_bottom).offset(self.textSize * self.separation);
            } else
            {
                make.top.equalTo(self.logoImage.mas_bottom).offset(self.textSize * self.separation);
            }
            
            
        }];
        
        
        previousField = textField;
    }
    
    
}

-(void)setupButtons
{
    self.createAccountButon = [[DiscogsButton alloc] init];
    [self.createAccountButon setTitle:@"Submit" forState:UIControlStateNormal];
    self.cancelButton = [[DiscogsButton alloc] init];
    [self.cancelButton setTitle:@"Cancel" forState:UIControlStateNormal];
    
    NSArray *buttonArray = @[self.createAccountButon , self.cancelButton];
    DiscogsButton *previousButton;
    
    for (DiscogsButton *aButton in buttonArray)
    {
        [self.view addSubview:aButton];
        
        [aButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.equalTo(self.view).multipliedBy(self.itemWidth);
            make.height.equalTo(@(self.textSize));
            make.centerX.equalTo(self.view);
            
            if(previousButton)
            {
                make.top.equalTo(previousButton.mas_bottom).offset(self.textSize * self.separation);
            } else
            {
                make.top.equalTo(self.confirmPassword.mas_bottom).offset(self.textSize * self.separation);
            }
        }];
        
        [aButton addTarget:self action:@selector(buttonWasPressed:) forControlEvents:UIControlEventTouchUpInside];
        
        previousButton = aButton;
    }
    
}


-(void)setupBackground
{
    UIView *behindVisualEffect = [[UIView alloc] init];
    //    behindVisualEffect.alpha = 0.9;
    behindVisualEffect.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:behindVisualEffect];
    [behindVisualEffect mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(behindVisualEffect.superview);
    }];
    
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    UIVisualEffectView *backgroundView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    backgroundView.accessibilityLabel = @"backGround";
    [behindVisualEffect addSubview:backgroundView];
    
    [backgroundView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
}

#pragma mark - button was pressed

-(void)buttonWasPressed:(DiscogsButton *)sender
{
    if ([sender isEqual:self.createAccountButon])
    {
        NSMutableArray *responseArray = [self checkIfInfoIsCorrect];
        if([responseArray[0] isEqual:@(1)])
        {
            
        } else
        {
            [responseArray removeObjectAtIndex:0];
            NSString *responseString = [responseArray componentsJoinedByString:@"\n"];
            NSLog(@"%@",responseString);
            [self displayeAlertForBadEntry:responseString];
            
        }
        
    } else if ([sender isEqual:self.cancelButton])
    {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}


#pragma mark - dealing with contents

-(NSMutableArray *)checkIfInfoIsCorrect
{
    bool emailOkay = [self validateEmail:self.emailAddressField.text];
    bool passwordsEqual = [self.passwordField.text isEqualToString:self.confirmPassword.text];
    bool passwordOkay = 0;
    
    if(passwordsEqual)
    {
        passwordOkay = self.passwordField.text.length > 5;
    }
    
    bool isFirstName = ![self.firstName.text isEqualToString:@""];
    bool isLastName = ![self.lastName.text isEqualToString:@""];
    
    
    NSLog(@"email: %u , password: %u, firstname: %u, lastname: %u \n all: %u",emailOkay,passwordOkay,isFirstName,isLastName,emailOkay && passwordOkay && isFirstName && isLastName);
    
    NSMutableArray *responseArray = [[NSMutableArray alloc] init];
    
    [responseArray addObject:@(emailOkay && passwordOkay && isFirstName && isLastName)];
    
    if (!isFirstName)
    {
        [responseArray addObject:@"Enter your first name"];
    }
    if (!isLastName)
    {
        [responseArray addObject:@"Enter your last name"];
    }
    if (!emailOkay)
    {
        [responseArray addObject:@"Enter a valid email"];
    }
    if (!passwordsEqual)
    {
        [responseArray addObject:@"Passwords do not match"];
    }
    if (self.passwordField.text.length <= 5)
    {
        [responseArray addObject:@"Password must be 6 characters or more"];
    }
    
    
    return responseArray;
}

-(void)displayeAlertForBadEntry:(NSString *) response
{
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:@"Please fix errors"
                                          message: response
                                          preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction
                               actionWithTitle:NSLocalizedString(@"Cancel", @"OK action")
                               style:UIAlertActionStyleDestructive
                               handler:^(UIAlertAction *action)
                               {
                                   
                               }];
    
    [alertController addAction:okAction];
    [self presentViewController:alertController animated:YES completion:nil];
}


- (BOOL) validateEmail: (NSString *)candidate {
    NSString *emailRegex =
    @"(?:[a-z0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[a-z0-9!#$%\\&'*+/=?\\^_`{|}"
    @"~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\"
    @"x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-"
    @"z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5"
    @"]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-"
    @"9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21"
    @"-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])";
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES[c] %@", emailRegex];
    
    return [emailTest evaluateWithObject:candidate];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
    
    
}


-(void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    
    NSLog(@"user touched this object: %@",touches.anyObject.view.accessibilityLabel);
    
    if([touches.anyObject.view.accessibilityLabel isEqualToString:@"backGround"])
    {
        //        [self dismissViewControllerAnimated:YES completion:nil];
    }
    
}

@end
