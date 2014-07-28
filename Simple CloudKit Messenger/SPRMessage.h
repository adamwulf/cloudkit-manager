//
//  SPRMessage.h
//  Simple CloudKit Messenger Sample
//
//  Created by Bob Spryn on 7/27/14.
//  Copyright (c) 2014 Sprynthesis. All rights reserved.
//

@import UIKit;
@import CloudKit;

@interface SPRMessage : NSObject

@property (nonatomic, copy, readonly) NSString *senderFirstName;
@property (nonatomic, copy, readonly) NSString *senderLastName;
@property (nonatomic, copy, readonly) NSString *messageText;
@property (nonatomic, strong, readonly) UIImage *messageImage;

- (id) initWithNotification:(CKQueryNotification *) notification senderRecord:(CKRecord *)sender;

@end
