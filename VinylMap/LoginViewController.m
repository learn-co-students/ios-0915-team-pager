//
//  LoginViewController.m
//  VinylMap
//
//  Created by JASON HARRIS on 11/19/15.
//  Copyright © 2015 Toaster. All rights reserved.
//

#import "LoginViewController.h"
#import <Masonry.h>
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>
#import <FBSDKApplicationDelegate.h>
#import "UserObject.h"
#import <Google/Core.h>
#import <Google/SignIn.h>
#import <Firebase/Firebase.h>
#import <FirebaseUI/FirebaseLoginViewController.h>
#import "VinylConstants.h"
#import <AFOAuth2Manager.h>
#import <AFNetworking.h>
#import <KDURLRequestSerialization+OAuth.h>
#import "DiscogsOAuthRequestSerializer.h"
#import "AccountCreationViewController.h"
#import "DiscogsButton.h"
#import <SSKeychain.h>
#import <SSKeychainQuery.h>
#import "DiscogsAPI.h"
#import "MyAlbumsViewController.h"
#import "VinylColors.h"


@interface LoginViewController () <FBSDKLoginButtonDelegate, AccountCreationViewControllerDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) FBSDKLoginButton *facebookLoginButton;
@property (nonatomic, strong) DiscogsButton *dismissViewControllerButton;
@property (nonatomic, strong) DiscogsButton *firebaseLoginButton;
@property (nonatomic, strong) DiscogsButton *firebaseLogoutButton;
@property (nonatomic, strong) DiscogsButton *discogsLoginButton;
@property (nonatomic, strong) DiscogsButton *createFirebaseAccount;
@property (nonatomic, strong) DiscogsButton *syncToDiscogs;

@property (nonatomic, strong) NSMutableArray *arrayOfButtons;

@property (nonatomic, assign) CGFloat offsetAmount;
@property (nonatomic, assign) CGFloat widthMultiplier;

@property (nonatomic, strong) UIImageView *logoImage;


@property (nonatomic, strong) UITextField *emailAddressField;
@property (nonatomic, strong) UITextField *passwordField;

@property (nonatomic, strong) UILabel *loggedInLabel;


@property (nonatomic, strong) AFHTTPSessionManager *manager;
@property (nonatomic, strong) AccountCreationViewController *createAccountVC;


@end



@implementation LoginViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setupLogoImage];
    self.offsetAmount = 15;
    self.widthMultiplier = 0.9;
    self.view.backgroundColor = [UIColor vinylMediumGray];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(viewDidAppear:)
                                                 name:DISCOGS_LOGIN_NOTIFICATION object:nil];
    if (self.modalOne) {
        [self setUpTextFields];
        self.view.userInteractionEnabled = YES;
        UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(screenTapped:)];
        tapRecognizer.delegate = self;
        tapRecognizer.numberOfTapsRequired = 1;
        tapRecognizer.numberOfTouchesRequired = 1;
        [self.view addGestureRecognizer:tapRecognizer];
        UIImage *background = [UIImage imageNamed:@"records.jpg"];
        UIImageView *backgroundImageView = [[UIImageView alloc] initWithImage:background];
        backgroundImageView.alpha = 0.5;
        [self.view insertSubview:backgroundImageView atIndex:0];
        
        [backgroundImageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.height.and.width.equalTo(self.view).offset(100);
            make.left.equalTo(self.view).offset(-50);
            make.top.equalTo(self.view).offset(-50);
        }];
        
        
        UIInterpolatingMotionEffect *verticalMotionEffect = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
        verticalMotionEffect.minimumRelativeValue = @(-50);
        verticalMotionEffect.maximumRelativeValue = @(50);
        UIInterpolatingMotionEffect *horizontalMotionEffect = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
        horizontalMotionEffect.minimumRelativeValue = @(-50);
        horizontalMotionEffect.maximumRelativeValue = @(50);
        UIMotionEffectGroup *group = [UIMotionEffectGroup new];
        group.motionEffects = @[horizontalMotionEffect, verticalMotionEffect];
        [backgroundImageView addMotionEffect:group];
        
        self.view.backgroundColor = [UIColor vinylMediumGray];
    }
    else {
        [self setUpLoggedInMessage];
    }
    self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName:[UIColor whiteColor]};

}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self stopCallingViewDidAppear];
}

