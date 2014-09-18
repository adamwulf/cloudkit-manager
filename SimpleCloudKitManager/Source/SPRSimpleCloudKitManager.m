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
#import "SPRMessage+Protected.h"

@interface SPRSimpleCloudKitManager ()

// logged in user account, if any
@property (nonatomic, assign) SCKMAccountStatus accountStatus;
@property (nonatomic, assign) SCKMApplicationPermissionStatus permissionStatus;
@property (nonatomic, strong) CKRecordID *accountRecordID;
@property (nonatomic, strong) CKDiscoveredUserInfo *accountInfo;

@property (readonly) CKContainer *container;
@property (readonly) CKDatabase *publicDatabase;
@property (nonatomic, strong) CKServerChangeToken *serverChangeToken;

@end

@implementation SPRSimpleCloudKitManager{
    BOOL subscribeIsInFlight;
    CKFetchNotificationChangesOperation *mostRecentFetchNotification;
}

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
    // first, see if we have an iCloud account at all
    [self.container accountStatusWithCompletionHandler:^(CKAccountStatus accountStatus, NSError *error) {
//#ifdef DEBUG
//        [NSThread sleepForTimeInterval:3];
//#endif
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
                [self.container statusForApplicationPermission:CKApplicationPermissionUserDiscoverability
                                             completionHandler:^(CKApplicationPermissionStatus applicationPermissionStatus, NSError *error) {
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
- (void) promptAndFetchUserInfoOnComplete:(void (^)(SCKMApplicationPermissionStatus permissionStatus, CKRecordID *recordID, CKDiscoveredUserInfo * userInfo, NSError *error)) completionHandler {
        [self promptToBeDiscoverableIfNeededOnComplete:^(SCKMApplicationPermissionStatus applicationPermissionStatus, NSError *error) {
            if (error) {
                NSLog(@"Prompt Failed");
                if(completionHandler) completionHandler(applicationPermissionStatus, nil, nil, error);
            } else {
                NSLog(@"Prompted to be discoverable");
                [self silentlyFetchUserInfoOnComplete:^(CKRecordID* recordID, CKDiscoveredUserInfo* userInfo, NSError* err){
                    if(completionHandler) completionHandler(applicationPermissionStatus, recordID, userInfo, error);
                }];
            }
        }];
}
// Checks the discoverability of the active user. Prompts if possible, errors if they are in a bad state
- (void) promptToBeDiscoverableIfNeededOnComplete:(void (^)(SCKMApplicationPermissionStatus applicationPermissionStatus, NSError *error)) completionHandler {
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
        // theError will either be an error or nil, so we can always pass it in
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) completionHandler((SCKMApplicationPermissionStatus)applicationPermissionStatus, theError);
        });
    }];
}

-(void) promptForRemoteNotificationsIfNecessary{
    UIUserNotificationSettings* settings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeAlert|UIUserNotificationTypeBadge)
                                                                             categories:nil];
    [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    [[UIApplication sharedApplication] registerForRemoteNotifications];
}

// Fetches the active user CKDiscoveredUserInfo, fairly straightforward
- (void) silentlyFetchUserInfoOnComplete:(void (^)(CKRecordID *recordID, CKDiscoveredUserInfo * userInfo, NSError *error)) completionHandler {
    [self silentlyFetchUserRecordIDOnComplete:^(CKRecordID *recordID, NSError *error) {
        if (error) {
            // don't have to wrap this in GCD main because it's in our internal method on the main queue already
            if(completionHandler) completionHandler(nil, nil, error);
        } else {
            self.accountRecordID = recordID;
            if(self.permissionStatus == SCKMApplicationPermissionStatusGranted){
                [self.container discoverUserInfoWithUserRecordID:recordID completionHandler:^(CKDiscoveredUserInfo *userInfo, NSError *error) {
                    NSError *theError = nil;
                    if (error) {
                        theError = [self simpleCloudMessengerErrorForError:error];
                    } else {
                        self.accountInfo = userInfo;
                    }
                    // theError will either be an error or nil, so we can always pass it in
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if(completionHandler) completionHandler(recordID, userInfo, theError);
                    });
                }];
            }else{
                NSError* theError = [NSError errorWithDomain:SPRSimpleCloudKitMessengerErrorDomain code:SPRSimpleCloudMessengerErrorMissingDiscoveryPermissions userInfo:nil];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if(completionHandler) completionHandler(recordID, nil, theError);
                });
            }
        }
    }];
}

