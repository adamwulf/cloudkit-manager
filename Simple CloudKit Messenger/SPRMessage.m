//
//  SPRMessage.m
//  Simple CloudKit Messenger Sample
//
//  Created by Bob Spryn on 7/27/14.
//  Copyright (c) 2014 Sprynthesis. All rights reserved.
//

#import "SPRMessage.h"
#import "SPRSimpleCloudKitMessenger.h"

@interface SPRMessage ()
@property (nonatomic, strong, readonly) CKRecordID *senderRecordID;
@end

@implementation SPRMessage

- (id) initWithNotification:(CKQueryNotification *) notification senderRecord:(CKRecord *)sender {
    self = [super init];
    if (!self) return nil;
    _messageText = notification.recordFields[SPRMessageTextField];
    _senderFirstName = notification.recordFields[SPRMessageSenderFirstNameField];
    _senderRecordID = notification.recordFields[SPRMessageSenderField];
    return self;
}

@end
