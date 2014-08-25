//
//  SPRSimpleCloudKitMessenger.m
//  CloudKit Manager
//
//  Created by Bob Spryn on 6/11/14.
//  Copyright (c) 2014 Sprynthesis. All rights reserved.
//

#import "SPRSimpleCloudKitManager.h"
#import <CloudKit/CloudKit.h>
#import "SPRMessage.h"

@interface SPRSimpleCloudKitManager ()

// logged in user account, if any
@property (nonatomic, assign) SCKMAccountStatus accountStatus;
@property (nonatomic, assign) SCKMApplicationPermissionStatus permissionStatus;
@property (nonatomic, strong) CKRecordID *accountRecordID;
@property (nonatomic, strong) CKDiscoveredUserInfo *accountInfo;

@property (readonly) CKContainer *container;
@property (readonly) CKDatabase *publicDatabase;
@property (nonatomic, getter=isSubscribed) BOOL subscribed;
@property (nonatomic, strong) CKServerChangeToken *serverChangeToken;

@end

@implementation SPRSimpleCloudKitManager

- (id)init {
    self = [super init];
    if (self) {
        _container = [CKContainer defaultContainer];
        _publicDatabase = [_container publicCloudDatabase];
        
        if(!_container.containerIdentifier){
            NSLog(@"no container");
            _container = nil;
            return nil;
        }
    }
    return self;
}

+ (SPRSimpleCloudKitManager *) sharedManager {
    static dispatch_once_t onceToken;
    static SPRSimpleCloudKitManager *messenger;
    dispatch_once(&onceToken, ^{
        messenger = [[SPRSimpleCloudKitManager alloc] init];
    });
    return messenger;
}

-(void) reset{
    self.accountStatus = SCKMAccountStatusCouldNotDetermine;
    self.permissionStatus = SCKMApplicationPermissionStatusCouldNotComplete;
    self.accountInfo = nil;
    self.accountRecordID = nil;
}

#pragma mark - Account status and discovery

// Verifies iCloud Account Status and that the iCloud ubiquityIdentityToken hasn't changed
- (void) silentlyVerifyiCloudAccountStatusOnComplete:(void (^)(SCKMAccountStatus accountStatus, SCKMApplicationPermissionStatus permissionStatus, NSError *error)) completionHandler {
    NSLog(@"silently asking");
    // first, see if we have an iCloud account at all
    [self.container accountStatusWithCompletionHandler:^(CKAccountStatus accountStatus, NSError *error) {
        _accountStatus = (SCKMAccountStatus) accountStatus;
        
        __block NSError *theError = nil;
        if (error) {
            theError = [self simpleCloudMessengerErrorForError:error];
            self.permissionStatus = SCKMApplicationPermissionStatusCouldNotComplete;
            dispatch_async(dispatch_get_main_queue(), ^{
                // theError will either be an error or nil, so we can always pass it in
                if(completionHandler) completionHandler(self.accountStatus, self.permissionStatus, theError);
            });
        } else {
            // if it's not a valid account raise an error
            if (accountStatus != CKAccountStatusAvailable) {
                NSString *errorString = [self simpleCloudMessengerErrorStringForErrorCode:SPRSimpleCloudMessengerErroriCloudAccount];
                theError = [NSError errorWithDomain:SPRSimpleCloudKitMessengerErrorDomain
                                               code:SPRSimpleCloudMessengerErroriCloudAccount
                                           userInfo:@{NSLocalizedDescriptionKey: errorString }];
                self.permissionStatus = SCKMApplicationPermissionStatusCouldNotComplete;
                dispatch_async(dispatch_get_main_queue(), ^{
                    // theError will either be an error or nil, so we can always pass it in
                    if(completionHandler) completionHandler(self.accountStatus, self.permissionStatus, theError);
                });
            } else {
                // grab the ubiquityIdentityToken
                // if it's a different ubiquityIdentityToken than previously stored, raise an error
                // so the developer can clear sensitive data
                id currentiCloudToken = [[NSFileManager defaultManager] ubiquityIdentityToken];
                id previousiCloudToken = [[NSUserDefaults standardUserDefaults] objectForKey:SPRActiveiCloudIdentity];
                if (previousiCloudToken && ![previousiCloudToken isEqual:currentiCloudToken]) {
                    theError = [NSError errorWithDomain:SPRSimpleCloudKitMessengerErrorDomain
                                                   code:SPRSimpleCloudMessengerErroriCloudAccountChanged
                                               userInfo:@{NSLocalizedDescriptionKey:[self simpleCloudMessengerErrorStringForErrorCode:SPRSimpleCloudMessengerErroriCloudAccountChanged]}];
                    // also clear the stored ubiquityIdentityToken, the subscription ID and nil the active user record
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:SPRActiveiCloudIdentity];
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:SPRSubscriptionID];
                    self.accountRecordID = nil;
                } else{
                    // else everything is good, store the ubiquityIdentityToken
                    [[NSUserDefaults standardUserDefaults] setObject:currentiCloudToken forKey:SPRActiveiCloudIdentity];
                }
                NSLog(@"asking about permissions");
                [self.container statusForApplicationPermission:CKApplicationPermissionUserDiscoverability
                                             completionHandler:^(CKApplicationPermissionStatus applicationPermissionStatus, NSError *error) {
                                                 NSLog(@"got reply about permissions");
                                                 // ok, we've got our permission status now
                                                 self.permissionStatus = (SCKMApplicationPermissionStatus) applicationPermissionStatus;
                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                     // theError will either be an error or nil, so we can always pass it in
                                                     if(completionHandler) completionHandler(self.accountStatus, self.permissionStatus, theError);
                                                 });
                }];
            }
        }
    }];
}


