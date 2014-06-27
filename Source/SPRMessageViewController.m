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
    [[SPRSimpleCloudKitMessenger sharedMessenger] fetchDetailForMessageRecord:self.messageRecord withCompletionHandler:^(CKRecord *messageRecord, NSError *error) {
        self.messageLabel.text = messageRecord[SPRMessageTextField];
        CKAsset *imageAsset = messageRecord[SPRMessageImageField];
        NSData *imageData = [NSData dataWithContentsOfURL:imageAsset.fileURL];
        UIImage *image = [UIImage imageWithData:imageData];
        self.imageView.image = image;
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
