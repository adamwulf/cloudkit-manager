//
//  SPRMessageViewController.m
//  Simple CloudKit Messenger Sample
//
//  Created by Jen Dron on 6/27/14.
//  Copyright (c) 2014 Sprynthesis. All rights reserved.
//

#import "SPRMessageViewController.h"
#import "SPRSimpleCloudKitMessenger.h"

@interface SPRMessageViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;

@end

@implementation SPRMessageViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (!self.message.messageImage) {
        [[SPRSimpleCloudKitMessenger sharedMessenger] fetchDetailsForMessage:self.message withCompletionHandler:^(SPRMessage *message, NSError *error) {
            self.messageLabel.text = message.messageText;
            self.imageView.image = message.messageImage;
        }];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
