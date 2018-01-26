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

+(BOOL) isKeyValid:(NSString*)key{
    return [key compare:SPRMessageImageField options:NSCaseInsensitiveSearch] != NSOrderedSame &&
    [key compare:SPRMessageSenderField options:NSCaseInsensitiveSearch] != NSOrderedSame &&
    [key compare:SPRMessageSenderFirstNameField options:NSCaseInsensitiveSearch] != NSOrderedSame &&
    [key compare:SPRMessageReceiverField options:NSCaseInsensitiveSearch] != NSOrderedSame;
}

+(BOOL) isScalar:(id)obj{
    return [obj isKindOfClass:[NSString class]] ||
    [obj isKindOfClass:[NSNumber class]] ||
    [obj isKindOfClass:[NSDate class]];
}

- (id) initWithNotification:(CKQueryNotification *) notification{
    self = [super init];
    if (!self) return nil;

    _messageText = notification.recordFields[SPRMessageTextField];
    _senderInfo = nil;
    _senderRecordID = [[CKRecordID alloc] initWithRecordName:notification.recordFields[SPRMessageSenderField]];
    _messageRecordID = notification.recordID;
    return self;
}

-(NSString*) senderFirstName{
    return [_senderInfo objectForKey:@"firstName"];
}

-(NSString*) senderLastName{
    return [_senderInfo objectForKey:@"lastName"];
}

-(void) fetchDetailsWithCompletionHandler:(void (^)(NSError *error))completionHandler{
    if(_senderInfo && _messageData){
        // we already have details
        completionHandler(nil);
        return;
    }
    
    // Do something with the message, like pushing it onto the stack
    [[SPRSimpleCloudKitManager sharedManager] fetchDetailsForMessage:self withCompletionHandler:^(SPRMessage *message, NSError *error) {
        if(completionHandler)completionHandler(error);
    }];
}

#pragma mark - Protected

// these methods are only called by the SPRSimpleCloudKitManager

-(void) updateMessageWithSenderInfo:(CKDiscoveredUserInfo*)sender{
    _senderInfo = [sender asDictionary];
}

- (void) updateMessageWithMessageRecord:(CKRecord*) messageRecord {
    self.messageText = messageRecord[SPRMessageTextField];
    
    CKAsset *imageAsset = messageRecord[SPRMessageImageField];
    _messageData = imageAsset.fileURL;
    
    NSMutableDictionary* additionalAttributes = [NSMutableDictionary dictionary];
    
    for(NSString* key in [messageRecord allKeys]){
        if([SPRMessage isKeyValid:key]){
            id obj = [messageRecord objectForKey:key];
            if([SPRMessage isScalar:obj]){
                [additionalAttributes setValue:obj forKey:key];
            }
        }
    }
    _attributes = [NSDictionary dictionaryWithDictionary:additionalAttributes];
}


#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        _messageText = [decoder decodeObjectForKey:SPRMessageTextField];
        _messageData = [decoder decodeObjectForKey:SPRMessageImageField];
        _senderInfo = [decoder decodeObjectForKey:SPRMessageSenderField];
        
        NSData *data = [decoder decodeObjectForKey:@"senderID"];
        _senderRecordID = [NSKeyedUnarchiver unarchiveObjectWithData:data];

        data = [decoder decodeObjectForKey:@"recordID"];
        _messageRecordID = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        _attributes = [decoder decodeObjectForKey:@"attributes"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:_messageText forKey:SPRMessageTextField]; 
    [encoder encodeObject:_messageData forKey:SPRMessageImageField];
    [encoder encodeObject:_senderInfo forKey:SPRMessageSenderField];
    if(_attributes){
        [encoder encodeObject:_attributes forKey:@"attributes"];
    }else{
        [encoder encodeObject:@{} forKey:@"attributes"];
    }
    
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
