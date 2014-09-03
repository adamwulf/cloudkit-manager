//
//  SPRMessage.m
//  Simple CloudKit Messenger Sample
//
//  Created by Bob Spryn on 7/27/14.
//  Copyright (c) 2014 Sprynthesis. All rights reserved.
//

#import "SPRMessage.h"
#import "SPRSimpleCloudKitManager.h"

@implementation SPRMessage

- (id) initWithNotification:(CKQueryNotification *) notification{
    self = [super init];
    if (!self) return nil;
    
    _messageText = notification.recordFields[SPRMessageTextField];
    _senderFirstName = nil;
    _senderLastName = nil;
    _senderRecordID = [[CKRecordID alloc] initWithRecordName:notification.recordFields[SPRMessageSenderField]];
    _messageRecordID = notification.recordID;
    return self;
}

-(void) updateMessageWithSenderInfo:(CKDiscoveredUserInfo*)sender{
    _senderFirstName = sender.firstName;
    _senderLastName = sender.lastName;
}

- (void) updateMessageWithMessageRecord:(CKRecord*) messageRecord {
    _messageText = messageRecord[SPRMessageTextField];
    CKAsset *imageAsset = messageRecord[SPRMessageImageField];
    _messageData = imageAsset.fileURL;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        _messageText = [decoder decodeObjectForKey:SPRMessageTextField];
        _messageData = [decoder decodeObjectForKey:SPRMessageImageField];
        _senderFirstName = [decoder decodeObjectForKey:SPRMessageSenderFirstNameField];
        _senderLastName = [decoder decodeObjectForKey:@"lastName"];
        
        NSData *data = [decoder decodeObjectForKey:@"senderID"];
        _senderRecordID = [NSKeyedUnarchiver unarchiveObjectWithData:data];

        data = [decoder decodeObjectForKey:@"recordID"];
        _messageRecordID = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:_messageText forKey:SPRMessageTextField];
    [encoder encodeObject:_messageData forKey:SPRMessageImageField];
    [encoder encodeObject:_senderFirstName forKey:SPRMessageSenderFirstNameField];
    [encoder encodeObject:_senderLastName forKey:@"lastName"];
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_senderRecordID];
    [encoder encodeObject:data forKey:@"senderID"];
    
    data = [NSKeyedArchiver archivedDataWithRootObject:_messageRecordID];
    [encoder encodeObject:data forKey:@"recordID"];
}


#pragma mark - NSObject

-(NSString*) description{
    return [NSString stringWithFormat:@"[SPRMessage: %@", self.messageRecordID];
}

-(BOOL) isEqual:(id)object{
    if(object == self) return YES;
    if([object isKindOfClass:[SPRMessage class]]){
        return [self.messageRecordID isEqual:[object messageRecordID]];
    }
    return NO;
}

@end
