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
@property (nonatomic, copy) NSString *senderFirstName;
@property (nonatomic, copy) NSString *senderLastName;
@property (nonatomic, copy) NSString *messageText;
@property (nonatomic, strong) UIImage *messageImage;
@property (nonatomic, strong) CKRecordID *senderRecordID;
@property (nonatomic, strong) CKRecordID *messageRecordID;
@end

@implementation SPRMessage

- (id) initWithNotification:(CKQueryNotification *) notification senderInfo:(CKDiscoveredUserInfo *)sender {
    self = [super init];
    if (!self) return nil;
    _messageText = notification.recordFields[SPRMessageTextField];
    _senderFirstName = sender.firstName;
    _senderLastName = sender.lastName;
    _senderRecordID = sender.userRecordID;
    _senderRecordID = notification.recordFields[SPRMessageSenderField];
    _messageRecordID = notification.recordID;
    return self;
}

- (void) updateMessageWithMessageRecord:(CKRecord*) messageRecord {
    self.messageText = messageRecord[SPRMessageTextField];
    CKAsset *imageAsset = messageRecord[SPRMessageImageField];
    NSData *imageData = [NSData dataWithContentsOfURL:imageAsset.fileURL];
    UIImage *image = [UIImage imageWithData:imageData];
    self.messageImage = image;
}

@end