-(void)stopCallingViewDidAppear
{
    [self setUpButtons];
    [self discogsLoginButtonAlive];
    self.loggedInLabel.text = [NSString stringWithFormat:@"Logged in as %@", [UserObject sharedUser].firebaseRoot.authData.providerData[@"email"]];
    if(![UserObject sharedUser].firebaseRoot.authData && !self.modalOne)
    {
        [self showLoginScreen];
    }
    
}

- (IBAction)screenTapped:(UITapGestureRecognizer *)sender {
    NSLog(@"tap");
    [self.view endEditing:YES];
}



#pragma mark - text field handling/delegates

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if([textField isEqual:self.emailAddressField])
    {
        [self.passwordField becomeFirstResponder];
    } else if ([textField isEqual:self.passwordField])
    {
        if(self.firebaseLoginButton.isUserInteractionEnabled)
        {
            [self firebaseLoginClicked];
        } else
        {
            [self resignFirstResponder];
        }
    }
    
    return YES;
    
}

#pragma mark - set up buttons

-(void)setUpButtons
{
    for (id buttonObject in self.arrayOfButtons) {
        [buttonObject removeFromSuperview];
    }
    self.arrayOfButtons = [@[] mutableCopy];
    
    
    if([UserObject sharedUser].firebaseRoot.authData)  //USER IS ALREADY LOGGED IN
    {
        if([FBSDKAccessToken currentAccessToken])
        {
            self.facebookLoginButton = [[FBSDKLoginButton alloc] init];
            self.facebookLoginButton.accessibilityIdentifier = @"facebookLogin";
            [self.view addSubview:self.facebookLoginButton];
            self.facebookLoginButton.readPermissions = @[@"public_profile", @"email", @"user_friends"];
            self.facebookLoginButton.delegate = self;
            [self.arrayOfButtons addObject:self.facebookLoginButton];
        } else
        {
            self.firebaseLogoutButton = [[DiscogsButton alloc] init];
            [self.firebaseLogoutButton setTitle:@"Logout" forState:UIControlStateNormal];
            [self.view addSubview:self.firebaseLogoutButton];
            [self.arrayOfButtons addObject:self.firebaseLogoutButton];
        }
        
        self.discogsLoginButton = [[DiscogsButton alloc] init];
        [self.discogsLoginButton setTitle:@"Link Discogs account" forState:UIControlStateNormal];
        [self.view addSubview:self.discogsLoginButton];
        [self.arrayOfButtons addObject:self.discogsLoginButton];
        [self dismissViewControllerAnimated:YES completion:nil];
        
    } else  //USER IS NOT LOGGED IN
    {
        self.firebaseLoginButton = [[DiscogsButton alloc] init];
        [self.firebaseLoginButton setTitle:@"Login" forState:UIControlStateNormal];
        [self.view addSubview:self.firebaseLoginButton];
        [self.arrayOfButtons addObject:self.firebaseLoginButton];
        
        self.createFirebaseAccount = [[DiscogsButton alloc] init];
        [self.createFirebaseAccount setTitle:@"Create new account" forState:UIControlStateNormal];
        [self.view addSubview:self.createFirebaseAccount];
        [self.arrayOfButtons addObject:self.createFirebaseAccount];
        
        self.facebookLoginButton = [[FBSDKLoginButton alloc] init];
        self.facebookLoginButton.accessibilityIdentifier = @"facebookLogin";
        [self.view addSubview:self.facebookLoginButton];
        self.facebookLoginButton.readPermissions = @[@"public_profile", @"email", @"user_friends"];
        self.facebookLoginButton.delegate = self;
        [self.arrayOfButtons addObject:self.facebookLoginButton];
        
    }
    

    

    DiscogsButton *previousButton;
    
    for (DiscogsButton *button in self.arrayOfButtons) {
        [button addTarget:self
                   action:@selector(buttonClicked:)
         forControlEvents:UIControlEventTouchUpInside];
        
        if(previousButton)
        {
            [button mas_makeConstraints:^(MASConstraintMaker *make) {
                make.height.equalTo(@35);
                make.width.equalTo(self.view).multipliedBy(self.widthMultiplier);
                make.centerX.equalTo(self.view);
                make.top.equalTo(previousButton.mas_bottom).offset(self.offsetAmount);
            }];

        } else
        {
            if(self.modalOne)
            {
                [button mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.height.equalTo(@35);
                    make.width.equalTo(self.view).multipliedBy(self.widthMultiplier);
                    make.centerX.equalTo(self.view);
                    make.top.equalTo(self.passwordField.mas_bottom).offset(self.offsetAmount);
                }];
            } else
            {
                [button mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.height.equalTo(@35);
                    make.width.equalTo(self.view).multipliedBy(self.widthMultiplier);
                    make.centerX.equalTo(self.view);
                    make.top.equalTo(self.loggedInLabel.mas_bottom).offset(self.offsetAmount);
                }];
   
            }
        }
        
        previousButton = button;
    }
    
}

