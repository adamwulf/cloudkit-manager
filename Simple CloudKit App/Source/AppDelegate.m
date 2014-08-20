//
//  AppDelegate.m
//  CloudKit Manager
//
//  Created by Bob Spryn on 6/11/14.
//  Copyright (c) 2014 Sprynthesis. All rights reserved.
//

#import "AppDelegate.h"
#import <SimpleCloudKitManager/SPRSimpleCloudKitManager.h>

@implementation AppDelegate
            

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"didFinishLaunchingWithOptions");

    if (launchOptions != nil)
    {
        NSDictionary *dictionary = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
        if (dictionary != nil)
        {
            [self checkForNotificationToHandleWithUserInfo:dictionary];
        }
    }

    [self verifyAndLogIntoCloudKit];

    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    NSLog(@"applicationDidBecomeActive");
}

-(void) applicationWillEnterForeground:(UIApplication *)application{
    NSLog(@"applicationWillEnterForeground");
    [self verifyAndLogIntoCloudKit];
}

-(void) applicationDidEnterBackground:(UIApplication *)application{
    NSLog(@"applicationDidEnterBackground");
}

-(void) applicationWillResignActive:(UIApplication *)application{
    NSLog(@"applicationWillResignActive");
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSLog(@"%@", deviceToken);
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"%@", error);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)info {
    
    // Do something if the app was in background. Could handle foreground notifications differently
    if (application.applicationState != UIApplicationStateActive) {
        [self checkForNotificationToHandleWithUserInfo:info];
    }else{
        [self checkForNotificationToHandleWithUserInfo:info];
    }
}

- (void) checkForNotificationToHandleWithUserInfo:(NSDictionary *)userInfo {
    NSString *notificationKey = [userInfo valueForKeyPath:@"ck.qry.sid"];
    if ([notificationKey isEqualToString:SPRSubscriptionIDIncomingMessages]) {
        CKQueryNotification *notification = [CKQueryNotification notificationFromRemoteNotificationDictionary:userInfo];
        [[SPRSimpleCloudKitManager sharedMessenger] messageForQueryNotification:notification withCompletionHandler:^(SPRMessage *message, NSError *error) {
            // Do something with the message, like pushing it onto the stack
            NSLog(@"%@", message);
            if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
                UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Message!" message:message.messageText delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alertView show];
            }

        }];
    }
    
}


-(void) verifyAndLogIntoCloudKit{
    [[SPRSimpleCloudKitManager sharedMessenger] verifyAndFetchActiveiCloudUserWithCompletionHandler:^(CKDiscoveredUserInfo *userInfo, NSError *error) {
        if (error) {
            [[[UIAlertView alloc] initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
        }
    }];
}

@end