-(void) silentlyFetchUserInfoForUserId:(CKRecordID*)userRecordID onComplete:(void (^)(CKDiscoveredUserInfo *, NSError *))completionHandler{
    if(self.permissionStatus == SCKMApplicationPermissionStatusGranted){
        [self.container discoverUserInfoWithUserRecordID:userRecordID completionHandler:^(CKDiscoveredUserInfo *userInfo, NSError *error) {
            NSError *theError = nil;
            if (error) {
//                NSLog(@"Failed Fetching Active User Info");
                theError = [self simpleCloudMessengerErrorForError:error];
            } else {
//                NSLog(@"Active User Info fetched");
                if([self.accountRecordID isEqual:userRecordID]){
                    self.accountInfo = userInfo;
                }
            }
            // theError will either be an error or nil, so we can always pass it in
            dispatch_async(dispatch_get_main_queue(), ^{
                if(completionHandler) completionHandler(userInfo, theError);
            });
        }];
    }else{
        NSError* theError = [NSError errorWithDomain:SPRSimpleCloudKitMessengerErrorDomain code:SPRSimpleCloudMessengerErrorMissingDiscoveryPermissions userInfo:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            if(completionHandler) completionHandler(nil, theError);
        });
    }
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
            [self subscribeFor:recordID];
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
            if (error.code != CKErrorRequestRateLimited) {
                NSLog(@"fetch friends error: %@", error);
            }
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
- (void)subscribeFor:(CKRecordID*)recordId {
    if (self.subscribed == NO) {
        @synchronized(self){
            if(subscribeIsInFlight){
                return;
            }
            subscribeIsInFlight = YES;
        }
        // find existing subscriptions and deletes them
        [self.publicDatabase fetchSubscriptionWithID:SPRSubscriptionIDIncomingMessages completionHandler:^(CKSubscription *subscription, NSError *error) {
            // this operation silently fails, which is probably the right way to go
            if (subscription) {
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setBool:YES forKey:SPRSubscriptionID];
                _subscribed = YES;
                @synchronized(self){
                    subscribeIsInFlight = NO;
                }
            } else {
                // else if there are no subscriptions, just setup a new one
                NSLog(@"setting up subscription");
                [self setupSubscriptionFor:recordId];
            }
        }];
    }else{
//        NSLog(@"subscribed");
    }
}

