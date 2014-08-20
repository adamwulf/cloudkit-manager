//
//  SPRTabViewController.m
//  Simple CloudKit Messenger Sample
//
//  Created by Adam Wulf on 8/20/14.
//  Copyright (c) 2014 Sprynthesis. All rights reserved.
//

#import "SPRTabViewController.h"
#import "SPRFriendsTableViewController.h"
#import "SPRInboxTableViewController.h"

@interface SPRTabViewController ()

@end

@implementation SPRTabViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // setup all tabs
    
    SPRFriendsTableViewController* friendList = [[SPRFriendsTableViewController alloc] initWithStyle:UITableViewStylePlain];
    UINavigationController* friendNav = [[UINavigationController alloc] initWithRootViewController:friendList];
    friendNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemContacts tag:0];
    
    SPRInboxTableViewController* inboxList = [[SPRInboxTableViewController alloc] initWithStyle:UITableViewStylePlain];
    UINavigationController* inboxNav = [[UINavigationController alloc] initWithRootViewController:inboxList];
    inboxNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Inbox" image:nil tag:1];
    
    self.viewControllers = @[friendNav, inboxNav];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
