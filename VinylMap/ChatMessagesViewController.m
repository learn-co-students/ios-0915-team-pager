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


#define chatroom @"https://amber-torch-8635.firebaseio.com/data/chatrooms"

@interface ChatMessagesViewController ()
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *textFieldBottomContstraint;
@property (nonatomic) double originalTextFieldBottomConstant;
@property (nonatomic, strong) NSString *userToMessage;
@property (nonatomic, strong) NSString *currentUser;


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
    
    
    // Initialize the root of our Firebase namespace.
    self.firebase = [[Firebase alloc] initWithUrl:chatroom];
    
    
    // Pick a random number between 1-1000 for our username.
//    self.name = self.currentUser; FOR USE WHEN USER AUTHENTICATION IS SET UP
    self.currentUser = @"Dog";
    
//**  [nameField setTitle:self.userToMessage forState:UIControlStateNormal]; FOR USE WHEN USER AUTHENTICATION IS SET UP
    self.userToMessage = @"Cat";
    nameField.text = self.userToMessage;
    
    
    // This allows us to check if these were messages already stored on the server
    // when we booted up (YES) or if they are new messages since we've started the app.
    // This is so that we can batch together the initial messages' reloadData for a perf gain.
    __block BOOL initialAdds = YES;
    
//**    Firebase *userChat = [self.firebase childByAppendingPath:self.currentUser]; FOR USE WHEN USER AUTHENTICATION IS SET UP

    NSString *messagesOfPeopleInChat = [NSString stringWithFormat:@"/%@%@", self.currentUser, self.userToMessage];

    Firebase *userChat = [self.firebase childByAppendingPath:messagesOfPeopleInChat];

    
    [userChat observeEventType:FEventTypeChildAdded withBlock:^(FDataSnapshot *snapshot) {

        // Add the chat message to the array.
            [self.chat addObject:snapshot.value];
            
        
        
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
    

    self.originalTextFieldBottomConstant = self.textFieldBottomContstraint.constant;
    

}

-(void)scrollToBottom{
    
    [self.tableView scrollRectToVisible:CGRectMake(0, self.tableView.contentSize.height - self.tableView.bounds.size.height, self.tableView.bounds.size.width, self.tableView.bounds.size.height) animated:NO];
    
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
    NSString *messageParticipants = [NSString stringWithFormat:@"/%@%@", self.currentUser, self.userToMessage];
    NSString *reversemessageParticipants = [NSString stringWithFormat:@"/%@%@", self.userToMessage, self.currentUser];

    Firebase *chatRoomMessages = [self.firebase childByAppendingPath:messageParticipants];
            Firebase *eachMessage = [chatRoomMessages childByAutoId];
            [eachMessage setValue:@{@"name" : self.currentUser, @"text": aTextField.text, @"time": kFirebaseServerValueTimestamp}];
    Firebase *reverseChatRoomMessages = [self.firebase childByAppendingPath:reversemessageParticipants];
    Firebase *reverseEachMessage = [reverseChatRoomMessages childByAutoId];
    [reverseEachMessage setValue:@{@"name" : self.currentUser, @"text": aTextField.text, @"time": kFirebaseServerValueTimestamp}];
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
    NSDictionary* chatMessage = [self.chat objectAtIndex:indexPath.row];
    
    NSString *text = chatMessage[@"text"];
    
    // typical textLabel.frame = {{10, 30}, {260, 22}}
    const CGFloat TEXT_LABEL_WIDTH = 260;
    CGSize constraint = CGSizeMake(TEXT_LABEL_WIDTH, 20000);
    
    // typical textLabel.font = font-family: "Helvetica"; font-weight: bold; font-style: normal; font-size: 18px

    CGSize size = [text sizeWithFont:[UIFont systemFontOfSize:17] constrainedToSize:constraint lineBreakMode:NSLineBreakByWordWrapping]; // requires iOS 6+
    const CGFloat CELL_CONTENT_MARGIN = 22;
    CGFloat height = MAX(CELL_CONTENT_MARGIN + size.height, 44);
    
    return height;
}

- (UITableViewCell*)tableView:(UITableView*)table cellForRowAtIndexPath:(NSIndexPath *)index
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        cell.textLabel.font = [UIFont systemFontOfSize:18];
        cell.textLabel.numberOfLines = 0;
    }
    
    NSDictionary* chatMessage = [self.chat objectAtIndex:index.row];
    

    cell.textLabel.text = chatMessage[@"text"];
    cell.detailTextLabel.text = chatMessage[@"name"];
    
    return cell;
}


#pragma mark - Keyboard handling

// Subscribe to keyboard show/hide notifications.
- (void)viewWillAppear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter]
        addObserver:self selector:@selector(keyboardWillShow:)
        name:UIKeyboardWillShowNotification object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self selector:@selector(keyboardWillHide:)
        name:UIKeyboardWillHideNotification object:nil];
}

// Unsubscribe from keyboard show/hide notifications.
- (void)viewWillDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter]
        removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter]
        removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}
-(void)viewDidLayoutSubviews{
    [self scrollToBottom];
}

- (void)keyboardWillShow:(NSNotification*)notification
{
    NSDictionary* keyboardInfo = [notification userInfo];
    NSValue* keyboardFrameBegin = [keyboardInfo valueForKey:UIKeyboardFrameBeginUserInfoKey];
    CGRect keyboardFrameBeginRect = [keyboardFrameBegin CGRectValue];
    self.textFieldBottomContstraint.constant -= keyboardFrameBeginRect.size.height;

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