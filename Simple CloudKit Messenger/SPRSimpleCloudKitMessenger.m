//
//  SPRSimpleCloudKitMessenger.m
//  CloudKit Manager
//
//  Created by Bob Spryn on 6/11/14.
//  Copyright (c) 2014 Sprynthesis. All rights reserved.
//

#import "SPRSimpleCloudKitMessenger.h"
@import CloudKit;

@interface SPRSimpleCloudKitMessenger ()
@property (readonly) CKContainer *container;
@property (readonly) CKDatabase *publicDatabase;
@property (nonatomic, getter=isSubscribed) BOOL subscribed;
@property (nonatomic, strong) CKRecordID *activeUserRecordID;
@end

NSString *const SPRSimpleCloudKitMessengerErrorDomain = @"com.SPRSimpleCloudKitMessenger.ErrorDomain";

static NSString *const SPRMessageRecordType = @"Message";
static NSString *const SPRMessageTextField = @"text";
static NSString *const SPRMessageImageField = @"image";
static NSString *const SPRMessageSenderField = @"sender";
static NSString *const SPRMessageReceiverField = @"receiver";
static NSString *const SPRActiveiCloudIdentity = @"SPRActiveiCloudIdentity";
static NSString *const SPRSubscriptionID = @"SPRSubscriptionID";

@implementation SPRSimpleCloudKitMessenger
- (id)init {
    self = [super init];
    if (self) {
        _container = [CKContainer defaultContainer];
        _publicDatabase = [_container publicCloudDatabase];
    }
    return self;
}

+ (SPRSimpleCloudKitMessenger *) sharedMessenger {
    static dispatch_once_t onceToken;
    static SPRSimpleCloudKitMessenger *messenger;
    dispatch_once(&onceToken, ^{
        messenger = [[SPRSimpleCloudKitMessenger alloc] init];
    });
    return messenger;
}

#pragma mark - Account status and discovery

// Uses internal methods to do the majority of the setup for this class
// If everything is successful, it returns the active user CKDiscoveredUserInfo
// All internal methods fire completionHandlers on the main thread, so no need to use GCD in this method
- (void) verifyAndFetchActiveiCloudUserWithCompletionHandler:(void (^)(CKDiscoveredUserInfo * userInfo, NSError *error)) completionHandler {
    [self verifyiCloudAccountStatusWithCompletionHandler:^(NSError *error) {
        if (error) {
            completionHandler(nil, error);
        } else {
            [self promptToBeDiscoverableIfNeededWithCompletionHandler:^(NSError *error) {
                if (error) {
                    completionHandler(nil, error);
                } else {
                    [self fetchActiveUserInfoWithCompletionHandler:completionHandler];
                }
            }];
        }
    }];
}

// Verifies iCloud Account Status and that the iCloud ubiquityIdentityToken hasn't changed
- (void) verifyiCloudAccountStatusWithCompletionHandler:(void (^)(NSError *error)) completionHandler {
    [self.container accountStatusWithCompletionHandler:^(CKAccountStatus accountStatus, NSError *error) {
        __block NSError *theError = nil;
        if (error) {
            theError = [self simpleCloudMessengerErrorForError:error];
        } else {
            // if it's not a valid account raise an error
            if (accountStatus != CKAccountStatusAvailable) {
                NSString *errorString = [self simpleCloudMessengerErrorStringForErrorCode:SPRSimpleCloudMessengerErroriCloudAccount];
                theError = [NSError errorWithDomain:SPRSimpleCloudKitMessengerErrorDomain
                                                        code:SPRSimpleCloudMessengerErroriCloudAccount
                                                    userInfo:@{NSLocalizedDescriptionKey: errorString }];
            } else {
                // grab the ubiquityIdentityToken
                id currentiCloudToken = [[NSFileManager defaultManager] ubiquityIdentityToken];
                id previousiCloudToken = [[NSUserDefaults standardUserDefaults] objectForKey:SPRActiveiCloudIdentity];
                // if it's a different ubiquityIdentityToken than previously stored, raise an error
                // so the developer can clear sensitive data
                if (previousiCloudToken && ![previousiCloudToken isEqual:currentiCloudToken]) {
                    theError = [NSError errorWithDomain:SPRSimpleCloudKitMessengerErrorDomain
                                                   code:SPRSimpleCloudMessengerErroriCloudAcountChanged
                                               userInfo:@{NSLocalizedDescriptionKey:[self simpleCloudMessengerErrorStringForErrorCode:SPRSimpleCloudMessengerErroriCloudAcountChanged]}];
                    // also clear the stored ubiquityIdentityToken and nil the active user record
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:SPRActiveiCloudIdentity];
                    self.activeUserRecordID = nil;
                } else {
                    // else everything is good, store the ubiquityIdentityToken
                    [[NSUserDefaults standardUserDefaults] setObject:currentiCloudToken forKey:SPRActiveiCloudIdentity];
                }
            }
        }
        // theError will either be an error or nil, so we can always pass it in
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) {
                completionHandler(theError);
            }
        });
    }];
}

