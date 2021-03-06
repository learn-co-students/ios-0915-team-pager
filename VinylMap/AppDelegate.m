//
//  AppDelegate.m
//  VinylMap
//
//  Created by Haaris Muneer on 11/18/15.
//  Copyright © 2015 Toaster. All rights reserved.
//

#import "AppDelegate.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>
#import <Google/Core.h>
#import <Google/SignIn.h>
#import "UserObject.h"
#import "VinylConstants.h"
#import <FirebaseUI/FirebaseAppDelegate.h>
#import <AFNetworking.h>
#import <KDURLRequestSerialization+OAuth.h>
#import "DiscogsOAuthRequestSerializer.h"
#import <AFOAuth2Manager.h>
#import <SSKeychain.h>
#import <SSKeychainQuery.h>
#import "DiscogsAPI.h"
#import "AlbumCollectionDataStore.h"
#import "LoginViewController.h"
#import "VinylColors.h"
#import "MyAlbumsViewController.h"
#import "AlbumDetailsViewController.h"
#import "SearchViewController.h"
#import "BarcodeViewController.h"
#import "ChatMessagesViewController.h"


@interface AppDelegate  () <GIDSignInDelegate, UITabBarControllerDelegate>
@property (nonatomic, strong) AFHTTPSessionManager *manager;


@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [Firebase defaultConfig].persistenceEnabled = YES;
    // Override point for customization after application launch.
    [UserObject sharedUser];
    [[FBSDKApplicationDelegate sharedInstance] application:application didFinishLaunchingWithOptions:launchOptions]; // THIS WAKES UP THE FACEBOOK DELEGATES
    [UserObject sharedUser].facebookUserID = [FBSDKAccessToken currentAccessToken].userID;
    [self setUpFirebase];
    [DiscogsAPI pullDiscogsTokenSecret];
    [AlbumCollectionDataStore sharedDataStore];
    NSLog(@"%@",[UserObject sharedUser].firebaseRoot.authData);
    [self setUpTabBars];
    [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert categories:[NSSet setWithObject:@"GLOBAL"]]];
    [UserObject sharedUser].lastMessageTime = [NSDecimalNumber decimalNumberWithString:@"10"];
    
    
    [self setUpNotifications];
    return YES;
}


-(void)setUpFirebase
{
    [UserObject sharedUser].firebaseRoot = [[Firebase alloc] initWithUrl:FIREBASE_URL];
    [UserObject sharedUser].firebaseTestFolder = [[Firebase alloc] initWithUrl:[NSString stringWithFormat:@"%@testing/",FIREBASE_URL]];
    [[UserObject sharedUser].firebaseTestFolder observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        NSLog(@"TEST: %@ -> %@", snapshot.key, snapshot.value); //LOGS CHANGES IN TEST FOLDER
    }];
    
    
    //LISTEN FOR FIREBASE AUTH
    [[UserObject sharedUser].firebaseRoot observeAuthEventWithBlock:^(FAuthData *authData) {
        if(authData)
        {
            NSLog(@"%@",[UserObject sharedUser].firebaseRoot.authData); //AUTHDATA COMPLETE
            
        } else{
            __block NSString *errorMessage = @"User just logged out";
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                errorMessage = @"App start = user not logged in";
            });
            NSLog(@"%@",errorMessage);
        }
    }];
    
    
}



-(void)setUpGoogle
{
    NSError* configureError;
    [[GGLContext sharedInstance] configureWithError: &configureError];
    [GIDSignIn sharedInstance].delegate = self;
    NSAssert(!configureError, @"Error configuring Google services: %@", configureError);
    
}


-(void)signIn:(GIDSignIn *)signIn didSignInForUser:(GIDGoogleUser *)user withError:(NSError *)error
{
    //GOOGLE'S APP DELEGATE FOR SIGN IN
    
}

#pragma mark - message notificadtions

