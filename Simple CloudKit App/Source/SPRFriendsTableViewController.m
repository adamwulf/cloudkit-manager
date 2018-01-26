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
        NSPersonNameComponents *nameComponentsObject = nil;
        if([evaluatedObject isKindOfClass:[CKUserIdentity class]])
        {
            nameComponentsObject = [(CKUserIdentity*)evaluatedObject nameComponents];
            return [nameComponentsObject givenName] != nil;
        }
        else
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


    [[SPRSimpleCloudKitManager sharedManager] silentlyVerifyiCloudAccountStatusOnComplete:^(SCKMAccountStatus accountStatus, SCKMApplicationPermissionStatus permissionStatus, NSError *error) {
        if(accountStatus == SCKMAccountStatusAvailable){
            NSLog(@"logged in as a real user");
            [[SPRSimpleCloudKitManager sharedManager] discoverAllFriendsWithCompletionHandler:^(NSArray *friendRecords, NSError *error) {
                if (error) {
                    [[[UIAlertView alloc] initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                } else {
                    self.friends = [self filteredArrayOfFriendRecords:friendRecords];
                    [self.tableView reloadData];
                }
            }];
        }else{
            NSLog(@"not logged in at all");
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
    if([userInfo isKindOfClass:[CKUserIdentity class]])
    {
        NSPersonNameComponents *nameComponentsObject = nil;
        nameComponentsObject = [(CKUserIdentity*)userInfo nameComponents];
        cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", [nameComponentsObject givenName], [nameComponentsObject familyName]];
    }
    else
        cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", userInfo.firstName, userInfo.lastName];
    return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    __block NSString *usetEnteredText = nil;
    UIAlertController * alertController = [UIAlertController alertControllerWithTitle: @"Chat Message"
                                                                              message: @"Enter a chat text message to send"
                                                                       preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Chat Text";
        textField.textColor = [UIColor blueColor];
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.borderStyle = UITextBorderStyleRoundedRect;
    }];
    UIAlertAction *cancelAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel action")
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction *action)
                                   {
                                       NSLog(@"Cancel Chat action ");
                                   }];
    [alertController addAction:cancelAction];   // make the cancwl button appear first
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSArray * textfields = alertController.textFields;
        UITextField *userTextfield = textfields[0];
        NSLog(@"%@",userTextfield.text);
        usetEnteredText = userTextfield.text;
        
        CKDiscoveredUserInfo *userInfo = self.friends[indexPath.row];
        NSString * bundleImagePath = [[NSBundle mainBundle] pathForResource:@"Michael" ofType:@"jpg"];
        NSURL *imageURL = [NSURL fileURLWithPath:bundleImagePath];
        if([usetEnteredText length] || imageURL != nil)
        {
            [[SPRSimpleCloudKitManager sharedManager] sendMessage:usetEnteredText withFile:imageURL withAttributes:nil toUserRecordID:userInfo.userRecordID withProgressHandler:nil withCompletionHandler:^(NSError *error) {
                if (error) {
                    [[[UIAlertView alloc] initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
                } else {
                    [[[UIAlertView alloc] initWithTitle:@"Success!" message:@"Message sent" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
                }
            }];
        }
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
    
    [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
}

@end
