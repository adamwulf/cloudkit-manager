//
//  MMMockDiscoveredUser.m
//  LooseLeaf
//
//  Created by Adam Wulf on 10/2/14.
//  Copyright (c) 2014 Milestone Made, LLC. All rights reserved.
//

#import "SPRMockDiscoveredUser.h"

@implementation SPRMockDiscoveredUser{
    CKRecordID* userRecordID;
    NSString* firstName;
    NSString* lastName;
}

@synthesize userRecordID;
@synthesize firstName;
@synthesize lastName;

-(id) initWithRecord:(CKRecordID*)recId andFirstName:(NSString*)first andLastName:(NSString*)last{
    if(self = [super init]){
        userRecordID = recId;
        firstName = first;
        lastName = last;
    }
    return self;
}


-(NSString*) initials{
    NSString* firstLetter = self.firstName.length > 1 ? [self.firstName substringToIndex:1] : @"";
    NSString* lastLetter = self.lastName.length > 1 ? [self.lastName substringToIndex:1] : @"";
    return [firstLetter stringByAppendingString:lastLetter];
}

-(NSDictionary*) asDictionary{
    if(self.userRecordID){
        return @{
                 @"recordId" : self.userRecordID,
                 @"firstName" : self.firstName ? self.firstName : @"",
                 @"lastName" : self.lastName ? self.lastName : @"",
                 @"initials" : self.initials
                 };
    }else{
        return @{};
    }
}

@end
