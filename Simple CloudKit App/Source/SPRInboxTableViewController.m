//
//  SPRInboxTableViewController.m
//  Simple CloudKit Messenger Sample
//
//  Created by Bob Spryn on 6/20/14.
//  Copyright (c) 2014 Sprynthesis. All rights reserved.
//

#import "SPRInboxTableViewController.h"
#import <SimpleCloudKitManager/SPRSimpleCloudKitManager.h>
#import "SPRMessageViewController.h"

@interface SPRInboxTableViewController ()
@property (nonatomic, strong) NSArray *messages;
@end

@implementation SPRInboxTableViewController

-(instancetype) initWithStyle:(UITableViewStyle)style{
    self = [super initWithStyle:style];
    if (!self) return nil;
    self.messages = @[];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    UITableView* tv = (UITableView*) self.view;
    tv.dataSource = self;
    tv.delegate = self;
    
    [tv registerClass:[UITableViewCell class] forCellReuseIdentifier:@"SPRMessageCell"];


    [[SPRSimpleCloudKitManager sharedManager] fetchNewMessagesAndMarkAsReadWithCompletionHandler:^(NSArray *messages, NSError *error) {
        self.messages = [self.messages arrayByAddingObjectsFromArray:messages];
        [self.tableView reloadData];
    }];
    
    self.refreshControl = [[UIRefreshControl alloc]init];
    [tv addSubview:self.refreshControl];
    [self.refreshControl addTarget:self action:@selector(refreshView:) forControlEvents:UIControlEventValueChanged];
}

- (void)refreshView:(UIRefreshControl *)sender {
    // Do something...
    [[SPRSimpleCloudKitManager sharedManager] fetchNewMessagesAndMarkAsReadWithCompletionHandler:^(NSArray *messages, NSError *error) {
        NSLog(@"finished fetching messages, in inbox controller");
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
    if([message.messageText length])
        cell.textLabel.text = message.messageText;
    else
        cell.textLabel.text = [message.messageData path];
    return cell;
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSUInteger index = [self.tableView indexPathForCell:(UITableViewCell *) sender].row;
    ((SPRMessageViewController *)segue.destinationViewController).message = self.messages[index];
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    SPRMessageViewController* messageVC =[[SPRMessageViewController alloc] init];
    messageVC.message = self.messages[indexPath.row];
    [self.navigationController pushViewController:messageVC animated:YES];
}


@end