// Uses internal methods to do the majority of the setup for this class
// If everything is successful, it returns the active user CKDiscoveredUserInfo
// All internal methods fire completionHandlers on the main thread, so no need to use GCD in this method
- (void) promptAndFetchUserInfoOnComplete:(void (^)(SCKMAccountStatus accountStatus, SCKMApplicationPermissionStatus permissionStatus, CKRecordID *recordID, CKDiscoveredUserInfo * userInfo, NSError *error)) completionHandler {
    [self silentlyVerifyiCloudAccountStatusOnComplete:^(SCKMAccountStatus accountStatus, SCKMApplicationPermissionStatus permissionStatus, NSError *error) {
        if (error) {
            NSLog(@"iCloud Account Could Not Be Verified");
            if(completionHandler) completionHandler(SCKMAccountStatusCouldNotDetermine, SCKMApplicationPermissionStatusCouldNotComplete, nil, nil, error);
        } else {
            NSLog(@"iCloud Account Verified");
            [self promptToBeDiscoverableIfNeededOnComplete:^(NSError *error) {
                if (error) {
                    NSLog(@"Prompt Failed");
                    if(completionHandler) completionHandler(accountStatus, permissionStatus, nil, nil, error);
                } else {
                    NSLog(@"Prompted to be discoverable");
                    [self silentlyFetchUserInfoOnComplete:^(CKRecordID* recordID, CKDiscoveredUserInfo* userInfo, NSError* err){
                        if(completionHandler) completionHandler(accountStatus, permissionStatus, recordID, userInfo, error);
                    }];
                }
            }];
        }
    }];
}
// Checks the discoverability of the active user. Prompts if possible, errors if they are in a bad state
- (void) promptToBeDiscoverableIfNeededOnComplete:(void (^)(NSError *error)) completionHandler {
    [self.container requestApplicationPermission:CKApplicationPermissionUserDiscoverability completionHandler:^(CKApplicationPermissionStatus applicationPermissionStatus, NSError *error) {
        self.permissionStatus = (SCKMApplicationPermissionStatus) applicationPermissionStatus;
        
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
        if(!theError){
            // if we don't have an error, then ask for remote notifications
            UIUserNotificationSettings* settings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeAlert
                                                                                                 |UIUserNotificationTypeSound)
                                                                                     categories:nil];
            [[UIApplication sharedApplication] registerForRemoteNotifications];
            [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        }
        // theError will either be an error or nil, so we can always pass it in
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) completionHandler(theError);
        });
    }];
}

// Fetches the active user CKDiscoveredUserInfo, fairly straightforward
- (void) silentlyFetchUserInfoOnComplete:(void (^)(CKRecordID *recordID, CKDiscoveredUserInfo * userInfo, NSError *error)) completionHandler {
    [self silentlyFetchUserRecordIDOnComplete:^(CKRecordID *recordID, NSError *error) {
        if (error) {
            NSLog(@"Failed fetching Active User ID");
            // don't have to wrap this in GCD main because it's in our internal method on the main queue already
            if(completionHandler) completionHandler(nil, nil, error);
        } else {
            NSLog(@"Active User ID fetched");
            self.accountRecordID = recordID;
            if(self.permissionStatus == SCKMApplicationPermissionStatusGranted){
                [self.container discoverUserInfoWithUserRecordID:recordID completionHandler:^(CKDiscoveredUserInfo *userInfo, NSError *error) {
                    NSError *theError = nil;
                    if (error) {
                        NSLog(@"Failed Fetching Active User Info");
                        theError = [self simpleCloudMessengerErrorForError:error];
                    } else {
                        NSLog(@"Active User Info fetched");
                        self.accountInfo = userInfo;
                    }
                    // theError will either be an error or nil, so we can always pass it in
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if(completionHandler) completionHandler(recordID, userInfo, theError);
                    });
                }];
            }else{
                dispatch_async(dispatch_get_main_queue(), ^{
                    if(completionHandler) completionHandler(recordID, nil, nil);
                });
            }
        }
    }];
}