-(void)setUpNotifications{
    NSString *chatroomsOfSelf = [NSString stringWithFormat:@"https://amber-torch-8635.firebaseio.com/users/%@/chatrooms", [UserObject sharedUser].firebaseRoot.authData.uid];
    
    Firebase *userChatrooms = [[Firebase alloc] initWithUrl:chatroomsOfSelf];
    [userChatrooms observeEventType:FEventTypeChildChanged withBlock:^(FDataSnapshot *snapshot) {

        
        NSNumber *stringNumber = snapshot.value[@"time"];
        NSDecimalNumber *timeValue = [NSDecimalNumber decimalNumberWithString:stringNumber.stringValue];
//        NSLog(@"initial timeVal %@",timeValue);
        NSDecimalNumber *result = [timeValue decimalNumberBySubtracting:[UserObject sharedUser].lastMessageTime ];
        NSLog(@"diff from last %@",result);
        
        [UserObject sharedUser].lastMessageTime = timeValue;
        if(result.integerValue > 110)
        {
            [UserObject sharedUser].unreadMessages ++;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReceived" object:snapshot];
        }
        
//        if ([[UIApplication sharedApplication] currentUserNotificationSettings].types & UIUserNotificationTypeAlert) {
//            UILocalNotification *localNotification = [[UILocalNotification alloc] init];
//            localNotification.alertTitle = snapshot.value[@"display"];
//            localNotification.alertBody = snapshot.value[@"newest"];
//            localNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow:5];
//            localNotification.category = @"GLOBAL"; // Lazy categorization
//
//            [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
//        }
    }];
    
}


#pragma mark - opening URIs

-(BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options
{
    //MAKE THIS CONDITIONAL FOR FACEBOOK
    NSString *stringFromURL = [url absoluteString];
    if ([stringFromURL rangeOfString:FACEBOOK_KEY].location != NSNotFound) // facebook
    {
        [[FBSDKApplicationDelegate sharedInstance] application:app
                                                       openURL:url
                                             sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]
                                                    annotation:options[UIApplicationOpenURLOptionsAnnotationKey]];
    } else if ([stringFromURL rangeOfString:@"vinyl-discogs-beeper"].location != NSNotFound)
    {
        [UserObject sharedUser].discogsOAuthVerifier = [self firstValueForQueryItemNamed:@"oauth_verifier" inURL:url];
        NSLog(@"oauth verifier: %@",[UserObject sharedUser].discogsOAuthVerifier);
        [self handleDiscogsOAuthResponse];
    }
    
    
    return YES;
}


-(NSString *)firstValueForQueryItemNamed:(NSString *)name inURL:(NSURL *)url
{
    NSURLComponents *urlComps = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:nil];
    NSArray *queryItems = urlComps.queryItems;
    
    for(NSURLQueryItem *queryItem in queryItems) {
        if([queryItem.name isEqualToString:name]) {
            return queryItem.value;
        }
    }
    
    return nil;
}

