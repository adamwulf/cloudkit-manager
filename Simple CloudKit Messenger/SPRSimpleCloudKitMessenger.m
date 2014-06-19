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
static NSString *const SPRActiveUserRecordID = @"SPRActiveUserRecordID";

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

- (void) verifyiCloudAccountStatusWithCompletionHandler:(void (^)(NSError *error)) completionHandler {
    [self.container accountStatusWithCompletionHandler:^(CKAccountStatus accountStatus, NSError *error) {
        __block NSError *theError = nil;
        if (error) {
            theError = [self simpleCloudMessengerErrorForError:error];
        } else {
            if (accountStatus != CKAccountStatusAvailable) {
                NSString *errorString = [self simpleCloudMessengerErrorStringForErrorCode:SPRSimpleCloudMessengerErroriCloudAccount];
                theError = [NSError errorWithDomain:SPRSimpleCloudKitMessengerErrorDomain
                                                        code:SPRSimpleCloudMessengerErroriCloudAccount
                                                    userInfo:@{NSLocalizedDescriptionKey: errorString }];
            }
        }
        // theError will either be an error or nil
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) {
                completionHandler(theError);
            }
        });
    }];
}

- (void) promptToBeDiscoverableIfNeededWithCompletionHandler:(void (^)(NSError *error)) completionHandler {
    [self.container requestApplicationPermission:CKApplicationPermissionUserDiscoverability completionHandler:^(CKApplicationPermissionStatus applicationPermissionStatus, NSError *error) {
        __block NSError *theError = nil;
        if (error) {
            theError = [self simpleCloudMessengerErrorForError:error];
        } else {
            if (applicationPermissionStatus != CKApplicationPermissionStatusGranted) {
                NSString *errorString = [self simpleCloudMessengerErrorStringForErrorCode:SPRSimpleCloudMessengerErrorMissingDiscoveryPermissions];
                theError = [NSError errorWithDomain:SPRSimpleCloudKitMessengerErrorDomain
                                                        code:SPRSimpleCloudMessengerErrorMissingDiscoveryPermissions
                                                    userInfo:@{NSLocalizedDescriptionKey: errorString }];
            }
        }
        // theError will either be an error or nil
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) {
                completionHandler(theError);
            }
        });
    }];
}

- (void) fetchActiveUserInfoWithCompletionHandler:(void (^)(CKDiscoveredUserInfo * userInfo, NSError *error)) completionHandler {
    [self fetchActiveUserRecordIDWithCompletionHandler:^(CKRecordID *recordID, NSError *error) {
        if (error) {
            completionHandler(nil, error);
        } else {
            [self.container discoverUserInfoWithUserRecordID:recordID completionHandler:^(CKDiscoveredUserInfo *userInfo, NSError *error) {
                NSError *theError = nil;
                if (error) {
                    theError = [self simpleCloudMessengerErrorForError:error];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completionHandler) {
                        completionHandler(userInfo, theError);
                    }
                });
            }];
        }
    }];
}

- (void) fetchActiveUserRecordIDWithCompletionHandler:(void (^)(CKRecordID *recordID, NSError *error))completionHandler {
    [self.container fetchUserRecordIDWithCompletionHandler:^(CKRecordID *recordID, NSError *error) {
        NSError *theError = nil;
        if (error) {
            theError = [self simpleCloudMessengerErrorForError:error];
        } else {
#warning Need to somehow store and check against previously logged in user, potentially with ubiquityIdentityToken off of the NSFileManager
//            CKRecordID *previousRecordID  = [[NSUserDefaults standardUserDefaults] objectForKey:SPRActiveUserRecordID];
//            [[NSUserDefaults standardUserDefaults] setObject:recordID forKey:SPRActiveUserRecordID];
            // if the iCloud account changed, raise an error with the record ID
            CKRecordID *previousRecordID = self.activeUserRecordID;
            self.activeUserRecordID = recordID;
            if (previousRecordID && ![previousRecordID isEqual:recordID]) {
                theError = [NSError errorWithDomain:SPRSimpleCloudKitMessengerErrorDomain
                                               code:SPRSimpleCloudMessengerErroriCloudAcountChanged
                                           userInfo:@{NSLocalizedDescriptionKey:[self simpleCloudMessengerErrorStringForErrorCode:SPRSimpleCloudMessengerErroriCloudAcountChanged]}];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) {
                completionHandler(recordID, theError);
            }
        });
    }];
}

#pragma mark - friends

- (void) discoverAllFriendsWithCompletionHandler:(void (^)(NSArray *friendRecords, NSError *error)) completionHandler {
    [self.container discoverAllContactUserInfosWithCompletionHandler:^(NSArray *userInfos, NSError *error) {
        NSError *theError = nil;
        if (error) {
            theError = [self simpleCloudMessengerErrorForError:error];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) {
                completionHandler(userInfos, theError);
            }
        });
    }];
}

#pragma mark - Subscription handling

- (void)subscribeWithCompletionHandler:(void (^)(NSError *error)) completionHandler {
    
    if (self.subscribed == NO) {
        
        NSPredicate *truePredicate = [NSPredicate predicateWithValue:YES];
        CKSubscription *itemSubscription = [[CKSubscription alloc] initWithRecordType:SPRMessageRecordType
                                                                            predicate:truePredicate
                                                                              options:CKSubscriptionOptionsFiresOnRecordCreation];
        
        
        CKNotificationInfo *notification = [[CKNotificationInfo alloc] init];
        notification.alertBody = @"New Item Added!";
        itemSubscription.notificationInfo = notification;
        
        [self.publicDatabase saveSubscription:itemSubscription completionHandler:^(CKSubscription *subscription, NSError *error) {
            NSError *theError = nil;
            if (error) {
                theError = [self simpleCloudMessengerErrorForError:error];
            } else {
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"Subscribed to Item");
//                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                //                [defaults setBool:YES forKey:@"subscribed"];
                //                [defaults setObject:subscription.subscriptionID forKey:@"subscriptionID"];

                if (completionHandler) {
                    completionHandler(theError);
                }
            });
        }];
    }
}

- (void)unsubscribe {
    if (self.subscribed == YES) {
        
        NSString *subscriptionID = [[NSUserDefaults standardUserDefaults] objectForKey:@"subscriptionID"];
        
        CKModifySubscriptionsOperation *modifyOperation = [[CKModifySubscriptionsOperation alloc] init];
        modifyOperation.subscriptionIDsToDelete = @[subscriptionID];
        
        modifyOperation.modifySubscriptionsCompletionBlock = ^(NSArray *savedSubscriptions, NSArray *deletedSubscriptionIDs, NSError *error) {
            if (error) {
                // In your app, handle this error beautifully.
                NSLog(@"An error occured in %@: %@", NSStringFromSelector(_cmd), error);
                abort();
            } else {
                NSLog(@"Unsubscribed to Item");
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"subscriptionID"];
            }
        };
        
        [self.publicDatabase addOperation:modifyOperation];
    }
}

- (BOOL)isSubscribed {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"subscriptionID"] != nil;
}

#pragma mark - Messaging

- (void) sendMessage:(NSString *)message withImageURL:(NSURL *)imageURL toUserRecordID:(CKRecordID*)userRecordID withCompletionHandler:(void (^)(NSError *error)) completionHandler {
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
    
    [self.publicDatabase saveRecord:record completionHandler:^(CKRecord *record, NSError *error) {
        NSError *theError = nil;
        if (error) {
            theError = [self simpleCloudMessengerErrorForError:error];
        } else {
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) {
                completionHandler(theError);
            }
        });
    }];

}

#pragma mark - Error handling utility methods

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