-(void)setUpLoggedInMessage {
    self.loggedInLabel = [UILabel new];
    NSString *loggedInMessage = [NSString stringWithFormat:@"Logged in as %@", [UserObject sharedUser].firebaseRoot.authData.providerData[@"email"]];
    self.loggedInLabel.text = loggedInMessage;
    self.loggedInLabel.textColor = [UIColor vinylDarkGray];
    [self.view addSubview:self.loggedInLabel];
    [self.loggedInLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.top.equalTo(self.logoImage.mas_bottom).offset(self.offsetAmount);
    }];
}


-(void)setUpTextFields
{
    self.emailAddressField = [[UITextField alloc] init];
    self.emailAddressField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.emailAddressField.placeholder = @"email address";
    self.emailAddressField.keyboardType = UIKeyboardTypeEmailAddress;
    self.emailAddressField.delegate = self;
    [self.view addSubview:self.emailAddressField];
    
    self.passwordField = [[UITextField alloc] init];
    self.passwordField.placeholder = @"password";
    self.passwordField.secureTextEntry = YES;
    self.passwordField.delegate = self;
    [self.view addSubview:self.passwordField];
    
    
    for (UITextField *textField in @[self.passwordField, self.emailAddressField]) {
        CGFloat grayNESS = 0.9;
        textField.backgroundColor = [UIColor vinylLightGray];
        textField.borderStyle = UITextBorderStyleRoundedRect;
        
        [textField mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerX.equalTo(self.view);
            make.width.equalTo(self.view).multipliedBy(self.widthMultiplier);
        }];
        
    }
    
    
    [self.emailAddressField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.logoImage.mas_bottom).offset(self.offsetAmount);
    }];
    
    [self.passwordField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.emailAddressField.mas_bottom).offset(self.offsetAmount);
    }];

}

#pragma mark - discogs buttons

-(void)discogsLoginButtonAlive
{
    if([UserObject sharedUser].firebaseRoot.authData)
    {
        if([UserObject sharedUser].discogsTokenSecret)
        {
            self.discogsLoginButton.userInteractionEnabled = NO;
            self.discogsLoginButton.enabled = NO;
            [self.discogsLoginButton setTitle:@"Discogs linked" forState:UIControlStateNormal];
            [self createDiscogsSyncButton];
            
        } else
        {
            self.discogsLoginButton.userInteractionEnabled = YES;
            self.discogsLoginButton.enabled = YES;
            [self.discogsLoginButton setTitle:@"Link Discogs account" forState:UIControlStateNormal];
        }
        
    } else
    {
        self.discogsLoginButton.userInteractionEnabled = NO;
        self.discogsLoginButton.enabled = NO;
        [self.discogsLoginButton setTitle:@"Must login to link Discogs" forState:UIControlStateNormal];
    }
    if ([UserObject sharedUser].firebaseRoot.authData && self.modalOne) {
        [self dismissViewControllerAnimated:YES completion:^{
            [UserObject sharedUser].loggedInOnce = YES;
        }];
    }
}