-(void)handleDiscogsOAuthResponse
{
    
    NSString *stringURL = @"https://api.discogs.com/oauth/access_token";
    
    self.manager = [AFHTTPSessionManager manager];
    
    DiscogsOAuthRequestSerializer *reqSerializer = [DiscogsOAuthRequestSerializer serializer]; //PARAMETERS ARE IN REQUEST SERIALIZER
    self.manager.requestSerializer = reqSerializer;
    self.manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    self.manager.responseSerializer.acceptableContentTypes = [self.manager.responseSerializer.acceptableContentTypes setByAddingObject:@"text/html"];
    [self.manager POST:stringURL parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        NSString *responseString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        NSLog(@"%@", responseString);
        responseString = [NSString stringWithFormat:@"%@?%@",stringURL,responseString]; //ADDED ORIGINAL URL TO USE QUEURY ITEMS
        NSURL *responseURL = [NSURL URLWithString:responseString]; // CHANGED TO NSURL
        NSURLComponents *urlComps = [NSURLComponents componentsWithURL:responseURL resolvingAgainstBaseURL:nil];
        NSArray *urlParts = urlComps.queryItems;
        
        for (NSURLQueryItem *queryItem in urlParts) {
            if([queryItem.name isEqualToString:@"oauth_token_secret"])
            {
                [UserObject sharedUser].discogsTokenSecret = queryItem.value;
                [UserObject sharedUser].prelimDiscogsTokenSecret = queryItem.value;
                NSLog(@"OAuth Final Secret %@",queryItem.value);
            } else if ([queryItem.name isEqualToString:@"oauth_token"])
            {
                [UserObject sharedUser].discogsRequestToken = queryItem.value;
                [UserObject sharedUser].prelimDiscogsRequestToken = queryItem.value;
                NSLog(@"OAuth Final Token %@",queryItem.value);
            }
        }
        //STORE IN KEYCHAIN
        NSError *error;
        [SSKeychain setPassword:[UserObject sharedUser].discogsTokenSecret
                     forService:DISCOGS_KEYCHAIN
                        account:[UserObject sharedUser].discogsRequestToken error:&error];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:DISCOGS_LOGIN_NOTIFICATION object:nil];
        
        if(error)
        {
            NSLog(@"%@",error);
        }
        
        self.manager.responseSerializer = [AFHTTPSessionManager manager].responseSerializer;
        [self.manager GET:@"https://api.discogs.com/oauth/identity" parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
            NSLog(@"%@",responseObject);
            
            [DiscogsAPI populateUserObjectWithStrings:responseObject];
            
            
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSLog(@"get identity error: %@",error);
        }];
        
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSLog(@"%@", error);
    }];
    
    
    
}

-(void)setUpTabBars
{
    [[UINavigationBar appearance] setBarTintColor:[UIColor vinylDarkGray]];
//    [[UINavigationBar appearance] setBarStyle:UIBarStyleBlack];
//    [[UINavigationBar appearance] setTranslucent:YES];
//    NSLog(@"%u",[UINavigationBar appearance].isTranslucent);
    NSLog(@"Is Bar Opaque: %@",[UINavigationBar appearance].isOpaque ? @"YES":@"NO");
    
    [[UITabBar appearance] setBarTintColor:[UIColor vinylDarkGray]];
    [[UITabBar appearance] setTintColor:[UIColor vinylOrange]];
//    [UITabBar appearance].translucent = NO;
    [[UINavigationBar appearance] setTintColor:[UIColor vinylLightGray]];
//    [UINavigationBar appearance].translucent = NO;
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
    UITabBarController *tabBarController = (UITabBarController *)self.window.rootViewController;
    UITabBar *tabBar = tabBarController.tabBar;
    UITabBarItem *tabBarItem0 = [tabBar.items objectAtIndex:0];
    UITabBarItem *tabBarItem1 = [tabBar.items objectAtIndex:1];
    UITabBarItem *tabBarItem2 = [tabBar.items objectAtIndex:2];
    UITabBarItem *tabBarItem3 = [tabBar.items objectAtIndex:3];
    UITabBarItem *tabBarItem4 = [tabBar.items objectAtIndex:4];
    
    tabBarItem0.selectedImage = [UIImage imageNamed:@"search-oj-32px.png"];
    tabBarItem1.selectedImage = [UIImage imageNamed:@"map-oj-32px.png"];
    tabBarItem2.selectedImage = [UIImage imageNamed:@"record-oj-32px"];
    tabBarItem3.selectedImage = [UIImage imageNamed:@"speech-bubble-oj-32px.png"];
    tabBarItem4.selectedImage = [UIImage imageNamed:@"settings-oj-32px.png"];
}


#pragma marks - defaults and no rotation

//-(UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window
//{
//    if(self.restrictRotation)
//        return UIInterfaceOrientationMaskPortrait;
//    else
//        return UIInterfaceOrientationMaskPortraitUpsideDown | UIInterfaceOrientationMaskPortrait;
//}


#pragma mark - application delegates


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