// Checks the discoverability of the active user. Prompts if possible, errors if they are in a bad state
- (void) promptToBeDiscoverableIfNeededWithCompletionHandler:(void (^)(NSError *error)) completionHandler {
    [self.container requestApplicationPermission:CKApplicationPermissionUserDiscoverability completionHandler:^(CKApplicationPermissionStatus applicationPermissionStatus, NSError *error) {
        __block NSError *theError = nil;
        if (error) {
            theError = [self simpleCloudMessengerErrorForError:error];
        } else {
            // if not "granted", raise an error
            if (applicationPermissionStatus != CKApplicationPermissionStatusGranted) {
                NSString *errorString = [self simpleCloudMessengerErrorStringForErrorCode:SPRSimpleCloudMessengerErrorMissingDiscoveryPermissions];
                theError = [NSError errorWithDomain:SPRSimpleCloudKitMessengerErrorDomain
                                                        code:SPRSimpleCloudMessengerErrorMissingDiscoveryPermissions
                                                    userInfo:@{NSLocalizedDescriptionKey: errorString }];
            }
        }
        // theError will either be an error or nil, so we can always pass it in
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) {
                completionHandler(theError);
            }
        });
    }];
}

// Fetches the active user CKDiscoveredUserInfo, fairly straightforward
- (void) fetchActiveUserInfoWithCompletionHandler:(void (^)(CKDiscoveredUserInfo * userInfo, NSError *error)) completionHandler {
    [self fetchActiveUserRecordIDWithCompletionHandler:^(CKRecordID *recordID, NSError *error) {
        if (error) {
            // don't have to wrap this in GCD main because it's in our internal method on the main queue already
            completionHandler(nil, error);
        } else {
            [self.container discoverUserInfoWithUserRecordID:recordID completionHandler:^(CKDiscoveredUserInfo *userInfo, NSError *error) {
                NSError *theError = nil;
                if (error) {
                    theError = [self simpleCloudMessengerErrorForError:error];
                }
                // theError will either be an error or nil, so we can always pass it in
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completionHandler) {
                        completionHandler(userInfo, theError);
                    }
                });
            }];
        }
    }];
}

// fetches the active user record ID and stores it in a property
// also kicks off subscription for messages
- (void) fetchActiveUserRecordIDWithCompletionHandler:(void (^)(CKRecordID *recordID, NSError *error))completionHandler {
    [self.container fetchUserRecordIDWithCompletionHandler:^(CKRecordID *recordID, NSError *error) {
        NSError *theError = nil;
        if (error) {
            theError = [self simpleCloudMessengerErrorForError:error];
        } else {
            self.activeUserRecordID = recordID;
            [self subscribe];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) {
                // theError will either be an error or nil, so we can always pass it in
                completionHandler(recordID, theError);
            }
        });
    }];
}

#pragma mark - friends

// grabs all friends discoverable in the address book, fairly straightforward
- (void) discoverAllFriendsWithCompletionHandler:(void (^)(NSArray *friendRecords, NSError *error)) completionHandler {
    [self.container discoverAllContactUserInfosWithCompletionHandler:^(NSArray *userInfos, NSError *error) {
        NSError *theError = nil;
        if (error) {
            theError = [self simpleCloudMessengerErrorForError:error];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) {
                // theError will either be an error or nil, so we can always pass it in
                completionHandler(userInfos, theError);
            }
        });
    }];
}

#pragma mark - Subscription handling
// handles clearing old subscriptions, and setting up the new one
- (void)subscribe {
    if (self.subscribed == NO) {
        // find existing subscriptions and deletes them
#warning Should probably be more specific here so we don't kill any extra subscriptions the developer made
        CKFetchSubscriptionsOperation *fetchAllSubscriptions = [CKFetchSubscriptionsOperation fetchAllSubscriptionsOperation];

        fetchAllSubscriptions.fetchSubscriptionCompletionBlock = ^( NSDictionary *subscriptionsBySubscriptionID, NSError *operationError) {
#warning this operation silently fails, which is probably the right way to go
            if (!operationError) {
                // if there are existing subscriptions, delete them
                if (subscriptionsBySubscriptionID.count > 0) {
                    CKModifySubscriptionsOperation *modifyOperation = [[CKModifySubscriptionsOperation alloc] init];
                    modifyOperation.subscriptionIDsToDelete = subscriptionsBySubscriptionID.allKeys;
                    modifyOperation.modifySubscriptionsCompletionBlock = ^(NSArray *savedSubscriptions, NSArray *deletedSubscriptionIDs, NSError *error) {
#warning right now subscription errors fail silently.
                        if (!error) {
                            // then setup a new subscription
                            [self setupSubscription];
                        }
                    };
                    [self.publicDatabase addOperation:modifyOperation];
                    
                // else if there are no subscriptions, just setup a new one
                } else {
                    [self setupSubscription];
                }
            }
        };
        [self.publicDatabase addOperation:fetchAllSubscriptions];
    }
}