- (void) setupSubscriptionFor:(CKRecordID*)recordId {
    // create the subscription
    [self.publicDatabase saveSubscription:[self incomingMessageSubscriptionFor:recordId] completionHandler:^(CKSubscription *subscription, NSError *error) {
        // right now subscription errors fail silently.
        @synchronized(self){
            subscribeIsInFlight = NO;
        }
        if (!error) {
            // when i first create a new subscription, it's because
            // i'm on a brand new database. so clear out any previous
            // server change token, and only use new stuff going forward
            NSLog(@"resetting server changed token from: %@", self.serverChangeToken);
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:SPRServerChangeToken];
            NSLog(@"resetting server changed token to  : %@", self.serverChangeToken);
            // save the subscription ID so we aren't constantly trying to create a new one
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setBool:YES forKey:SPRSubscriptionID];
            _subscribed = YES;
            NSLog(@"subscribe success");
        }else{
            NSLog(@"subscribe fail");
            // can't subscribe, so try again in a bit...
            dispatch_async(dispatch_get_main_queue(), ^{
                [self performSelector:@selector(subscribeFor:) withObject:recordId afterDelay:20];
            });
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

//- (BOOL)isSubscribed {
//    return [[NSUserDefaults standardUserDefaults] boolForKey:SPRSubscriptionID];
//}

- (CKSubscription *) incomingMessageSubscriptionFor:(CKRecordID*)recordId {
    // setup a subscription watching for new messages with the active user as the receiver
    CKReference *receiver = [[CKReference alloc] initWithRecordID:self.accountRecordID action:CKReferenceActionNone];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", SPRMessageReceiverField, receiver];
    CKSubscription *itemSubscription = [[CKSubscription alloc] initWithRecordType:SPRMessageRecordType
                                                                        predicate:predicate
                                                                   subscriptionID:SPRSubscriptionIDIncomingMessages
                                                                          options:CKSubscriptionOptionsFiresOnRecordCreation];
    CKNotificationInfo *notification = [[CKNotificationInfo alloc] init];
    notification.alertLocalizationKey = @"%@ just sent you a page!";
    notification.alertLocalizationArgs = @[SPRMessageSenderFirstNameField];
    notification.desiredKeys = @[SPRMessageSenderFirstNameField, SPRMessageSenderField];
    notification.shouldBadge = YES;
    // currently not well documented, and doesn't seem to actually startup the app in the background as promised.
//    notification.shouldSendContentAvailable = YES;
    itemSubscription.notificationInfo = notification;
    return itemSubscription;
}


#pragma mark - Messaging

// Does the work of "sending the message" e.g. Creating the message record.
// the attributes is a dictionary, and all of the values must be:
// strings, numbers, booleans, dates. no dictionary/array values are allowed.
- (void) sendFile:(NSURL *)imageURL withAttributes:(NSDictionary*)attributes toUserRecordID:(CKRecordID*)userRecordID withProgressHandler:(void (^)(CGFloat progress))progressHandler  withCompletionHandler:(void (^)(NSError *error)) completionHandler {
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
    if (imageURL) {
        CKAsset *asset = [[CKAsset alloc] initWithFileURL:imageURL];
        record[SPRMessageImageField] = asset;
    }
    CKReference *sender = [[CKReference alloc] initWithRecordID:self.accountRecordID action:CKReferenceActionNone];
    record[SPRMessageSenderField] = sender;
    CKReference *receiver = [[CKReference alloc] initWithRecordID:userRecordID action:CKReferenceActionNone];
    record[SPRMessageReceiverField] = receiver;
    record[SPRMessageSenderFirstNameField] = self.accountInfo.firstName;
    
    for(NSString* key in [attributes allKeys]){
        if([SPRMessage isKeyValid:key]){
            id obj = [attributes objectForKey:key];
            if([SPRMessage isScalar:obj]){
                [record setValue:obj forKey:key];
            }
        }
    }

    // save the record, and notify of progress + completion
    CKModifyRecordsOperation* saveOp = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[record] recordIDsToDelete:@[]];
    saveOp.perRecordProgressBlock = ^(CKRecord *record, double progress){
        progressHandler(progress);
    };
    saveOp.perRecordCompletionBlock = ^(CKRecord *record, NSError *error){
        NSLog(@"cloudkit save complete %@", record.recordID);
        NSError *theError = nil;
        if (error) {
            theError = [self simpleCloudMessengerErrorForError:error];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // theError will either be an error or nil, so we can always pass it in
            if(completionHandler) completionHandler(theError);
        });
    };
    [self.publicDatabase addOperation:saveOp];
}

// Method for fetching all new messages
- (void) fetchNewMessagesAndMarkAsReadWithCompletionHandler:(void (^)(NSArray *messages, NSError *error)) completionHandler {
    @synchronized(self){
        if(mostRecentFetchNotification){
            return;
        }
        if(!self.isSubscribed){
            NSError* err = [NSError errorWithDomain:SPRSimpleCloudKitMessengerErrorDomain
                                       code:SPRSimpleCloudMessengerErrorUnexpected
                                   userInfo:@{NSLocalizedDescriptionKey: @"Can't fetch new messages without subscription"}];
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(@[], err);
            });
            return;
        }
        
        CKFetchNotificationChangesOperation *operation = [[CKFetchNotificationChangesOperation alloc] initWithPreviousServerChangeToken:self.serverChangeToken];
        NSMutableArray *incomingMessages = [@[] mutableCopy];
        NSMutableArray* notificationIds = [[NSMutableArray alloc] init];
        operation.notificationChangedBlock = ^ (CKNotification *notification) {
            if([notification isKindOfClass:[CKQueryNotification class]]){
                if(notification.notificationType == CKNotificationTypeQuery){
                    SPRMessage* potentiallyMissedMessage = [[SPRMessage alloc] initWithNotification:(CKQueryNotification*)notification];
                    NSLog(@"new record: %@", potentiallyMissedMessage.messageRecordID);
                    [incomingMessages addObject:potentiallyMissedMessage];
                    [notificationIds addObject:notification.notificationID];
                }
            }
        };
        operation.fetchNotificationChangesCompletionBlock = ^ (CKServerChangeToken *serverChangeToken, NSError *operationError) {
            NSError *theError = nil;
            if (operationError) {
                theError = [self simpleCloudMessengerErrorForError:operationError];
                dispatch_async(dispatch_get_main_queue(), ^{
                    // theError will either be an error or nil, so we can always pass it in
                    if(completionHandler) completionHandler(nil, theError);
                });
            } else {
                if([serverChangeToken isEqual:self.serverChangeToken]){
//                    NSLog(@"same server token, no updates");
                }else{
                    self.serverChangeToken = serverChangeToken;
                    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:serverChangeToken];
                    [[NSUserDefaults standardUserDefaults] setObject:data forKey:SPRServerChangeToken];
                }
                @synchronized(self){
                    mostRecentFetchNotification = nil;
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    // theError will either be an error or nil, so we can always pass it in
                    completionHandler(incomingMessages, theError);
                });
            }
            
            if([notificationIds count]){
//                NSLog(@"askign to set read: %@", notificationIds);
                CKMarkNotificationsReadOperation* markAsRead = [[CKMarkNotificationsReadOperation alloc] initWithNotificationIDsToMarkRead:notificationIds];
                markAsRead.markNotificationsReadCompletionBlock = ^(NSArray *notificationIDsMarkedRead, NSError *operationError){
//                    if(operationError){
//                        NSLog(@"couldn't mark %d as read", (int)[notificationIDsMarkedRead count]);
//                    }else{
//                        NSLog(@"marked %d notifiactions as read", (int)[notificationIDsMarkedRead count]);
//                    }
//                    NSLog(@"result set read: %@", notificationIds);
                };
                [self.container addOperation:markAsRead];
            }
        };
        mostRecentFetchNotification = operation;
        [self.container addOperation:operation];
    }
}

