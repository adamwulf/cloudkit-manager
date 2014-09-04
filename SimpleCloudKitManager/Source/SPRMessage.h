//
//  SPRMessage.h
//  Simple CloudKit Messenger Sample
//
//  Created by Bob Spryn on 7/27/14.
//  Copyright (c) 2014 Sprynthesis. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CloudKit/CloudKit.h>

@interface SPRMessage : NSObject <NSCoding>

// URL to local file of opaque binary blob data of the message
@property (nonatomic, strong, readonly) NSURL *messageData;
@property (nonatomic, strong, readonly) CKRecordID *messageRecordID;

@property (nonatomic, copy, readonly) NSString *senderFirstName;
@property (nonatomic, copy, readonly) NSString *senderLastName;
@property (nonatomic, strong, readonly) CKRecordID *senderRecordID;
@property (nonatomic, strong, readonly) NSDictionary *attributes;

- (id) initWithNotification:(CKQueryNotification *) notification;

-(void) updateMessageWithSenderInfo:(CKDiscoveredUserInfo*)sender;
- (void) updateMessageWithMessageRecord:(CKRecord*) messageRecord;

+(BOOL) isKeyValid:(NSString*)key;
+(BOOL) isScalar:(id)obj;

@end
