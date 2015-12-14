//
//  ChatMessagesViewController.m
//  Firechat
//
//  Copyright (c) 2012 Firebase.
//
//  No part of this project may be copied, modified, propagated, or distributed
//  except according to terms in the accompanying LICENSE file.
//

#import "ChatMessagesViewController.h"
#import "UserObject.h"
#import "VinylColors.h"
#import <Masonry.h>
#import "VinylConstants.h"


@interface ChatMessagesViewController ()
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *textFieldBottomContstraint;
@property (nonatomic, assign) double originalTextFieldBottomConstant;
@property (nonatomic, strong) NSString *currentUser;
@property (nonatomic, strong) NSString *currentUserDisplayName;


@end

@implementation ChatMessagesViewController

@synthesize nameField;
@synthesize textField;
@synthesize tableView;


#pragma mark - Setup

// Initialization.
- (void)viewDidLoad
{
    [super viewDidLoad];
	
    // Initialize array that will store chat messages.
    self.chat = [[NSMutableArray alloc] init];
    self.view.backgroundColor = [UIColor vinylLightGray];
    self.tableView.backgroundColor = [UIColor vinylLightGray];

    self.originalTextFieldBottomConstant = self.textFieldBottomContstraint.constant;
    

    self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName:[UIColor whiteColor]};

}
-(void)scrollToBottom{
    
    [self.tableView scrollRectToVisible:CGRectMake(0, self.tableView.contentSize.height - self.tableView.bounds.size.height, self.tableView.bounds.size.width, self.tableView.bounds.size.height) animated:NO];
    
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    
    // Initialize the root of our Firebase namespace.
    self.firebase = [[Firebase alloc] initWithUrl:FIREBASE_CHATROOM];
    
    
    self.currentUser = [UserObject sharedUser].firebaseRoot.authData.uid;
    NSString *displayName = [NSString stringWithFormat:@"%@users/%@",FIREBASE_URL, self.currentUser];
    Firebase *displayNameFirebase = [[Firebase alloc] initWithUrl:displayName];
    [displayNameFirebase observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        self.currentUserDisplayName = snapshot.value[@"displayName"];
    }];
    
    self.title   = self.userToMessageDisplayName;
    
    
    // This allows us to check if these were messages already stored on the server
    // when we booted up (YES) or if they are new messages since we've started the app.
    // This is so that we can batch together the initial messages' reloadData for a perf gain.
    __block BOOL initialAdds = YES;
    
    
    NSString *messagesOfPeopleInChat = [NSString stringWithFormat:@"/%@%@", self.currentUser, self.userToMessage];
    
    Firebase *userChat = [self.firebase childByAppendingPath:messagesOfPeopleInChat];
    
    
    [userChat observeEventType:FEventTypeChildAdded withBlock:^(FDataSnapshot *snapshot) {
        
        // Add the chat message to the array.
        [self.chat insertObject:snapshot.value atIndex:0];
        if ([[UIApplication sharedApplication] currentUserNotificationSettings].types & UIUserNotificationTypeAlert) {
            UILocalNotification *localNotification = [[UILocalNotification alloc] init];
            localNotification.alertTitle = @"Visit";
            localNotification.alertBody = snapshot.value[@"text"];
            localNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow:5];
            localNotification.category = @"GLOBAL"; // Lazy categorization
            
            [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
        }
        
        
        
        // Reload the table view so the new message will show up.
        if (!initialAdds) {
            [self.tableView reloadData];
            [self scrollToBottom];
        }
    }];
    
    [userChat observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        // Reload the table view so that the intial messages show up
        [self.tableView reloadData];
        [self scrollToBottom];
        initialAdds = NO;
        
    }];
    
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    [[NSNotificationCenter defaultCenter]
     addObserver:self selector:@selector(keyboardWillShow:)
     name:UIKeyboardWillShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self selector:@selector(keyboardWillHide:)
     name:UIKeyboardWillHideNotification object:nil];
    [self scrollToBottom];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - Text field handling