// fetches the active user record ID and stores it in a property
// also kicks off subscription for messages
- (void) silentlyFetchUserRecordIDOnComplete:(void (^)(CKRecordID *recordID, NSError *error))completionHandler {
    [self.container fetchUserRecordIDWithCompletionHandler:^(CKRecordID *recordID, NSError *error) {
        NSError *theError = nil;
        if (error) {
            theError = [self simpleCloudMessengerErrorForError:error];
        } else {
            self.accountRecordID = recordID;
            [self subscribe];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            // theError will either be an error or nil, so we can always pass it in
            if(completionHandler) completionHandler(recordID, theError);
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
            // theError will either be an error or nil, so we can always pass it in
            if(completionHandler) completionHandler(userInfos, theError);
        });
    }];
}

#pragma mark - Subscription handling
// handles clearing old subscriptions, and setting up the new one
- (void)subscribe {
    if (self.subscribed == NO) {
        // find existing subscriptions and deletes them
        [self.publicDatabase fetchSubscriptionWithID:SPRSubscriptionIDIncomingMessages completionHandler:^(CKSubscription *subscription, NSError *error) {
            // this operation silently fails, which is probably the right way to go
            if (subscription) {
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setBool:YES forKey:SPRSubscriptionID];
            } else {
                // else if there are no subscriptions, just setup a new one
                [self setupSubscription];
            }
        }];
    }
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

- (CKSubscription *) incomingMessageSubscription {
    // setup a subscription watching for new messages with the active user as the receiver
    CKReference *receiver = [[CKReference alloc] initWithRecordID:self.accountRecordID action:CKReferenceActionNone];
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


#pragma mark - Messaging

// Does the work of "sending the message" e.g. Creating the message record.
- (void) sendMessage:(NSString *)message withImageURL:(NSURL *)imageURL toUserRecordID:(CKRecordID*)userRecordID withCompletionHandler:(void (^)(NSError *error)) completionHandler {
    // if we somehow don't have an active user record ID, raise an error about the iCloud account
    if (!self.accountRecordID) {
        NSError *error = [NSError errorWithDomain:SPRSimpleCloudKitMessengerErrorDomain
                                             code:SPRSimpleCloudMessengerErroriCloudAccount
                                         userInfo:@{NSLocalizedDescriptionKey: [self simpleCloudMessengerErrorStringForErrorCode:SPRSimpleCloudMessengerErroriCloudAccount]}];
        dispatch_async(dispatch_get_main_queue(), ^{
            if(completionHandler) completionHandler(error);
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
    CKReference *sender = [[CKReference alloc] initWithRecordID:self.accountRecordID action:CKReferenceActionNone];
    record[SPRMessageSenderField] = sender;
    CKReference *receiver = [[CKReference alloc] initWithRecordID:userRecordID action:CKReferenceActionNone];
    record[SPRMessageReceiverField] = receiver;
    
    record[SPRMessageSenderFirstNameField] = self.accountInfo.firstName;
    
    // save the record
    [self.publicDatabase saveRecord:record completionHandler:^(CKRecord *record, NSError *error) {
        NSError *theError = nil;
        if (error) {
            theError = [self simpleCloudMessengerErrorForError:error];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // theError will either be an error or nil, so we can always pass it in
            if(completionHandler) completionHandler(theError);
        });
    }];
}

// Method for fetching all new messages
- (void) fetchNewMessagesWithCompletionHandler:(void (^)(NSArray *messages, NSError *error)) completionHandler {
    CKFetchNotificationChangesOperation *operation = [[CKFetchNotificationChangesOperation alloc] initWithPreviousServerChangeToken:self.serverChangeToken];
    NSMutableArray *notifications = [@[] mutableCopy];
    operation.notificationChangedBlock = ^ (CKNotification *notification) {
        NSLog(@"notification changed");
        [notifications addObject:notification];
    };
    operation.fetchNotificationChangesCompletionBlock = ^ (CKServerChangeToken *serverChangeToken, NSError *operationError) {
        NSError *theError = nil;
        if (operationError) {
            NSLog(@"notification changed error");
            theError = [self simpleCloudMessengerErrorForError:operationError];
            dispatch_async(dispatch_get_main_queue(), ^{
                // theError will either be an error or nil, so we can always pass it in
                if(completionHandler) completionHandler(nil, theError);
            });
        } else {
            NSLog(@"notification changed complete");
            
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
                    // error will either be an error or nil, so we can always pass it in
                    if(completionHandler) completionHandler([objects copy], operationalError);
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
            // error will either be an error or nil, so we can always pass it in
            if(completionHandler) completionHandler(message, error);
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
            // error will either be an error or nil, so we can always pass it in
            if(completionHandler) completionHandler(message, error);
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
        case SPRSimpleCloudMessengerErroriCloudAccountChanged:
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
    return data ? [NSKeyedUnarchiver unarchiveObjectWithData:data] : nil;
}

@end
