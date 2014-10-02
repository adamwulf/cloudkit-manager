//
//  MMMockDiscoveredUser.h
//  LooseLeaf
//
//  Created by Adam Wulf on 10/2/14.
//  Copyright (c) 2014 Milestone Made, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>

@interface SPRMockDiscoveredUser : NSObject

@property (nonatomic, readonly) CKRecordID* userRecordID;
@property (nonatomic, readonly) NSString* firstName;
@property (nonatomic, readonly) NSString* lastName;

-(id) initWithRecord:(CKRecordID*)recId andFirstName:(NSString*)first andLastName:(NSString*)last;

@end

