//
//  SPRSimpleCloudKitMessenger.h
//  CloudKit Manager
//
//  Created by Bob Spryn on 6/11/14.
//  Copyright (c) 2014 Sprynthesis. All rights reserved.
//

#import <Foundation/Foundation.h>
@import UIKit;
@import CloudKit;

typedef NS_ENUM(NSUInteger, SPRSimpleCloudMessengerError) {
    SPRSimpleCloudMessengerErrorUnexpected,
    SPRSimpleCloudMessengerErroriCloudAccount,
    SPRSimpleCloudMessengerErrorMissingDiscoveryPermissions,
    SPRSimpleCloudMessengerErrorNetwork,
    SPRSimpleCloudMessengerErrorServiceUnavailable,
    SPRSimpleCloudMessengerErrorCancelled,
    SPRSimpleCloudMessengerErroriCloudAcountChanged,
};

extern NSString *const SPRSimpleCloudKitMessengerErrorDomain;

@interface SPRSimpleCloudKitMessenger : NSObject

+ (SPRSimpleCloudKitMessenger *) sharedMessenger;
- (void) discoverAllFriendsWithCompletionHandler:(void (^)(NSArray *friendRecords, NSError *error)) completionHandler;
- (void) fetchNewMessagesWithCompletionHandler:(void (^)(NSArray *messages, NSError *error)) completionHandler;
- (void) sendMessage:(NSString *)message withImageURL:(NSURL *)imageURL toUserRecordID:(CKRecordID*)userRecordID withCompletionHandler:(void (^)(NSError *error)) completionHandler;
- (void) verifyAndFetchActiveiCloudUserWithCompletionHandler:(void (^)(CKDiscoveredUserInfo * userInfo, NSError *error)) completionHandler;
@end
