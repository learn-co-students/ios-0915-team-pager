//
//  ChatroomsTableViewController.m
//  VinylMap
//
//  Created by Linda NG on 12/7/15.
//  Copyright © 2015 Toaster. All rights reserved.
//

#import "ChatroomsTableViewController.h"
#import "UserObject.h"
#import "ChatMessagesViewController.h"
#import "VinylColors.h"
#import "VinylConstants.h"

@interface ChatroomsTableViewController ()
@property (nonatomic, strong) NSString *currentUser;
@property (nonatomic, strong) NSString *currentUserDisplayName;
@property (nonatomic, strong) NSMutableArray *chatroomsUnsorted;
@property (nonatomic, strong) NSArray *values;

@end

@implementation ChatroomsTableViewController

-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateMessageBadge:)
                                                     name:@"messageReceived" object:nil];
    }
    return self;
}



- (void)viewDidLoad {
    [super viewDidLoad];
    self.chatrooms = [[NSMutableArray alloc] init];
    self.chatroomsUnsorted = [[NSMutableArray alloc]init];
    
    self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName:[UIColor whiteColor]};
    
}

-(void)updateMessageBadge:(id)snapshot
{
    if([UserObject sharedUser].unreadMessages == 0)
    {
            self.navigationController.tabBarItem.badgeValue = nil;
    } else
    {
        self.navigationController.tabBarItem.badgeValue = @([UserObject sharedUser].unreadMessages).stringValue;
    }

}

- (void)viewWillAppear:(BOOL)animated{
    
    self.currentUser = [UserObject sharedUser].firebaseRoot.authData.uid;
    self.view.backgroundColor = [UIColor vinylLightGray];
    NSString *chatroom = [NSString stringWithFormat:@"%@users/%@/chatrooms",FIREBASE_URL, self.currentUser];
    Firebase *chatroomsFirebase = [[Firebase alloc] initWithUrl:chatroom];
    [chatroomsFirebase observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        [self.chatroomsUnsorted removeAllObjects];
        [self.chatroomsUnsorted addObject:snapshot.value];
        NSSortDescriptor *sortByTime = [NSSortDescriptor sortDescriptorWithKey:@"time" ascending:NO];
                    NSArray *sortDescriptors = [NSArray arrayWithObject:sortByTime];
        self.chatrooms = [[self.chatroomsUnsorted sortedArrayUsingDescriptors:sortDescriptors] mutableCopy];
        NSDictionary *chatRoomofUser = [self.chatrooms objectAtIndex:0];
        if (![chatRoomofUser isKindOfClass:[NSNull class]]) {
            self.values = [chatRoomofUser allValues];
            self.values = [self.values sortedArrayUsingDescriptors:sortDescriptors];
        }
        [self.tableView reloadData];
    }];
    self.navigationController.tabBarItem.badgeValue = nil;
    [UserObject sharedUser].unreadMessages = 0;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.values.count;

}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"chatroomsCell" forIndexPath:indexPath];
    if (self.values.count != 0) {
        NSDictionary *chatUsers = [self.values objectAtIndex:indexPath.row];
        cell.textLabel.text = chatUsers[@"display"];
        cell.detailTextLabel.text = chatUsers[@"newest"];
    }
    
    cell.backgroundColor = [UIColor vinylLightGray];
    UIView *bgColorView = [[UIView alloc] init];
    bgColorView.backgroundColor = [UIColor vinylBlue];
    [cell setSelectedBackgroundView:bgColorView];
    
    return cell;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    ChatMessagesViewController *destinationVC = segue.destinationViewController;
    NSIndexPath *indexPathOfRowTapped = self.tableView.indexPathForSelectedRow;
    NSDictionary *chatUserAtIndex = self.values[indexPathOfRowTapped.row];
    NSString *userToMessage = chatUserAtIndex[@"id"];
    NSString *userToMessageDisplayName = chatUserAtIndex[@"display"];
    destinationVC.userToMessage = userToMessage;
    destinationVC.userToMessageDisplayName = userToMessageDisplayName;
    
}


@end