-(void)createDiscogsSyncButton
{
    self.syncToDiscogs = [[DiscogsButton alloc] init];
    [self.syncToDiscogs setTitle:@"Sync Discogs" forState:UIControlStateNormal];
    [self.view addSubview:self.syncToDiscogs];
    [self.arrayOfButtons addObject:self.syncToDiscogs];
    
    [self.syncToDiscogs mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(@35);
        make.width.equalTo(self.view).multipliedBy(self.widthMultiplier);
        make.centerX.equalTo(self.view);
        make.top.equalTo(self.discogsLoginButton.mas_bottom).offset(self.offsetAmount);
    }];
    [self.syncToDiscogs addTarget:self
                           action:@selector(buttonClicked:)
                 forControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - discogs login

-(void)discogsLoginButtonPressed
{
    NSString *stringURL = @"https://api.discogs.com/oauth/request_token";
    NSString *timeInterval = [NSString stringWithFormat:@"%ld", [@([[NSDate date] timeIntervalSince1970]) integerValue]];
    NSDictionary *params = @{@"oauth_consumer_key" : DISCOGS_CONSUMER_KEY,
                             @"oauth_signature" : [NSString stringWithFormat:@"%@&",DISCOGS_CONSUMER_SECRET],
                             @"oauth_signature_method":@"PLAINTEXT",
                             @"oauth_timestamp" : timeInterval,
                             @"oauth_nonce" : @"jThVrMF",
                             @"User-Agent" : @"uniqueVinylMaps",
                             @"oauth_version" : @"1.0",
                             @"oauth_callback" : @"vinyl-discogs-beeper://"
                             };
    
    self.manager = [AFHTTPSessionManager manager];
    
    
    DiscogsOAuthRequestSerializer *reqSerializer = [DiscogsOAuthRequestSerializer serializer];
    self.manager.requestSerializer = reqSerializer;
    self.manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    self.manager.responseSerializer.acceptableContentTypes = [self.manager.responseSerializer.acceptableContentTypes setByAddingObject:@"text/html"];
    [self.manager GET:stringURL parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        NSString *responseString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        responseString = [NSString stringWithFormat:@"%@?%@",stringURL,responseString]; //ADDED ORIGINAL URL TO USE QUEURY ITEMS
        NSURL *responseURL = [NSURL URLWithString:responseString]; // CHANGED TO NSURL
        NSURLComponents *urlComps = [NSURLComponents componentsWithURL:responseURL resolvingAgainstBaseURL:nil];
        NSArray *urlParts = urlComps.queryItems;
        for (NSURLQueryItem *queryItem in urlParts) {
            if([queryItem.name isEqualToString:@"oauth_token_secret"])
            {
                [UserObject sharedUser].prelimDiscogsTokenSecret = queryItem.value;
                //                NSLog(@"OAuth Prelim Secret %@",queryItem.value);
            } else if ([queryItem.name isEqualToString:@"oauth_token"])
            {
                [UserObject sharedUser].prelimDiscogsRequestToken = queryItem.value;
                
                //                NSLog(@"OAuth Prelim Token %@",queryItem.value);
            }
        }
        NSString *authorizeStringURL = [NSString stringWithFormat:@"https://discogs.com/oauth/authorize?oauth_token=%@",[UserObject sharedUser].prelimDiscogsRequestToken];
        NSURL *authorizeURL = [NSURL URLWithString:authorizeStringURL];
        [[UIApplication sharedApplication] openURL:authorizeURL];
        [self stopCallingViewDidAppear];
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSLog(@"%@", error);
    }];
    
}


#pragma mark - buttons clicked delegate

