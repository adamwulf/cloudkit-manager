//
//  AppDelegate.m
//  CloudKit Manager
//
//  Created by Bob Spryn on 6/11/14.
//  Copyright (c) 2014 Sprynthesis. All rights reserved.
//

#import "AppDelegate.h"
#import "SPRSimpleCloudKitMessenger.h"
#import "SPRMessage.h"

@interface AppDelegate ()
            
@property (nonatomic, strong) SPRSimpleCloudKitMessenger *simpleCloudKitMessenger;
@end

@implementation AppDelegate
            

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [application registerForRemoteNotifications];
    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeAlert
                          |UIUserNotificationTypeSound) categories:nil];
    [application registerUserNotificationSettings:settings];
    
    if (launchOptions != nil)
    {
        NSDictionary *dictionary = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
        if (dictionary != nil)
        {
            [self checkForNotificationToHandleWithUserInfo:dictionary];
        }
    }

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
    NSLog(@"%@", deviceToken);
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"%@", error);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)info {
    
    // Do something if the app was in background. Could handle foreground notifications differently
    if (application.applicationState != UIApplicationStateActive) {
        [self checkForNotificationToHandleWithUserInfo:info];
    }
}

- (void) checkForNotificationToHandleWithUserInfo:(NSDictionary *)userInfo {
    NSString *notificationKey = [userInfo valueForKeyPath:@"ck.qry.sid"];
    if ([notificationKey isEqualToString:SPRSubscriptionIDIncomingMessages]) {
        CKQueryNotification *notification = [CKQueryNotification notificationFromRemoteNotificationDictionary:userInfo];
        [[SPRSimpleCloudKitMessenger sharedMessenger] messageForQueryNotification:notification withCompletionHandler:^(SPRMessage *message, NSError *error) {
            // Do something with the message, like pushing it onto the stack
            NSLog(@"%@", message);
        }];
    }
}

@end
