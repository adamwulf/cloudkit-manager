//
//  AppDelegate.m
//  CloudKit Manager
//
//  Created by Bob Spryn on 6/11/14.
//  Copyright (c) 2014 Sprynthesis. All rights reserved.
//

#import "AppDelegate.h"
#import "SPRSimpleCloudKitMessenger.h"

@interface AppDelegate ()
            
@property (nonatomic, strong) SPRSimpleCloudKitMessenger *simpleCloudKitMessenger;
@end

@implementation AppDelegate
            

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [application registerForRemoteNotifications];
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [[SPRSimpleCloudKitMessenger sharedMessenger] verifyAndFetchActiveiCloudUserWithCompletionHandler:^(CKDiscoveredUserInfo *userInfo, NSError *error) {
        if (error) {
            [[[UIAlertView alloc] initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
        }
    }];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)info {
    NSLog(@"%@", info);
}

@end