-(void)buttonClicked:(DiscogsButton *)sendingButton
{
    
    if([sendingButton isEqual:self.dismissViewControllerButton])
    {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else if ([sendingButton isEqual:self.firebaseLoginButton])
    {
        [self firebaseLoginClicked];
        
    } else if ([sendingButton isEqual:self.firebaseLogoutButton])
    {
        [self logoutOfFirebase];
    } else if ([sendingButton isEqual:self.discogsLoginButton])
    {
        [self discogsLoginButtonPressed];
        
    } else if ([sendingButton isEqual:self.createFirebaseAccount])
    {
        [self createFirebaseAccountNow];
        
    } else if ([sendingButton isEqual:self.syncToDiscogs])
    {
        self.syncToDiscogs.userInteractionEnabled = NO;
        self.syncToDiscogs.enabled = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.syncToDiscogs.userInteractionEnabled = YES;
        self.syncToDiscogs.enabled = YES;
        });
        
        [DiscogsAPI syncDiscogsAlbums];
    }
    
}

#pragma mark - create account

-(void)createFirebaseAccountNow
{
    self.createAccountVC = [[AccountCreationViewController alloc] init];
    self.createAccountVC.delegate = self;
    [self.createAccountVC setModalPresentationStyle:UIModalPresentationOverFullScreen];
    [self presentViewController:self.createAccountVC animated:NO completion:nil];
    
}




#pragma mark - facebook

-(void)loginButton:(FBSDKLoginButton *)loginButton didCompleteWithResult:(FBSDKLoginManagerLoginResult *)result error:(NSError *)error

{
    
    NSLog(@"did complete with error %@",error);
    
    if(error)
    {
        
    } else
    {
        NSSet *grantedPermissions = result.token.permissions;
        NSSet *declinedPermissions = result.token.declinedPermissions;
        NSString *userID = result.token.userID;
        NSString *tokenString = result.token.tokenString;
        NSLog(@"userID: %@ \n token: %@ \n permissions: %@ \n declined permissions: %@ \n",userID,tokenString,grantedPermissions,declinedPermissions);
        [UserObject sharedUser].facebookUserID = [FBSDKAccessToken currentAccessToken].userID;
        [UserObject sharedUser].facebookToken = result.token.tokenString;
        
        [[UserObject sharedUser].firebaseRoot authWithOAuthProvider:@"facebook" token:result.token.tokenString withCompletionBlock:^(NSError *error, FAuthData *authData) {
            if(error)
            {
                NSLog(@"%@",error);
                [self stopCallingViewDidAppear];
            } else
            {
                NSLog(@"Facebook Login Complete"); //AUTHDATA COMPLETE
                NSDictionary *userProfile = authData.providerData[@"cachedUserProfile"];
                NSMutableDictionary *facebookUser = [@{
                                                       @"provider": authData.provider,
                                                       @"email" : authData.providerData[@"email"],
                                                       @"displayName" : authData.providerData[@"displayName"],
                                                       @"firstName" : userProfile[@"first_name"],
                                                       @"lastName" : userProfile[@"last_name"],
                                                       @"profileImageURL": authData.providerData[@"profileImageURL"]
                                                       } mutableCopy];
                
                // Create a child path with a key set to the uid underneath the "users" node
                [[[[UserObject sharedUser].firebaseRoot childByAppendingPath:@"users"]
                  childByAppendingPath:authData.uid] setValue:facebookUser];
                [self stopCallingViewDidAppear];
            }
        }];
        
    }
    
    
}


-(void)loginButtonDidLogOut:(FBSDKLoginButton *)loginButton
{
    [self logoutActions];
}

- (BOOL)loginButtonWillLogin:(FBSDKLoginButton *)loginButton
{
    
    return YES;
}

#pragma mark - firebase


-(void)firebaseLoginClicked
{
    
    [self loginToFirebase:self.emailAddressField.text password:self.passwordField.text withCompletion:^(bool loginResult)
    {
        
    }];
}