// This method is called when the user enters text in the text field.
// We add the chat message to our Firebase.
- (BOOL)textFieldShouldReturn:(UITextField*)aTextField
{

    // This will also add the message to our local array self.chat because
    // the FEventTypeChildAdded event will be immediately fired.
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    NSString *messageParticipants = [NSString stringWithFormat:@"/%@%@", self.currentUser, self.userToMessage];
    NSString *reversemessageParticipants = [NSString stringWithFormat:@"/%@%@", self.userToMessage, self.currentUser];
    NSString *chatRooms = [NSString stringWithFormat:@"%@users/%@/chatrooms",FIREBASE_URL ,self.currentUser];
    NSString *chatroomsReverse = [NSString stringWithFormat:@"%@users/%@/chatrooms",FIREBASE_URL, self.userToMessage];
    Firebase *chatRoomsFirebase = [[Firebase alloc] initWithUrl:chatRooms];
    Firebase *chatroomsReverseFirebase = [[Firebase alloc] initWithUrl:chatroomsReverse];
    Firebase *chatRoomsRef = [chatRoomsFirebase childByAppendingPath:self.userToMessage];
    [chatRoomsRef setValue:@{@"display" : self.userToMessageDisplayName, @"id" : self.userToMessage, @"time": kFirebaseServerValueTimestamp, @"newest": aTextField.text}];
    Firebase *chatRoomsRefReverse = [chatroomsReverseFirebase childByAppendingPath:self.currentUser];
    [chatRoomsRefReverse setValue:@{@"display" : self.currentUserDisplayName, @"id" : self.currentUser, @"time": kFirebaseServerValueTimestamp, @"newest": aTextField.text}];
    

    Firebase *chatRoomMessages = [self.firebase childByAppendingPath:messageParticipants];
            Firebase *eachMessage = [chatRoomMessages childByAutoId];
            [eachMessage setValue:@{@"name" : self.currentUserDisplayName, @"text": aTextField.text, @"time": kFirebaseServerValueTimestamp}];
    Firebase *reverseChatRoomMessages = [self.firebase childByAppendingPath:reversemessageParticipants];
    Firebase *reverseEachMessage = [reverseChatRoomMessages childByAutoId];
    [reverseEachMessage setValue:@{@"name" : self.currentUserDisplayName, @"text": aTextField.text, @"time": kFirebaseServerValueTimestamp}];
    [aTextField setText:@""];

    return NO;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView
{
    // We only have one section in our table view.
    return 1;
}

- (NSInteger)tableView:(UITableView*)table numberOfRowsInSection:(NSInteger)section
{
    // This is the number of chat messages.
    return [self.chat count];
  
}

// This method changes the height of the text boxes based on how much text there is.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary* chatMessage = [self.chat objectAtIndex:self.chat.count - indexPath.row -1];
    
    NSString *text = chatMessage[@"text"];
    
    const CGFloat TEXT_LABEL_WIDTH = 300;
    CGSize constraint = CGSizeMake(TEXT_LABEL_WIDTH*4/5, 20000);
    
    // typical textLabel.font = font-family: "Helvetica"; font-weight: bold; font-style: normal; font-size: 18px

    CGSize size = [text sizeWithFont:[UIFont systemFontOfSize:15] constrainedToSize:constraint lineBreakMode:NSLineBreakByWordWrapping]; // requires iOS 6+
    const CGFloat CELL_CONTENT_MARGIN = 20;
    CGFloat height = MAX(CELL_CONTENT_MARGIN + size.height, 44);
    
    return height;
}

- (UITableViewCell*)tableView:(UITableView*)table cellForRowAtIndexPath:(NSIndexPath *)index
{
    
    UITableViewCell *cell;
    NSDictionary* chatMessage = [self.chat objectAtIndex:self.chat.count - index.row-1];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@""];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    for(UIView *v in [cell subviews])
    {
        [v removeFromSuperview];
    }
    
    cell.backgroundColor = [UIColor vinylLightGray];
    
    
    UILabel *messageView = [[UILabel alloc] init];
    messageView.numberOfLines = 0;
    messageView.font = [UIFont systemFontOfSize:15];
    messageView.text = chatMessage[@"text"];
    CGFloat leftOffset = 0;
    CGFloat rightOffset = 0;
    UIView *insetView = [[UIView alloc] init];
    [insetView addSubview:messageView];
    
    if([chatMessage[@"name"] isEqualToString:self.currentUserDisplayName])
    {
        messageView.backgroundColor = [UIColor vinylBlue];
        insetView.backgroundColor = [UIColor vinylBlue];
        messageView.textColor = [UIColor vinylLightGray];
        leftOffset = self.view.frame.size.width/5;
    } else
    {
        messageView.backgroundColor = [UIColor vinylMediumGray];
        insetView.backgroundColor = [UIColor vinylMediumGray];
        messageView.textColor = [UIColor blackColor];
        rightOffset = -self.view.frame.size.width/5;
    }
    
    
    [cell setSelectedBackgroundView:nil];
    
    [cell addSubview:insetView];
    [insetView.layer setCornerRadius:10.0f];
    [insetView.layer setMasksToBounds:YES];
    [insetView.layer setBorderWidth:0];
    
    [messageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.and.bottom.equalTo(insetView);
        make.left.equalTo(insetView).offset(10);
        make.right.equalTo(insetView).offset(-10);
    }];
    
    [insetView mas_makeConstraints:^(MASConstraintMaker *make)
    {
        make.top.equalTo(cell).offset(2);
        make.bottom.equalTo(cell).offset(-2);
        make.left.equalTo(cell).offset(leftOffset);
        make.right.equalTo(cell).offset(rightOffset);
    }];
    
    
    return cell;
}


#pragma mark - Keyboard handling


// Unsubscribe from keyboard show/hide notifications.
- (void)viewWillDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter]
        removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter]
        removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}
-(void)viewDidLayoutSubviews{
    
}

- (void)keyboardWillShow:(NSNotification*)notification
{
    NSDictionary* keyboardInfo = [notification userInfo];
    NSValue* keyboardFrameBegin = [keyboardInfo valueForKey:UIKeyboardFrameBeginUserInfoKey];
    CGRect keyboardFrameBeginRect = [keyboardFrameBegin CGRectValue];
    CGFloat tabBarHeight = self.tabBarController.tabBar.frame.size.height;

    self.textFieldBottomContstraint.constant -= keyboardFrameBeginRect.size.height - tabBarHeight;

}

- (void)keyboardWillHide:(NSNotification*)notification
{
    self.textFieldBottomContstraint.constant = self.originalTextFieldBottomConstant;
}

- (IBAction)viewTapped:(UITapGestureRecognizer *)sender {
    if ([textField isFirstResponder]) {
        [textField resignFirstResponder];
    }
}


@end
