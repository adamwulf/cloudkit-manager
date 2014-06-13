//
//  SPRFriendsTableViewController.m
//  Simple CloudKit Messenger Sample
//
//  Created by Bob Spryn on 6/13/14.
//  Copyright (c) 2014 Sprynthesis. All rights reserved.
//

@import CloudKit;

#import "SPRFriendsTableViewController.h"
#import "SPRSimpleCloudKitMessenger.h"

@interface SPRFriendsTableViewController ()
@property (nonatomic, strong) NSArray *friends;
@end

@implementation SPRFriendsTableViewController

- (instancetype)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
        self.friends = @[];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];
    
    [[SPRSimpleCloudKitMessenger sharedMessenger] discoverAllFriendsWithCompletionHandler:^(NSArray *friendRecords, NSError *error) {
        if (error) {
            //alert
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.friends = friendRecords;
                [self.tableView reloadData];
            });
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

@end