-(void)loginToFirebase:(NSString *)username password:(NSString *)password withCompletion:(void (^)(bool loginResult))completionBlock
{
    self.firebaseLoginButton.userInteractionEnabled = NO;
    self.createFirebaseAccount.userInteractionEnabled = NO;
    self.facebookLoginButton.userInteractionEnabled = NO;
    
    [[UserObject sharedUser].firebaseRoot authUser:username password:password withCompletionBlock:^(NSError *error, FAuthData *authData) {
        if (error) {
            NSLog(@"error %@",error);
            NSString *errorString = error.localizedDescription;
            NSRange range = [errorString rangeOfString:@") "];
            [self displayErrorAlert:[errorString substringFromIndex:range.length + range.location] title:@"Error"];
            completionBlock(NO);
        } else {
            // user is logged in, check authData for data
            [FBSDKAccessToken setCurrentAccessToken:nil];
            [self stopCallingViewDidAppear];
            completionBlock(YES);
        }
        self.firebaseLoginButton.userInteractionEnabled = YES;
        self.createFirebaseAccount.userInteractionEnabled = YES;
        self.facebookLoginButton.userInteractionEnabled = YES;
    }];
    
}


-(void)logoutOfFirebase
{
    [self logoutActions];
}


- (void)showLoginScreen
{
    // Get login screen from storyboard and present it
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    LoginViewController *viewController = (LoginViewController *)[storyboard instantiateViewControllerWithIdentifier:@"InitialLoginVC"];
    viewController.modalOne = YES;
    [self presentViewController:viewController animated:NO completion:nil];
}

#pragma mark - account creation

-(void)createAccountResult:(NSDictionary *)someResult
{
    
    __block NSDictionary *result = [someResult mutableCopy];
    
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    spinner.center = CGPointMake(self.view.frame.size.width/2, self.view.frame.size.height*3/4);
    spinner.tag = 12;
    spinner.color = [UIColor blackColor];
    spinner.userInteractionEnabled = NO;
    [self.view addSubview:spinner];
    [spinner startAnimating];
    NSString *pathString = [NSString stringWithFormat:@"users/%@",result[@"provider"]];
    [self loginToFirebase:result[@"email"] password:result[@"password"] withCompletion:^(bool loginResult) {
        if(loginResult)
        {
            NSMutableDictionary *noPasswordDict = [result mutableCopy];
            [noPasswordDict removeObjectForKey:@"password"];
            
            
        [[[UserObject sharedUser].firebaseRoot childByAppendingPath:pathString] setValue:noPasswordDict withCompletionBlock:^(NSError *error, Firebase *ref) {
            if(error)
            {
                NSLog(@"error returned %@",error);
            } else
            {
                NSLog(@"wrote to /users/%@ \n%@",result[@"provider"],result);
            }
        }];
            
        }
        [spinner removeFromSuperview];
    }];
}


#pragma mark - display alert

-(void)displayErrorAlert:(NSString *)body
                   title:(NSString *)title
{
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:title
                                          message: body
                                          preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction
                               actionWithTitle:@"OK"
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *action)
                               {
                                   
                               }];
    
    [alertController addAction:okAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
}

#pragma mark - logout
-(void)logoutActions
{
    [[UserObject sharedUser].firebaseRoot unauth];
    [FBSDKAccessToken setCurrentAccessToken:nil];
    [DiscogsAPI removeDiscogsKeychain];
    [AlbumCollectionDataStore sharedDataStore].albums = [@[] mutableCopy];
    [self stopCallingViewDidAppear];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"userLogOut" object:nil];
}


#pragma mark - logo image

-(void)setupLogoImage
{
    self.logoImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"vinylMap_icon.png"]];
    [self.view addSubview:self.logoImage];
    [self.logoImage mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.top.equalTo(self.mas_topLayoutGuideBottom).offset(self.view.frame.size.height/20);
        make.height.and.width.equalTo(@(self.view.frame.size.width/1.5));
    }];
}


@end
