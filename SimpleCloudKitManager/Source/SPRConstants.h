//
//  Constants.h
//  SimpleCloudKitManager
//
//  Created by Adam Wulf on 8/22/14.
//  Copyright (c) 2014 Milestone Made, LLC. All rights reserved.
//

typedef NS_ENUM(NSInteger, SCKMAccountStatus);
typedef NS_ENUM(NSInteger, SCKMApplicationPermissionStatus);
typedef NS_ENUM(NSUInteger, SPRSimpleCloudMessengerError);

#ifndef SimpleCloudKitManager_Constants_h
#define SimpleCloudKitManager_Constants_h

typedef NS_ENUM(NSInteger, SCKMAccountStatus) {
    /* An error occurred when getting the account status, consult the corresponding NSError */
    SCKMAccountStatusCouldNotDetermine                   = 0,
    /* The iCloud account credentials are available for this application */
    SCKMAccountStatusAvailable                           = 1,
    /* Parental Controls / Device Management has denied access to iCloud account credentials */
    SCKMAccountStatusRestricted                          = 2,
    /* No iCloud account is logged in on this device */
    SCKMAccountStatusNoAccount                           = 3
};

typedef NS_ENUM(NSInteger, SCKMApplicationPermissionStatus) {
    /* The user has not made a decision for this application permission. */
    SCKMApplicationPermissionStatusInitialState          = 0,
    /* An error occurred when getting or setting the application permission status, consult the corresponding NSError */
    SCKMApplicationPermissionStatusCouldNotComplete      = 1,
    /* The user has denied this application permission */
    SCKMApplicationPermissionStatusDenied                = 2,
    /* The user has granted this application permission */
    SCKMApplicationPermissionStatusGranted               = 3
};


typedef NS_ENUM(NSUInteger, SPRSimpleCloudMessengerError) {
    SPRSimpleCloudMessengerErrorUnexpected,
    SPRSimpleCloudMessengerErroriCloudAccount,
    SPRSimpleCloudMessengerErrorMissingDiscoveryPermissions,
    SPRSimpleCloudMessengerErrorNetwork,
    SPRSimpleCloudMessengerErrorServiceUnavailable,
    SPRSimpleCloudMessengerErrorRateLimit,
    SPRSimpleCloudMessengerErrorCancelled,
    SPRSimpleCloudMessengerErroriCloudAccountChanged,
};

static NSString * _Nonnull const SPRSimpleCloudKitMessengerErrorDomain = @"com.SPRSimpleCloudKitMessenger.ErrorDomain";
static NSString * _Nonnull const SPRMessageRecordType = @"Message";
static NSString * _Nonnull const SPRMessageImageField = @"image";
static NSString * _Nonnull const SPRMessageSenderField = @"sender";
static NSString * _Nonnull const SPRMessageSenderFirstNameField = @"senderFirstName";
static NSString * _Nonnull const SPRMessageReceiverField = @"receiver";
static NSString * _Nonnull const SPRActiveiCloudIdentity = @"SPRActiveiCloudIdentity";
static NSString * _Nonnull const SPRSubscriptionID = @"SPRSubscriptionID";
static NSString * _Nonnull const SPRSubscriptionIDIncomingMessages = @"IncomingMessages";
static NSString * _Nonnull const SPRServerChangeToken = @"SPRServerChangeToken";
static NSString * _Nonnull const SPRMessageTextField = @"text";   

typedef void (^CKUserCloudInfoRequestHandler)(NSObject * _Nullable userInfo,
                                             NSError * _Nullable error);
typedef void (^CKDiscoverCloudFriendsCompletionHandler)(NSArray *   _Nullable userInfos, NSError *  _Nullable error);
#endif
