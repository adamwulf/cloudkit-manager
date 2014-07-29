//
//  SPRSimpleCloudKitMessenger.m
//  CloudKit Manager
//
//  Created by Bob Spryn on 6/11/14.
//  Copyright (c) 2014 Sprynthesis. All rights reserved.
//

#import "SPRSimpleCloudKitMessenger.h"
@import CloudKit;
#import "SPRMessage.h"

@interface SPRSimpleCloudKitMessenger ()
@property (readonly) CKContainer *container;
@property (readonly) CKDatabase *publicDatabase;
@property (nonatomic, getter=isSubscribed) BOOL subscribed;
@property (nonatomic, strong) CKRecordID *activeUserRecordID;
@property (nonatomic, strong) CKDiscoveredUserInfo *activeUserInfo;

@property (nonatomic, strong) CKServerChangeToken *serverChangeToken;
@end

NSString *const SPRSimpleCloudKitMessengerErrorDomain = @"com.SPRSimpleCloudKitMessenger.ErrorDomain";

static NSString *const SPRMessageRecordType = @"Message";
NSString *const SPRMessageTextField = @"text";
NSString *const SPRMessageImageField = @"image";
NSString *const SPRMessageSenderField = @"sender";
NSString *const SPRMessageSenderFirstNameField = @"senderFirstName";
static NSString *const SPRMessageReceiverField = @"receiver";
static NSString *const SPRActiveiCloudIdentity = @"SPRActiveiCloudIdentity";
static NSString *const SPRSubscriptionID = @"SPRSubscriptionID";
NSString *const SPRSubscriptionIDIncomingMessages = @"IncomingMessages";
static NSString *const SPRServerChangeToken = @"SPRServerChangeToken";

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
                    // also clear the stored ubiquityIdentityToken, the subscription ID and nil the active user record
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:SPRActiveiCloudIdentity];
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:SPRSubscriptionID];
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
                } else {
                    self.activeUserInfo = userInfo;
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
        // TODO: Could be more specific here so we don't kill any extra subscriptions the developer made. Need to learn more about when to delete/refresh subscriptions from Apple.
        CKFetchSubscriptionsOperation *fetchAllSubscriptions = [CKFetchSubscriptionsOperation fetchAllSubscriptionsOperation];
        fetchAllSubscriptions.subscriptionIDs = @[SPRSubscriptionIDIncomingMessages];

        fetchAllSubscriptions.fetchSubscriptionCompletionBlock = ^( NSDictionary *subscriptionsBySubscriptionID, NSError *operationError) {
            // this operation silently fails, which is probably the right way to go
            // Partial failure means this operation likely doesn't exist
            if (!operationError || operationError.code == CKErrorPartialFailure) {
                // if there are existing subscriptions, delete them
                if (subscriptionsBySubscriptionID.count > 0) {
                    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                    [defaults setBool:YES forKey:SPRSubscriptionID];
                // else if there are no subscriptions, just setup a new one
                } else {
                    [self setupSubscription];
                }
            }
        };
        [self.publicDatabase addOperation:fetchAllSubscriptions];
    }
}

- (CKSubscription *) incomingMessageSubscription {
    // setup a subscription watching for new messages with the active user as the receiver
    CKReference *receiver = [[CKReference alloc] initWithRecordID:self.activeUserRecordID action:CKReferenceActionNone];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", SPRMessageReceiverField, receiver];
    CKSubscription *itemSubscription = [[CKSubscription alloc] initWithRecordType:SPRMessageRecordType
                                                                        predicate:predicate
                                                                   subscriptionID:SPRSubscriptionIDIncomingMessages
                                                                          options:CKSubscriptionOptionsFiresOnRecordCreation];
    CKNotificationInfo *notification = [[CKNotificationInfo alloc] init];
    notification.alertLocalizationKey = @"Message from %@: %@.";
    notification.alertLocalizationArgs = @[SPRMessageSenderFirstNameField, SPRMessageTextField];
    notification.desiredKeys = @[SPRMessageSenderFirstNameField, SPRMessageTextField, SPRMessageSenderField];
    itemSubscription.notificationInfo = notification;
    return itemSubscription;
}

- (void) setupSubscription {
    
    // create the subscription
    [self.publicDatabase saveSubscription:[self incomingMessageSubscription] completionHandler:^(CKSubscription *subscription, NSError *error) {
        // right now subscription errors fail silently.
        if (!error) {
            // save the subscription ID so we aren't constantly trying to create a new one
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setBool:YES forKey:SPRSubscriptionID];
        }
    }];
}

// unused for now, maybe expose as a "log out" method?
- (void)unsubscribe {
    if (self.subscribed == YES) {
        
        CKModifySubscriptionsOperation *modifyOperation = [[CKModifySubscriptionsOperation alloc] init];
        modifyOperation.subscriptionIDsToDelete = @[SPRSubscriptionIDIncomingMessages];
        
        modifyOperation.modifySubscriptionsCompletionBlock = ^(NSArray *savedSubscriptions, NSArray *deletedSubscriptionIDs, NSError *error) {
            // right now subscription errors fail silently.
            if (!error) {
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:SPRSubscriptionID];
            }
        };
        
        [self.publicDatabase addOperation:modifyOperation];
    }
}

