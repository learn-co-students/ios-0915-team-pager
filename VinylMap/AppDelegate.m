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
#import <FirebaseUI/FirebaseUI.h>
#import <AFNetworking.h>
#import <KDURLRequestSerialization+OAuth.h>

@interface AppDelegate  () <GIDSignInDelegate>
@property (nonatomic, strong) AFHTTPSessionManager *manager;

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    [UserObject sharedUser];
    [[FBSDKApplicationDelegate sharedInstance] application:application didFinishLaunchingWithOptions:launchOptions]; // THIS WAKES UP THE FACEBOOK DELEGATES
    [UserObject sharedUser].facebookUserID = [FBSDKAccessToken currentAccessToken].userID;
    [self setUpFirebase];
    
    
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
            NSLog(@"%@",authData); //AUTHDATA COMPLETE
            [UserObject sharedUser].firebaseAuthData = authData;
        } else{
            NSLog(@"User not logged in or just logged out");
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

-(BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options
{
    //MAKE THIS CONDITIONAL FOR FACEBOOK
    NSString *stringFromURL = [url absoluteString];
    NSLog(@"%lu",(unsigned long)[stringFromURL rangeOfString:FACEBOOK_KEY].location);
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
    NSString *timeInterval = [NSString stringWithFormat:@"%ld", [@([[NSDate date] timeIntervalSince1970]) integerValue]];
    NSDictionary *params = @{@"oauth_consumer_key" : DISCOGS_CONSUMER_KEY,
                             @"oauth_signature" : [NSString stringWithFormat:@"%@&",DISCOGS_CONSUMER_SECRET],
                             @"oauth_signature_method":@"PLAINTEXT",
                             @"oauth_timestamp" : timeInterval,
                             @"oauth_nonce" : @"jThArMF",
                             @"oauth_verifier" : [UserObject sharedUser].discogsOAuthVerifier,
                             @"oauth_token" : [UserObject sharedUser].discogsRequestToken,
                             @"User-Agent" : @"uniqueVinylMaps",
                             @"oauth_version" : @"1.0",
                             @"oauth_callback" : @"vinyl-discogs-beeper://"
                             };
    
    self.manager = [AFHTTPSessionManager manager];
    
    KDHTTPRequestSerializer *reqSerializer = [KDHTTPRequestSerializer serializer];
    [reqSerializer setUseOAuth:YES];
    self.manager.requestSerializer = reqSerializer;
    self.manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    self.manager.responseSerializer.acceptableContentTypes = [self.manager.responseSerializer.acceptableContentTypes setByAddingObject:@"text/html"];
    
    //WHY IS THIS NOT WORKING?  WHY DO I EVEN NEED TO DO THIS WHEN I GET THE OAUTH SECRET IN THE FIRST STEP
    
    [self.manager POST:stringURL parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        NSString *responseString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        NSLog(@"%@", responseString);
        responseString = [NSString stringWithFormat:@"%@?%@",stringURL,responseString]; //ADDED ORIGINAL URL TO USE QUEURY ITEMS
        NSURL *responseURL = [NSURL URLWithString:responseString]; // CHANGED TO NSURL
        NSURLComponents *urlComps = [NSURLComponents componentsWithURL:responseURL resolvingAgainstBaseURL:nil];
        NSArray *urlParts = urlComps.queryItems;
        
        for (NSURLQueryItem *queryItem in urlParts) {
            if([queryItem.name isEqualToString:@"oauth_token_secret"])
            {
                
            } else if ([queryItem.name isEqualToString:@"oauth_token"])
            {
                
            }
        }
        
        
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSLog(@"%@", error);
    }];
    
}


-(UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window
{
    if(self.restrictRotation)
        return UIInterfaceOrientationMaskPortrait;
    else
        return UIInterfaceOrientationMaskAll;
}



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
