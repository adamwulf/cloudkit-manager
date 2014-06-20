//
//  SPRInboxTableViewController.m
//  Simple CloudKit Messenger Sample
//
//  Created by Bob Spryn on 6/20/14.
//  Copyright (c) 2014 Sprynthesis. All rights reserved.
//

#import "SPRInboxTableViewController.h"
#import "SPRSimpleCloudKitMessenger.h"

@interface SPRInboxTableViewController ()

@end

@implementation SPRInboxTableViewController

- (instancetype)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[SPRSimpleCloudKitMessenger sharedMessenger] fetchNewMessagesWithCompletionHandler:^(NSArray *messages, NSError *error) {
        NSLog(@"%@", messages);
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
#warning Potentially incomplete method implementation.
    // Return the number of sections.
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
#warning Incomplete method implementation.
    // Return the number of rows in the section.
    return 0;
}

@end