- (void) fetchDetailsForMessage:(SPRMessage *)message withCompletionHandler:(void (^)(SPRMessage *message, NSError *error)) completionHandler {
    // first fetch the sender information
    [self.container discoverUserInfoWithUserRecordID:message.senderRecordID completionHandler:^(CKDiscoveredUserInfo *userInfo, NSError *error) {
        NSError *theError = nil;
        if (error) {
            theError = [self simpleCloudMessengerErrorForError:error];
            dispatch_async(dispatch_get_main_queue(), ^{
                // error will either be an error or nil, so we can always pass it in
                if(completionHandler) completionHandler(message, theError);
            });
        } else {
            // next fetch the binary data
            [message updateMessageWithSenderInfo:userInfo];
            
            NSLog(@"fetching message: %@", message.messageRecordID);
            if(message.messageRecordID){
                CKFetchRecordsOperation* fetchOperation = [[CKFetchRecordsOperation alloc] initWithRecordIDs:@[message.messageRecordID]];
//#ifdef DEBUG
//                __weak CKFetchRecordsOperation* weakFetchOp = fetchOperation;
//#endif
                fetchOperation.perRecordProgressBlock = ^(CKRecordID *record, double progress){
                    NSLog(@"per record progress %f", progress);
                    
//#ifdef DEBUG
//                    if(progress > .5 && !weakFetchOp.isCancelled){
//                        if(rand() % 100 < 15){
//                            [weakFetchOp cancel];
//                        }
//                    }
//#endif
                };
                fetchOperation.perRecordCompletionBlock = ^(CKRecord *record, CKRecordID *recordID, NSError *error){
                    NSLog(@"per record completion");
                };
                fetchOperation.fetchRecordsCompletionBlock = ^(NSDictionary* records, NSError* error){
                    CKRecord* record = [records objectForKey:message.messageRecordID];
                    NSError *theError = nil;
                    if (!error) {
                        [message updateMessageWithMessageRecord:record];
                    }else{
                        theError = [self simpleCloudMessengerErrorForError:error];
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // error will either be an error or nil, so we can always pass it in
                        if(completionHandler) completionHandler(message, theError);
                    });
                };
                [self.publicDatabase addOperation:fetchOperation];
            }else{
                if(completionHandler) completionHandler(nil, [NSError errorWithDomain:SPRSimpleCloudKitMessengerErrorDomain code:SPRSimpleCloudMessengerErrorUnexpected userInfo:nil]);
            }
        }
    }];
}

- (void) messageForQueryNotification:(CKQueryNotification *)notification withCompletionHandler:(void (^)(SPRMessage *message, NSError *error)) completionHandler {
    SPRMessage* message = [[SPRMessage alloc] initWithNotification:notification];
    NSLog(@"was pushed %@", message.messageRecordID);
    completionHandler(message, nil);
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
        case CKErrorRequestRateLimited:
            return SPRSimpleCloudMessengerErrorRateLimit;
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
