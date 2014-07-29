//
//  SPRInboxTableViewController.m
//  Simple CloudKit Messenger Sample
//
//  Created by Bob Spryn on 6/20/14.
//  Copyright (c) 2014 Sprynthesis. All rights reserved.
//

#import "SPRInboxTableViewController.h"
#import "SPRSimpleCloudKitMessenger.h"
#import "SPRMessageViewController.h"
#import "SPRMessage.h"

@interface SPRInboxTableViewController ()
@property (nonatomic, strong) NSArray *messages;
@end

@implementation SPRInboxTableViewController

- (instancetype) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (!self) return nil;
    self.messages = @[];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[SPRSimpleCloudKitMessenger sharedMessenger] fetchNewMessagesWithCompletionHandler:^(NSArray *messages, NSError *error) {
        self.messages = [self.messages arrayByAddingObjectsFromArray:messages];
        [self.tableView reloadData];
    }];
    
    [self.refreshControl addTarget:self action:@selector(refreshView:) forControlEvents:UIControlEventValueChanged];
}

- (void)refreshView:(UIRefreshControl *)sender {
    // Do something...
    [[SPRSimpleCloudKitMessenger sharedMessenger] fetchNewMessagesWithCompletionHandler:^(NSArray *messages, NSError *error) {
        self.messages = [self.messages arrayByAddingObjectsFromArray:messages];
        [self.tableView reloadData];
        [self.refreshControl endRefreshing];
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.messages.count;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"SPRMessageCell"];
    SPRMessage *message = self.messages[indexPath.row];
    cell.textLabel.text = message.messageText;
    return cell;
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSUInteger index = [self.tableView indexPathForCell:(UITableViewCell *) sender].row;
    ((SPRMessageViewController *)segue.destinationViewController).message = self.messages[index];
}


@end
