#Cloud Kit Messenger

CloudKitMessenger is a part of [Loose Leaf](https://getlooseleaf.com), and allows for sending text and binary messages between users through CloudKit on iOS.

A simple, functioning example is included showing how to build messaging for your app on top of CloudKit. It allows a user to send and receive messages to and from anyone in their address book who is also using your app (and has allowed themselves to be discoverable.)

This messenger allows your users to send text and an image to their friends who are also using your app. It only has a few methods, and drastically shrinks the amount of error cases you will have to deal with.

## Building

This project builds a static iOS framework bundle.

##Installation

Download or clone the repository, and copy these files to your project:

```
SPRMessage.h
SPRMessage.m
SPRSimpleCloudKitMessenger.h
SPRSimpleCloudKitMessenger.m
```

##Setup

You'll need to configure your iCloud/CloudKit capabilities. If you are running the sample app, you'll need to use a custom container name.

![iCloud Configuration](http://content.screencast.com/users/sprynmr/folders/Snagit/media/d2ad40e9-0ad4-4fd3-9cd1-931064a2d17a/cloudkit.png)

##Basic Usage

###Login

CloudKit doesn't offer an exact equivalent to logging in. If the user is logged into iCloud on their device, they are logged into iCloud as far as your app is concerned.

`verifyAndFetchActiveiCloudUserWithCompletionHandler` is your main entry point. Although the user is already technically logged in, this would be a good method to call from a "Login with iCloud" button. You could store the success of this method in a user default, to know whether you should be able to successfully call other methods.

```Objective-C
- (void) loginAction {
    [[SPRSimpleCloudKitMessenger sharedMessenger] verifyAndFetchActiveiCloudUserWithCompletionHandler:^(CKDiscoveredUserInfo *userInfo, NSError *error) {
        if (error) {
            [[[UIAlertView alloc] initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool: YES forKey:@"loggedIn"];
        }
    }];
}
```

This method does the majority of the heavy lifting for setting up for the active iCloud user. It checks if they have a valid iCloud account and prompts for them to be discoverable. It will return an error if they don't have a valid iCloud account, or if their discovery permissions are disabled.

Once "logged in", you should call this method every time your app becomes active so it can perform it's checks.

```Objective-C
- (void)applicationDidBecomeActive:(UIApplication *)application {
    BOOL loggedIn = [[NSUserDefaults standardUserDefaults] boolForKey:@"loggedIn"];
    if (loggedIn) {
        [[SPRSimpleCloudKitMessenger sharedMessenger] verifyAndFetchActiveiCloudUserWithCompletionHandler:^(CKDiscoveredUserInfo *userInfo, NSError *error) {
            if (error) {
                if(error.code == RSimpleCloudMessengerErroriCloudAcountChanged) {
                    // user has changed from previous user
                    // do logout logic and let the new user "login"
                } else {
                    // some other error, decide whether to show error
                }
            }
        }];
    }
}
```

This method will also return an error if the user changed iCloud accounts since the last time they used your app. You should check for error code == `RSimpleCloudMessengerErroriCloudAcountChanged` and clean up any private user data. Once you have cleaned up old user data, call this method again to prepare for the new iCloud user (or when they tap a "login" button).

Any errors returned from this method, or any other method on this class, will have a friendly error message in NSLocalizedDescription.

All serious errors will carry the code `SPRSimpleCloudMessengerErrorUnexpected`.

###Friends

To grab all the available friends from the user's address book that are using the app and discoverable, you'll use `discoverAllFriendsWithCompletionHandler`. It provides an array of `CKDiscoveredUserInfo` objects.

###Sending message

To send a message, you'll use the `sendMessage:withImageURL:toUserRecordID:withCompletionHandler`. The `CKRecordID` can be pulled off of a `CKDiscoveredUserInfo` object from the previous method.  CloudKit makes it very easy to upload blob objects like images. You just need to provide the location to the image on disk.

```Objective-C
- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CKDiscoveredUserInfo *userInfo = self.friends[indexPath.row];
    NSURL *imageURL = [self getImageURL];
    [[SPRSimpleCloudKitMessenger sharedMessenger] sendMessage:textfield.text withImageURL:imageURL toUserRecordID:userInfo.userRecordID withCompletionHandler:^(NSError *error) {
        if (error) {
            [[[UIAlertView alloc] initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
        } else {
            [[[UIAlertView alloc] initWithTitle:@"Success!" message:@"Message sent" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
        }
    }];
    [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
}
```

###Fetching messages

Fetching messages is quite easy. Calling `fetchNewMessagesWithCompletionHandler` will give you an array of `SPRMessage` objects. Just be sure to store messages somewhere if you need to maintain them across app launches, as there is no way currently to retrieve old messages.

The `SPRMessage` object is just a very simple data object, but it adheres to the NSCoding protocol, so it can be stored/cached easily.

```Objective-C
- (void)viewDidLoad
{
    [super viewDidLoad];
    [[SPRSimpleCloudKitMessenger sharedMessenger] fetchNewMessagesWithCompletionHandler:^(NSArray *messages, NSError *error) {
        self.messages = [self.messages arrayByAddingObjectsFromArray:messages];
        [self.tableView reloadData];
    }];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"SPRMessageCell"];
    SPRMessage *message = self.messages[indexPath.row];
    cell.textLabel.text = message.messageText;
    return cell;
}
```

The method above for fetching messages doesn't automatically pull down the image data for a message. When displaying the message detail, you can call `fetchDetailsForMessage:withCompletionHandler:` to get the image data. You pass a `SPRMessage` object in, and that same object is updated. You can check if the image exists before requesting the details.

```Objective-C
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.messageLabel.text = self.message.messageText;
    if (self.message.messageImage) {
        self.imageView.image = self.message.messageImage;
    } else {
        [[SPRSimpleCloudKitMessenger sharedMessenger] fetchDetailsForMessage:self.message withCompletionHandler:^(SPRMessage *message, NSError *error) {
            self.messageLabel.text = message.messageText;
            self.imageView.image = message.messageImage;
        }];
    }
}
```

The only other method to be aware of is `messageForQueryNotification:withCompletionHandler:` which lets you turn a new message notification the user may have swiped/tapped into a message object that you can display.

```Objective-C
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)info {
    
    // Do something if the app was in background. Could handle foreground notifications differently
    if (application.applicationState != UIApplicationStateActive) {
        [self checkForNotificationToHandleWithUserInfo:info];
    }
}

- (void) checkForNotificationToHandleWithUserInfo:(NSDictionary *)userInfo {
    NSString *notificationKey = [userInfo valueForKeyPath:@"ck.qry.sid"];
    if ([notificationKey isEqualToString:SPRSubscriptionIDIncomingMessages]) {
        CKQueryNotification *notification = [CKQueryNotification notificationFromRemoteNotificationDictionary:userInfo];
        [[SPRSimpleCloudKitMessenger sharedMessenger] messageForQueryNotification:notification withCompletionHandler:^(SPRMessage *message, NSError *error) {
            // Do something with the message, like pushing it onto the stack
            NSLog(@"%@", message);
        }];
    }
}
```
