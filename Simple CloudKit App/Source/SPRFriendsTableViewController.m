//
//  SPRFriendsTableViewController.m
//  Simple CloudKit Messenger Sample
//
//  Created by Bob Spryn on 6/13/14.
//  Copyright (c) 2014 Sprynthesis. All rights reserved.
//

@import CloudKit;

#import "SPRFriendsTableViewController.h"
#import <SimpleCloudKitManager/SPRSimpleCloudKitManager.h>

@interface SPRFriendsTableViewController ()
@property (nonatomic, strong) NSArray *friends;
@end

@implementation SPRFriendsTableViewController

- (instancetype)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        self.friends = @[];
    }
    return self;
}

-(NSArray*) filteredArrayOfFriendRecords:(NSArray*)friendRecords{
    return [friendRecords filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [evaluatedObject firstName] != nil;
    }]];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    UITableView* tv = (UITableView*) self.view;
    tv.dataSource = self;
    tv.delegate = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];
    
    if([SPRSimpleCloudKitManager sharedMessenger].isActiveUserForCloudKit){
        NSLog(@"logged in as a real user");
    }else{
        NSLog(@"not logged in at all");
    }
    
    [[SPRSimpleCloudKitManager sharedMessenger] discoverAllFriendsWithCompletionHandler:^(NSArray *friendRecords, NSError *error) {
        if (error) {
            [[[UIAlertView alloc] initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        } else {
            self.friends = [self filteredArrayOfFriendRecords:friendRecords];
            [self.tableView reloadData];
        }
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.friends.count;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"UITableViewCell"];
    CKDiscoveredUserInfo *userInfo = self.friends[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", userInfo.firstName, userInfo.lastName];
    return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CKDiscoveredUserInfo *userInfo = self.friends[indexPath.row];
    NSString * bundleImagePath = [[NSBundle mainBundle] pathForResource:@"Michael" ofType:@"jpg"];
    NSURL *imageURL = [NSURL fileURLWithPath:bundleImagePath];
    [[SPRSimpleCloudKitManager sharedMessenger] sendMessage:@"Holy Cow" withImageURL:imageURL toUserRecordID:userInfo.userRecordID withCompletionHandler:^(NSError *error) {
        if (error) {
            [[[UIAlertView alloc] initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
        } else {
            [[[UIAlertView alloc] initWithTitle:@"Success!" message:@"Message sent" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
        }
    }];
    [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
}

@end