- (void) setupSubscription {
    // setup a subscription watching for new messages with the active user as the receiver
    CKReference *receiver = [[CKReference alloc] initWithRecordID:self.activeUserRecordID action:CKReferenceActionNone];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", SPRMessageReceiverField, receiver];
    CKSubscription *itemSubscription = [[CKSubscription alloc] initWithRecordType:SPRMessageRecordType
                                                                        predicate:predicate
                                                                          options:CKSubscriptionOptionsFiresOnRecordCreation];
    CKNotificationInfo *notification = [[CKNotificationInfo alloc] init];
    // TODO: Beef up the notification to actually substitute in the text from the message
    notification.alertBody = @"New Message!";
    itemSubscription.notificationInfo = notification;
    
    // create the subscription
    [self.publicDatabase saveSubscription:itemSubscription completionHandler:^(CKSubscription *subscription, NSError *error) {
#warning right now subscription errors fail silently.
        if (!error) {
            // save the subscription ID so we aren't constantly trying to create a new one
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setObject:subscription.subscriptionID forKey:SPRSubscriptionID];
        }
    }];
}

// unused for now, maybe expose as a "log out" method?
- (void)unsubscribe {
    if (self.subscribed == YES) {
        
        NSString *subscriptionID = [[NSUserDefaults standardUserDefaults] objectForKey:SPRSubscriptionID];
        
        CKModifySubscriptionsOperation *modifyOperation = [[CKModifySubscriptionsOperation alloc] init];
        modifyOperation.subscriptionIDsToDelete = @[subscriptionID];
        
        modifyOperation.modifySubscriptionsCompletionBlock = ^(NSArray *savedSubscriptions, NSArray *deletedSubscriptionIDs, NSError *error) {
#warning right now subscription errors fail silently.
            if (!error) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:SPRSubscriptionID];
            }
        };
        
        [self.publicDatabase addOperation:modifyOperation];
    }
}

- (BOOL)isSubscribed {
    return [[NSUserDefaults standardUserDefaults] objectForKey:SPRSubscriptionID] != nil;
}

#pragma mark - Messaging

// Does the work of "sending the message" e.g. Creating the message record.
- (void) sendMessage:(NSString *)message withImageURL:(NSURL *)imageURL toUserRecordID:(CKRecordID*)userRecordID withCompletionHandler:(void (^)(NSError *error)) completionHandler {
    // if we somehow don't have an active user record ID, raise an error about the iCloud account
    if (self.activeUserRecordID) {
        NSError *error = [NSError errorWithDomain:SPRSimpleCloudKitMessengerErrorDomain
                                             code:SPRSimpleCloudMessengerErroriCloudAccount
                                         userInfo:@{NSLocalizedDescriptionKey: [self simpleCloudMessengerErrorStringForErrorCode:SPRSimpleCloudMessengerErroriCloudAccount]}];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) {
                completionHandler(error);
            }
        });
        return;
    }
    // assemble the new record
    CKRecord *record = [[CKRecord alloc] initWithRecordType:SPRMessageRecordType];
    record[SPRMessageTextField] = message;
    if (imageURL) {
        CKAsset *asset = [[CKAsset alloc] initWithFileURL:imageURL];
        record[SPRMessageImageField] = asset;
    }
    CKReference *sender = [[CKReference alloc] initWithRecordID:self.activeUserRecordID action:CKReferenceActionNone];
    record[SPRMessageSenderField] = sender;
    CKReference *receiver = [[CKReference alloc] initWithRecordID:userRecordID action:CKReferenceActionNone];
    record[SPRMessageReceiverField] = receiver;
    
    // save the record
    [self.publicDatabase saveRecord:record completionHandler:^(CKRecord *record, NSError *error) {
        NSError *theError = nil;
        if (error) {
            theError = [self simpleCloudMessengerErrorForError:error];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) {
                // theError will either be an error or nil, so we can always pass it in
                completionHandler(theError);
            }
        });
    }];
}

