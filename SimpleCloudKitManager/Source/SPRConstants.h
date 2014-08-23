//
//  Constants.h
//  SimpleCloudKitManager
//
//  Created by Adam Wulf on 8/22/14.
//  Copyright (c) 2014 Adam Wulf. All rights reserved.
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
    SCKMAccountStatusNoAccount                           = 3,
    SCKMAccountStatusLoading
};

typedef NS_ENUM(NSInteger, SCKMApplicationPermissionStatus) {
    /* The user has not made a decision for this application permission. */
    SCKMApplicationPermissionStatusInitialState          = 0,
    /* An error occurred when getting or setting the application permission status, consult the corresponding NSError */
    SCKMApplicationPermissionStatusCouldNotComplete      = 1,
    /* The user has denied this application permission */
    SCKMApplicationPermissionStatusDenied                = 2,
    /* The user has granted this application permission */
    SCKMApplicationPermissionStatusGranted               = 3,
    SCKMApplicationPermissionStatusLoading
};


typedef NS_ENUM(NSUInteger, SPRSimpleCloudMessengerError) {
    SPRSimpleCloudMessengerErrorUnexpected,
    SPRSimpleCloudMessengerErroriCloudAccount,
    SPRSimpleCloudMessengerErrorMissingDiscoveryPermissions,
    SPRSimpleCloudMessengerErrorNetwork,
    SPRSimpleCloudMessengerErrorServiceUnavailable,
    SPRSimpleCloudMessengerErrorCancelled,
    SPRSimpleCloudMessengerErroriCloudAccountChanged,
};

static NSString *const SPRSimpleCloudKitMessengerErrorDomain = @"com.SPRSimpleCloudKitMessenger.ErrorDomain";
static NSString *const SPRMessageRecordType = @"Message";
static NSString *const SPRMessageTextField = @"text";
static NSString *const SPRMessageImageField = @"image";
static NSString *const SPRMessageSenderField = @"sender";
static NSString *const SPRMessageSenderFirstNameField = @"senderFirstName";
static NSString *const SPRMessageReceiverField = @"receiver";
static NSString *const SPRActiveiCloudIdentity = @"SPRActiveiCloudIdentity";
static NSString *const SPRSubscriptionID = @"SPRSubscriptionID";
static NSString *const SPRSubscriptionIDIncomingMessages = @"IncomingMessages";
static NSString *const SPRServerChangeToken = @"SPRServerChangeToken";

#endif
