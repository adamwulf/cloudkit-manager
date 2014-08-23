//
//  SPRSimpleCloudKitMessenger.h
//  CloudKit Manager
//
//  Created by Bob Spryn on 6/11/14.
//  Copyright (c) 2014 Sprynthesis. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CloudKit/CloudKit.h>
#import "SPRMessage.h"
#import "SPRConstants.h"

/**
 * Provides a messaging service using CloudKit
 *
 * This class is a bare bones implementation of messaging built on top of CloudKit
 */
@interface SPRSimpleCloudKitManager : NSObject

// logged in user account, if any
@property (readonly) SCKMAccountStatus accountStatus;
@property (readonly) SCKMApplicationPermissionStatus permissionStatus;
@property (readonly) CKRecordID *accountRecordID;
@property (readonly) CKDiscoveredUserInfo *accountInfo;


/** @return The configured SPRSimpleCloudKitMessenger instance */
+ (SPRSimpleCloudKitManager *) sharedManager;

- (void) silentlyVerifyiCloudAccountStatusOnComplete:(void (^)(SCKMAccountStatus accountStatus,  SCKMApplicationPermissionStatus permissionStatus, NSError *error)) completionHandler;

- (void) silentlyFetchUserInfoOnComplete:(void (^)(CKRecordID *recordID, CKDiscoveredUserInfo * userInfo, NSError *error)) completionHandler;

/** The main entry point for using this class
 * 
 * This method does the majority of the heavy lifting for setting up for the active iCloud user.
 * It checks if they have a valid iCloud account and prompts for them to be discoverable. It will return an error
 * if they don't have a valid iCloud account, or if their discovery permissions are disabled.
 *
 * This method will also return an error if the user changed iCloud accounts since the last time they used your app.
 * You should check for error code == SPRSimpleCloudMessengerErroriCloudAccountChanged and clean up any private user data. You may or may
 * not want to display the error message from this error.
 * This would be a good hook for "logging out" if that applies to your app. Once you have cleaned up old user data, call this method 
 * again to prepare for the new iCloud user (or when they tap a "log in" button.
 *
 * Any errors returned from this method, or any other method on this class, will have a friendly error message in NSLocalizedDescription.
 * All serious errors will carry the code SPRSimpleCloudMessengerErrorUnexpected.
 * 
 * Once "logged in", you should call this method every time your app becomes active so it can perform it's checks.
 * @param completionHandler will either return a CKDiscoveredUserInfo or an NSError
 */
- (void) promptAndFetchUserInfoOnComplete:(void (^)(CKDiscoveredUserInfo * userInfo, NSError *error)) completionHandler;

/** Method for retrieving all discoverable friends from the user's address book.
 * @param completionHandler will either return an NSArray of CKDiscoveredUserInfo or an NSError
 */
- (void) discoverAllFriendsWithCompletionHandler:(void (^)(NSArray *friendRecords, NSError *error)) completionHandler;

/** Method for retrieving all new messages
 * @param completionHandler that will be called after fetching new notifications. Will include an NSArray of SPRMessage objects, or an NSError param.
 */
- (void) fetchNewMessagesWithCompletionHandler:(void (^)(NSArray *messages, NSError *error)) completionHandler;
/** Method for retrieving the details about a certain messge
 * 
 * Use this when trying to display the detail view of a message including the image. You can check for the image on the message 
 * to decide whether to call this. It updates the existing message object, and returns it again in the callback
 * @param completionHandler will be called after the fetching is complete with either the full message object or an NSError
 */
- (void) fetchDetailsForMessage:(SPRMessage *)message withCompletionHandler:(void (^)(SPRMessage *message, NSError *error)) completionHandler;

/** Method for sending a message to the specified user record ID
 * @param message an NSString of the text you want to send
 * @param imageURL a NSURL to the image on disk
 * @param userRecordID a valid CKRecordID for the user the message is destined for
 * @param completionHandler will return an NSError if the send failed
 */
- (void) sendMessage:(NSString *)message withImageURL:(NSURL *)imageURL toUserRecordID:(CKRecordID*)userRecordID withCompletionHandler:(void (^)(NSError *error)) completionHandler;

/** Method for turning a CKQueryNotification into a SPRMessage object
*
* Use this when trying to convert a one off CKQueryNotification into a message object.
* For fetching all new message notifications and creating message objects see `fetchNewMessagesWithCompletionHandler`
* @param completionHandler will be called after the fetching is complete with either the full message object or an NSError
*/
- (void) messageForQueryNotification:(CKQueryNotification *) notification withCompletionHandler:(void (^)(SPRMessage *message, NSError *error)) completionHandler;

@end