- (BOOL)isSubscribed {
    return [[NSUserDefaults standardUserDefaults] boolForKey:SPRSubscriptionID];
}

#pragma mark - Messaging

// Does the work of "sending the message" e.g. Creating the message record.
- (void) sendMessage:(NSString *)message withImageURL:(NSURL *)imageURL toUserRecordID:(CKRecordID*)userRecordID withCompletionHandler:(void (^)(NSError *error)) completionHandler {
    // if we somehow don't have an active user record ID, raise an error about the iCloud account
    if (!self.activeUserRecordID) {
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
    
#warning This probably wouldn't fly through review. Shouldn't store personal info with a record like this. Probably want to do a username instead.
    record[SPRMessageSenderFirstNameField] = self.activeUserInfo.firstName;
    
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
- (void) fetchNewMessagesWithCompletionHandler:(void (^)(NSArray *messages, NSError *error)) completionHandler {
    CKFetchNotificationChangesOperation *operation = [[CKFetchNotificationChangesOperation alloc] initWithPreviousServerChangeToken:self.serverChangeToken];
    NSMutableArray *notifications = [@[] mutableCopy];
    operation.notificationChangedBlock = ^ (CKNotification *notification) {
        [notifications addObject:notification];
    };
    operation.fetchNotificationChangesCompletionBlock = ^ (CKServerChangeToken *serverChangeToken, NSError *operationError) {
        NSError *theError = nil;
        if (operationError) {
            theError = [self simpleCloudMessengerErrorForError:operationError];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completionHandler) {
                    // theError will either be an error or nil, so we can always pass it in
                    completionHandler(nil, theError);
                }
            });
        } else {
            
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:serverChangeToken];
            [[NSUserDefaults standardUserDefaults] setObject:data forKey:SPRServerChangeToken];
            
            NSMutableArray *recordIDStrings = [[notifications valueForKeyPath:@"recordFields.sender"] mutableCopy];
            
            [recordIDStrings removeObjectIdenticalTo:[NSNull null]];
            NSMutableArray *recordIDs = [@[] mutableCopy];
            for (NSString *recordIDString in recordIDStrings) {
                [recordIDs addObject:[[CKRecordID alloc]initWithRecordName:recordIDString]];
            }
            CKDiscoverUserInfosOperation *fetchSendersOperation = [[CKDiscoverUserInfosOperation alloc] initWithEmailAddresses:nil userRecordIDs:[recordIDs copy]];
            fetchSendersOperation.discoverUserInfosCompletionBlock = ^ (NSDictionary *emailsToUserInfos, NSDictionary *userRecordIDsToUserInfos, NSError *operationalError) {
                
                NSMutableArray *objects = [@[] mutableCopy];
                for (CKQueryNotification *notification in notifications) {
                    NSString *recordIDString = notification.recordFields[SPRMessageSenderField];
                    if (recordIDString) {
                        CKRecordID *recordID = [[CKRecordID alloc] initWithRecordName:notification.recordFields[SPRMessageSenderField]];
                        SPRMessage *message = [[SPRMessage alloc] initWithNotification:notification
                                                                          senderInfo:userRecordIDsToUserInfos[recordID]];
                        [objects addObject:message];
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completionHandler) {
                        // error will either be an error or nil, so we can always pass it in
                        completionHandler([objects copy], operationalError);
                    }
                });
            };

            [self.container addOperation:fetchSendersOperation];
        }
    };
    [self.container addOperation:operation];
}

- (void) fetchDetailsForMessage:(SPRMessage *)message withCompletionHandler:(void (^)(SPRMessage *message, NSError *error)) completionHandler {
    [self.publicDatabase fetchRecordWithID:message.messageRecordID completionHandler:^(CKRecord *record, NSError *error) {
        if (!error) {
            [message updateMessageWithMessageRecord:record];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) {
                // error will either be an error or nil, so we can always pass it in
                completionHandler(message, error);
            }
        });
    }];
}

- (void) messageForQueryNotification:(CKQueryNotification *) notification withCompletionHandler:(void (^)(SPRMessage *message, NSError *error)) completionHandler {
    [self.container discoverUserInfoWithUserRecordID:[[CKRecordID alloc] initWithRecordName:notification.recordFields[SPRMessageSenderField]] completionHandler:^(CKDiscoveredUserInfo *userInfo, NSError *error) {
        NSError *theError = nil;
        SPRMessage *message = nil;
        if (error) {
            theError = [self simpleCloudMessengerErrorForError:error];
        } else {
            message = [[SPRMessage alloc] initWithNotification:notification senderInfo:userInfo];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) {
                // error will either be an error or nil, so we can always pass it in
                completionHandler(message, error);
            }
        });
    }];
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

- (CKServerChangeToken *) serverChangeToken {
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:SPRServerChangeToken];
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}

@end
