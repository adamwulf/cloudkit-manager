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
    [[SPRSimpleCloudKitMessenger sharedMessenger] fetchNewMessagesWithCompletionHandler:^(NSDictionary *messagesByID, NSError *error) {
        self.messages = [self.messages arrayByAddingObjectsFromArray:[messagesByID allValues]];
        [self.tableView reloadData];
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
    CKRecord *message = self.messages[indexPath.row];
    cell.textLabel.text = message[@"text"];
    return cell;
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSUInteger index = [self.tableView indexPathForCell:(UITableViewCell *) sender].row;
    ((SPRMessageViewController *)segue.destinationViewController).messageRecord = self.messages[index];
}


@end
