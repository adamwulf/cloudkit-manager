//
//  SPRMessage+Protected.h
//  SimpleCloudKitManager
//
//  Created by Adam Wulf on 9/10/14.
//  Copyright (c) 2014 Milestone Made, LLC. All rights reserved.
//

#ifndef SimpleCloudKitManager_SPRMessage_Protected_h
#define SimpleCloudKitManager_SPRMessage_Protected_h

//
//  SPRMessage.h
//  Simple CloudKit Messenger Sample
//
//  Created by Bob Spryn on 7/27/14.
//  Copyright (c) 2014 Sprynthesis. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CloudKit/CloudKit.h>

@interface SPRMessage (Protected)

- (void) updateMessageWithSenderInfo:(CKDiscoveredUserInfo*)sender;
- (void) updateMessageWithMessageRecord:(CKRecord*) messageRecord;

+(BOOL) isKeyValid:(NSString*)key;
+(BOOL) isScalar:(id)obj;

@end


#endif