// Method for fetching all new messages
// For now just grabs all CKNotifications ever for this user
- (void) fetchNewMessagesWithCompletionHandler:(void (^)(NSArray *messages, NSError *error)) completionHandler {
    CKFetchNotificationChangesOperation *operation = [[CKFetchNotificationChangesOperation alloc] initWithPreviousServerChangeToken:nil];
    NSMutableArray *notifications = [@[] mutableCopy];
    operation.notificationChangedBlock = ^ (CKNotification *notification) {
        [notifications addObject:notification];
        NSLog(@"%@", notification);
    };
    operation.fetchNotificationChangesCompletionBlock = ^ (CKServerChangeToken *serverChangeToken, NSError *operationError) {
        NSError *theError = nil;
        if (operationError) {
            theError = [self simpleCloudMessengerErrorForError:operationError];
        }
        NSLog(@"%@", notifications);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) {
                // theError will either be an error or nil, so we can always pass it in
                completionHandler([notifications copy], theError);
            }
        });
    };
    [self.container addOperation:operation];
}

#pragma mark - Error handling utility methods

// translates CKError domain errors into SPRSimpleCloudKitMessenger Errors
- (NSError *) simpleCloudMessengerErrorForError:(NSError *) error {
    SPRSimpleCloudMessengerError errorCode;
    if ([error.domain isEqualToString:CKErrorDomain]) {
        errorCode = [self simpleCloudMessengerErrorCodeForCKErrorCode:error.code];
    } else {
        errorCode = SPRSimpleCloudMessengerErrorUnexpected;
    }
    NSString *errorString = [self simpleCloudMessengerErrorStringForErrorCode:errorCode];
    return [NSError errorWithDomain:SPRSimpleCloudKitMessengerErrorDomain
                               code:errorCode
                           userInfo:@{NSLocalizedDescriptionKey: errorString,
                                      NSUnderlyingErrorKey: error}];
}

// Human friendly error strings for SPRSimpleCloudKitMessenger errors
- (NSString *) simpleCloudMessengerErrorStringForErrorCode: (SPRSimpleCloudMessengerError) code {
    switch (code) {
        case SPRSimpleCloudMessengerErroriCloudAccount:
            return NSLocalizedString(@"We were unable to find a valid iCloud account. Please add or update your iCloud account in the Settings app.", nil);
        case SPRSimpleCloudMessengerErrorMissingDiscoveryPermissions:
            return NSLocalizedString(@"Your friends are currently unable to discover you. Please enabled discovery permissions in the Settings app.", nil);
        case SPRSimpleCloudMessengerErrorNetwork:
            return NSLocalizedString(@"There was a network error. Please try again later or when you are back online.", nil);
        case SPRSimpleCloudMessengerErrorServiceUnavailable:
            return NSLocalizedString(@"The server is currently unavailable. Please try again later.", nil);
        case SPRSimpleCloudMessengerErrorCancelled:
            return NSLocalizedString(@"The request was cancelled.", nil);
        case SPRSimpleCloudMessengerErroriCloudAcountChanged:
            return NSLocalizedString(@"The iCloud account in user has changed.", nil);
        case SPRSimpleCloudMessengerErrorUnexpected:
        default:
            return NSLocalizedString(@"There was an unexpected error. Please try again later.", nil);
    }
}

// maps CKError domain error codes into SPRSimpleCloudKitMessenger error domain codes
- (SPRSimpleCloudMessengerError) simpleCloudMessengerErrorCodeForCKErrorCode: (CKErrorCode) code {
    switch (code) {
        case CKErrorNetworkUnavailable:
        case CKErrorNetworkFailure:
            return SPRSimpleCloudMessengerErrorNetwork;
        case CKErrorServiceUnavailable:
            return SPRSimpleCloudMessengerErrorServiceUnavailable;
        case CKErrorNotAuthenticated:
            return SPRSimpleCloudMessengerErroriCloudAccount;
        case CKErrorPermissionFailure:
            // right now the ONLY permission is for discovery
            // if that changes in the future, will want to make this more accurate
            return SPRSimpleCloudMessengerErrorMissingDiscoveryPermissions;
        case CKErrorOperationCancelled:
            return SPRSimpleCloudMessengerErrorCancelled;
        case CKErrorBadDatabase:
        case CKErrorQuotaExceeded:
        case CKErrorZoneNotFound:
        case CKErrorBadContainer:
        case CKErrorInternalError:
        case CKErrorPartialFailure:
        case CKErrorMissingEntitlement:
        case CKErrorUnknownItem:
        case CKErrorInvalidArguments:
        case CKErrorResultsTruncated:
        case CKErrorServerRecordChanged:
        case CKErrorServerRejectedRequest:
        case CKErrorAssetFileNotFound:
        case CKErrorAssetFileModified:
        case CKErrorIncompatibleVersion:
        case CKErrorConstraintViolation:
        case CKErrorChangeTokenExpired:
        case CKErrorBatchRequestFailed:
        default:
            return SPRSimpleCloudMessengerErrorUnexpected;
    }
}


@end
