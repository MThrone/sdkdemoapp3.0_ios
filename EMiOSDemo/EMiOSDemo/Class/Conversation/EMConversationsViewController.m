//
//  EMConversationsViewController.m
//  ChatDemo-UI3.0
//
//  Created by XieYajie on 2019/1/8.
//  Copyright © 2019 XieYajie. All rights reserved.
//

#import "EMConversationsViewController.h"

#import "EMRealtimeSearch.h"
#import "EMConversationHelper.h"

#import "EMConversationCell.h"
#import "UIViewController+Search.h"

#import "PellTableViewSelect.h"
#import "EMInviteGroupMemberViewController.h"
#import "EMCreateGroupViewController.h"
#import "EMInviteFriendViewController.h"

@interface EMConversationsViewController()<EMChatManagerDelegate, EMGroupManagerDelegate, EMSearchControllerDelegate, EMConversationsDelegate,EMConversationCellDelegate,EMContactManagerDelegate>

@property (nonatomic) BOOL isViewAppear;
@property (nonatomic) BOOL isNeedReload;
@property (nonatomic) BOOL isNeedReloadSorted;

@property (nonatomic, strong) UIMenuItem *deleteMenuItem;
@property (nonatomic, strong) UIMenuItem *stickMenuItem;
@property (nonatomic, strong) UIMenuItem *cancelStickMenuItem;
@property (nonatomic, strong) UIMenuController *menuController;
@property (strong, nonatomic) NSIndexPath *menuIndexPath;

@property (nonatomic, strong) UIButton *addImageBtn;

@property (nonatomic, strong) EMInviteGroupMemberViewController *inviteController;

@end

@implementation EMConversationsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self _setupSubviews];
    
    [[EMClient sharedClient].chatManager addDelegate:self delegateQueue:nil];
    [[EMClient sharedClient].groupManager addDelegate:self delegateQueue:nil];
    [[EMConversationHelper shared] addDelegate:self];
    [[EMClient sharedClient].contactManager addDelegate:self delegateQueue:nil];
    [self _loadAllConversationsFromDBWithIsShowHud:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleGroupSubjectUpdated:) name:GROUP_SUBJECT_UPDATED object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(AgreeJoinGroupInvite:) name:NOTIF_ADD_SOCIAL_CONTACT object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBarHidden = YES;
    self.isViewAppear = YES;
    if (self.isNeedReloadSorted) {
        self.isNeedReloadSorted = NO;
        [self _loadAllConversationsFromDBWithIsShowHud:NO];
        
    } else if (self.isNeedReload) {
        self.isNeedReload = NO;
        [self.tableView reloadData];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    self.navigationController.navigationBarHidden = NO;
    self.isViewAppear = NO;
    self.isNeedReload = NO;
    self.isNeedReloadSorted = NO;
}

- (void)dealloc
{
    [[EMClient sharedClient].chatManager removeDelegate:self];
    [[EMClient sharedClient].groupManager removeDelegate:self];
    [[EMConversationHelper shared] removeDelegate:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Subviews

- (void)_setupSubviews
{
    self.view.backgroundColor = [UIColor whiteColor];
    self.showRefreshHeader = YES;
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"会话";
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.font = [UIFont systemFontOfSize:18];
    [self.view addSubview:titleLabel];
    [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.top.equalTo(self.view).offset(35);
        make.height.equalTo(@25);
    }];
    
    self.addImageBtn = [[UIButton alloc]init];
    [self.addImageBtn setBackgroundImage:[UIImage imageNamed:@"icon-add"] forState:UIControlStateNormal];
    [self.addImageBtn addTarget:self action:@selector(moreAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.addImageBtn];
    [self.addImageBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.equalTo(@24);
        make.centerY.equalTo(titleLabel);
        make.right.equalTo(self.view).offset(-15);
    }];
    
    [self enableSearchController];
    [self.searchButton mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(titleLabel.mas_bottom).offset(15);
        make.left.equalTo(self.view).offset(15);
        make.right.equalTo(self.view).offset(-15);
        make.height.equalTo(@36);
    }];
    
    self.tableView.rowHeight = 60;
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.searchButton.mas_bottom).offset(15);
        make.left.equalTo(self.view);
        make.right.equalTo(self.view);
        make.bottom.equalTo(self.view);
    }];
    
    [self _setupSearchResultController];
}

#pragma mark - moreAction
- (void)moreAction
{
    
    // 弹出QQ的自定义视图
    [PellTableViewSelect addPellTableViewSelectWithWindowFrame:CGRectMake(self.view.bounds.size.width-175, self.addImageBtn.frame.origin.y + 24, 165, 156) selectData:@[@"音视频会议",@"创建群组",@"添加好友"] images:@[@"icon-音视频会议",@"icon-创建群组",@"icon-添加好友"] locationY:-8 action:^(NSInteger index){
        if(index == 0) {
            [self avConfrence];
        } else if (index == 1) {
            [self createGroup];
        } else {
            [self addFriend];
        }
    } animated:YES];
}

//音视频会议
- (void)avConfrence
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"会议类型" message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"普通会议" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[NSNotificationCenter defaultCenter] postNotificationName:CALL_MAKECONFERENCE object:@{CALL_TYPE:@(EMConferenceTypeCommunication), NOTIF_NAVICONTROLLER:self.navigationController}];
    }];
    [alertController addAction:defaultAction];

    UIAlertAction *mixAction = [UIAlertAction actionWithTitle:@"混音会议" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[NSNotificationCenter defaultCenter] postNotificationName:CALL_MAKECONFERENCE object:@{CALL_TYPE:@(EMConferenceTypeLargeCommunication), NOTIF_NAVICONTROLLER:self.navigationController}];
    }];
    [alertController addAction:mixAction];

    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", @"Cancel") style: UIAlertActionStyleCancel handler:nil]];

    [self presentViewController:alertController animated:YES completion:nil];
}

//创建群组
- (void)createGroup
{
    self.inviteController = nil;
    self.inviteController = [[EMInviteGroupMemberViewController alloc] init];
    __weak typeof(self) weakself = self;
    [self.inviteController setDoneCompletion:^(NSArray * _Nonnull aSelectedArray) {
        EMCreateGroupViewController *createController = [[EMCreateGroupViewController alloc] initWithSelectedMembers:aSelectedArray];
        createController.inviteController = weakself.inviteController;
        [weakself.navigationController pushViewController:createController animated:YES];
    }];
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self.inviteController];
    navController.modalPresentationStyle = 0;
    [self presentViewController:navController animated:YES completion:nil];
}

//添加好友
- (void)addFriend
{
    EMInviteFriendViewController *controller = [[EMInviteFriendViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)_setupSearchResultController
{
    __weak typeof(self) weakself = self;
    self.resultController.tableView.rowHeight = 60;
    [self.resultController setCellForRowAtIndexPathCompletion:^UITableViewCell *(UITableView *tableView, NSIndexPath *indexPath) {
        NSString *cellIdentifier = @"EMConversationCell";
        EMConversationCell *cell = (EMConversationCell *)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (cell == nil) {
            cell = [[EMConversationCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        }
        
        NSInteger row = indexPath.row;
        EMConversationModel *model = [weakself.resultController.dataArray objectAtIndex:row];
        cell.model = model;
        return cell;
    }];
    [self.resultController setCanEditRowAtIndexPath:^BOOL(UITableView *tableView, NSIndexPath *indexPath) {
        return YES;
    }];
    [self.resultController setCommitEditingAtIndexPath:^(UITableView *tableView, UITableViewCellEditingStyle editingStyle, NSIndexPath *indexPath) {
        if (editingStyle != UITableViewCellEditingStyleDelete) {
            return ;
        }
        
        NSInteger row = indexPath.row;
        EMConversationModel *model = [weakself.resultController.dataArray objectAtIndex:row];
        EMConversation *conversation = model.emModel;
        [[EMClient sharedClient].chatManager deleteConversation:conversation.conversationId isDeleteMessages:YES completion:nil];
        [weakself.resultController.dataArray removeObjectAtIndex:row];
        [weakself.resultController.tableView reloadData];
    }];
    [self.resultController setDidSelectRowAtIndexPathCompletion:^(UITableView *tableView, NSIndexPath *indexPath) {
        NSInteger row = indexPath.row;
        EMConversationModel *model = [weakself.resultController.dataArray objectAtIndex:row];
        [[NSNotificationCenter defaultCenter] postNotificationName:CHAT_PUSHVIEWCONTROLLER object:model];
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [self.dataArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellIdentifier = @"EMConversationCell";
    EMConversationCell *cell = (EMConversationCell *)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[EMConversationCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    NSInteger row = indexPath.row;
    EMConversationModel *model = [self.dataArray objectAtIndex:row];
    cell.model = model;
    cell.delegate = self;
    [cell setSeparatorInset:UIEdgeInsetsMake(0, cell.avatarView.frame.size.height + 23, 0, 1)];

    //置顶是已选中状态，背景变色
    if([model.emModel.ext objectForKey:CONVERSATION_STICK] && ![[model.emModel.ext objectForKey:CONVERSATION_STICK] isEqualToString:@""]) {
        //cell.backgroundColor = [UIColor grayColor];
        dispatch_async(dispatch_get_main_queue(), ^{
            [cell setSelected:YES animated:NO];
        });
        //cell.selectionStyle = UITableViewCellSelectionStyleGray;
    }
    
    return cell;
}

#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSInteger row = indexPath.row;
    EMConversationModel *model = [self.dataArray objectAtIndex:row];
    [[NSNotificationCenter defaultCenter] postNotificationName:CHAT_PUSHVIEWCONTROLLER object:model];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger row = indexPath.row;
    EMConversationModel *model = [self.dataArray objectAtIndex:row];
    EMConversation *conversation = model.emModel;
    [[EMClient sharedClient].chatManager deleteConversation:conversation.conversationId
                                           isDeleteMessages:YES
                                                 completion:nil];
    [self.dataArray removeObjectAtIndex:row];
    [self.tableView reloadData];
}

#pragma mark - EMChatManagerDelegate

- (void)messagesDidRecall:(NSArray *)aMessages {
    [self _loadAllConversationsFromDBWithIsShowHud:NO];
}

- (void)conversationListDidUpdate:(NSArray *)aConversationList
{
    if (!self.isViewAppear) {
        self.isNeedReloadSorted = YES;
    } else {
        [self _loadAllConversationsFromDBWithIsShowHud:NO];
    }
}

- (void)messagesDidReceive:(NSArray *)aMessages
{
    if (self.isViewAppear) {
        if (!self.isNeedReload) {
            self.isNeedReload = YES;
            for (EMMessage *msg in aMessages) {
                if(msg.body.type == EMMessageBodyTypeText) {
                    EMConversation *conversation = [[EMClient sharedClient].chatManager getConversation:msg.conversationId type:EMConversationTypeGroupChat createIfNotExist:YES];
                    //群聊@提醒功能
                    NSString *content = [NSString stringWithFormat:@"@%@",EMClient.sharedClient.currentUsername];
                    if(conversation.type == EMConversationTypeGroupChat && [((EMTextMessageBody *)msg.body).text containsString:content]) {
                        NSMutableDictionary *dic;
                        if (conversation.ext) {
                            dic = [[NSMutableDictionary alloc]initWithDictionary:conversation.ext];
                        } else {
                            dic = [[NSMutableDictionary alloc]init];
                        }
                        [dic setObject:kConversation_AtYou forKey:kConversation_IsRead];
                        [conversation setExt:dic];
                    };
                }
            }
            [self performSelector:@selector(_reSortedConversationModelsAndReloadView) withObject:nil afterDelay:0.8];
        }
    } else {
        self.isNeedReload = YES;
    }
}

#pragma mark - EMGroupManagerDelegate

- (void)didLeaveGroup:(EMGroup *)aGroup
               reason:(EMGroupLeaveReason)aReason
{
    [[EMClient sharedClient].chatManager deleteConversation:aGroup.groupId isDeleteMessages:NO completion:nil];
}

#pragma mark - EMSearchControllerDelegate

- (void)searchBarWillBeginEditing:(UISearchBar *)searchBar
{
    self.resultController.searchKeyword = nil;
}

- (void)searchBarCancelButtonAction:(UISearchBar *)searchBar
{
    [[EMRealtimeSearch shared] realtimeSearchStop];
    
    [self.resultController.dataArray removeAllObjects];
    [self.resultController.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [self.view endEditing:YES];
}

- (void)searchTextDidChangeWithString:(NSString *)aString
{
    self.resultController.searchKeyword = aString;
    
    __weak typeof(self) weakself = self;
    [[EMRealtimeSearch shared] realtimeSearchWithSource:self.dataArray searchText:aString collationStringSelector:@selector(name) resultBlock:^(NSArray *results) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakself.resultController.dataArray removeAllObjects];
            [weakself.resultController.dataArray addObjectsFromArray:results];
            [weakself.resultController.tableView reloadData];
        });
    }];
}

#pragma mark - EMConversationsDelegate

- (void)didConversationUnreadCountToZero:(EMConversationModel *)aConversation
{
    NSInteger index = [self.dataArray indexOfObject:aConversation];
    [self.tableView beginUpdates];
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    [self.tableView endUpdates];
}

- (void)didResortConversationsLatestMessage
{
    [self _reSortedConversationModelsAndReloadView];
}

#pragma mark - EMContactManagerDelegate

//收到好友请求被同意/同意
- (void)friendshipDidAddByUser:(NSString *)aUsername
{
    [self notificationMsg:aUsername aUserName:aUsername conversationType:EMConversationTypeChat];
}

#pragma mark - EMGroupManagerDelegate

//群主同意用户A的入群申请后，用户A会接收到该回调
- (void)joinGroupRequestDidApprove:(EMGroup *)aGroup
{
    [self notificationMsg:aGroup.groupId aUserName:EMClient.sharedClient.currentUsername conversationType:EMConversationTypeGroupChat];
}

//有用户加入群组
- (void)userDidJoinGroup:(EMGroup *)aGroup
                    user:(NSString *)aUsername
{
    [self notificationMsg:aGroup.groupId aUserName:aUsername conversationType:EMConversationTypeGroupChat];
}

#pragma mark - noti
//加群邀请被同意
- (void)AgreeJoinGroupInvite:(NSNotification *)aNotif
{
    NSDictionary *dic = aNotif.object;
    [self notificationMsg:[dic objectForKey:CONVERSATION_ID] aUserName:[dic objectForKey:CONVERSATION_OBJECT] conversationType:EMConversationTypeGroupChat];
}

//加好友，加群 成功通知
- (void)notificationMsg:(NSString *)conversationId aUserName:(NSString *)aUserName conversationType:(EMConversationType)aType
{
    EMConversationType conversationType = aType;
    EMConversation *conversation = [[EMClient sharedClient].chatManager getConversation:conversationId type:conversationType createIfNotExist:YES];
    EMTextMessageBody *body;
    NSString *to = conversationId;
    EMMessage *message;
    if (conversationType == EMChatTypeChat) {
        body = [[EMTextMessageBody alloc] initWithText:[NSString stringWithFormat:@"你与%@已经成为好友，开始聊天吧",aUserName]];
        message = [[EMMessage alloc] initWithConversationID:to from:EMClient.sharedClient.currentUsername to:to body:body ext:@{MSG_EXT_NEWNOTI:NOTI_EXT_ADDFRIEND}];
    } else if (conversationType == EMChatTypeGroupChat) {
        if ([aUserName isEqualToString:EMClient.sharedClient.currentUsername]) {
            body = [[EMTextMessageBody alloc] initWithText:@"你已加入本群，开始发言吧"];
        } else {
            body = [[EMTextMessageBody alloc] initWithText:[NSString stringWithFormat:@"%@ 加入了群聊",aUserName]];
        }
        message = [[EMMessage alloc] initWithConversationID:to from:aUserName to:to body:body ext:@{MSG_EXT_NEWNOTI:NOTI_EXT_ADDGROUP}];
    }
    message.chatType = (EMChatType)conversation.type;
    message.isRead = YES;
    [conversation insertMessage:message error:nil];
    if ([aUserName isEqualToString:EMClient.sharedClient.currentUsername] || conversationType == EMChatTypeChat) {
        EMConversationModel *model = [[EMConversationModel alloc] initWithEMModel:conversation];
        [self.dataArray addObject:model];
        [self.tableView reloadData];
    }
}

#pragma mark - EMConversationCellDelegate
//长按
- (void)conversationCellDidLongPress:(EMConversationCell *)aCell
{
    self.menuIndexPath = [self.tableView indexPathForCell:aCell];
    [self _menuViewController:aCell];
    
}

#pragma mark - NSNotification

- (void)handleGroupSubjectUpdated:(NSNotification *)aNotif
{
    EMGroup *group = aNotif.object;
    if (!group) {
        return;
    }
    
    NSString *groupId = group.groupId;
    for (EMConversationModel *model in self.dataArray) {
        if ([model.emModel.conversationId isEqualToString:groupId]) {
            model.name = group.subject;
            [self.tableView reloadData];
        }
    }
}

#pragma mark - UIMenuController

//删除会话
- (void)_deleteConversation
{
    NSInteger row = self.menuIndexPath.row;
    EMConversationModel *model = [self.dataArray objectAtIndex:row];
    EMConversation *conversation = model.emModel;
    [[EMClient sharedClient].chatManager deleteConversation:conversation.conversationId
                                           isDeleteMessages:YES
                                                 completion:nil];
    [self.dataArray removeObjectAtIndex:row];
    [self.tableView reloadData];
}

//置顶
- (void)_stickConversation
{
    EMConversationModel *conversationModel = [self.dataArray objectAtIndex:self.menuIndexPath.row];
    
    [self.dataArray exchangeObjectAtIndex:self.menuIndexPath.row withObjectAtIndex:0];
    NSIndexPath *firstIndexPath = [NSIndexPath indexPathForRow:0 inSection:self.menuIndexPath.section];
    [self.tableView moveRowAtIndexPath:self.menuIndexPath toIndexPath:firstIndexPath];
    
    NSMutableDictionary *ext = [[NSMutableDictionary alloc]initWithDictionary:conversationModel.emModel.ext];
    [ext setObject:@"stick" forKey:CONVERSATION_STICK];
    
    [conversationModel.emModel setExt:ext];
    
}

//取消置顶
- (void)_cancelStickConversation
{
    EMConversationModel *conversationModel = [self.dataArray objectAtIndex:self.menuIndexPath.row];
    NSMutableDictionary *ext = [[NSMutableDictionary alloc]initWithDictionary:conversationModel.emModel.ext];
    [ext setObject:@"" forKey:CONVERSATION_STICK];
    [conversationModel.emModel setExt:ext];
    [self.tableView reloadData];
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}
//UIMenuController弹起防止滑动时出现bug
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    UIMenuController * menu = [UIMenuController sharedMenuController];
    [menu setMenuVisible:NO animated:YES];
}
-(BOOL)canPerformAction:(SEL)action withSender:(id)sender{
    
    if (action ==@selector(_deleteConversation) || action ==@selector(_stickConversation) || action == @selector(_cancelStickConversation)){
        
        return YES;
        
    }
    
    return NO;//隐藏系统默认的菜单项
}
//UIMenuController菜单
- (void)_menuViewController:(EMConversationCell *)aCell
{
    //[self canBecomeFirstResponder];
    [self becomeFirstResponder];
    NSMutableArray *items = [[NSMutableArray alloc] init];
    if([aCell.model.emModel.ext objectForKey:CONVERSATION_STICK] && ![[aCell.model.emModel.ext objectForKey:CONVERSATION_STICK] isEqualToString:@""]) {
        [items addObject:self.cancelStickMenuItem];
        [items addObject:self.deleteMenuItem];
    } else {
        [items addObject:self.stickMenuItem];
        [items addObject:self.deleteMenuItem];
    }
    [self.menuController setMenuItems:items];
    [self.menuController setTargetRect:aCell.frame inView:self.tableView];
    [self.menuController setMenuVisible:YES animated:YES];
    [[NSNotificationCenter defaultCenter] addObserver:aCell selector:@selector(setSelectedStatus) name:UIMenuControllerDidHideMenuNotification object:nil];
}

#pragma mark - Data

//会话置顶重排序
- (NSArray *)_stickSortedConversation:(NSArray *)originArray
{
    NSMutableArray *stickArray = [[NSMutableArray alloc]init];
    [stickArray addObjectsFromArray:originArray];
    EMConversation *conversation = nil;
    /*
    int last = (int)([originArray count] - 1);
    for (int i = last; i > -1 ; i--) {
        conversation = originArray[i];
        if([conversation.ext objectForKey:CONVERSATION_STICK]) {
            [stickArray exchangeObjectAtIndex:i withObjectAtIndex:last];
        }
    }*/
    
    for (int i = 0; i < [originArray count]; i++) {
        conversation = originArray[i];
        if([conversation.ext objectForKey:CONVERSATION_STICK] && ![[conversation.ext objectForKey:CONVERSATION_STICK] isEqualToString:@""]) {
            [stickArray exchangeObjectAtIndex:i withObjectAtIndex:0];
        }
    }

    return [stickArray copy];
}

//会话model置顶冲排序
- (NSArray *)_stickSortedConversationModels:(NSArray *)modelArray
{
    NSMutableArray *stickModelArray = [[NSMutableArray alloc]init];
    [stickModelArray addObjectsFromArray:modelArray];
    EMConversationModel *conversationModel = nil;
    /*
    int last = (int)([modelArray count] - 1);
    for (int i = last; i > -1 ; i--) {
        conversationModel = modelArray[i];
        if([conversationModel.emModel.ext objectForKey:CONVERSATION_STICK]) {
            [stickModelArray exchangeObjectAtIndex:i withObjectAtIndex:last];
        }
    }*/
    
    for (int i = 0; i < [modelArray count]; i++) {
        conversationModel = modelArray[i];
        if([conversationModel.emModel.ext objectForKey:CONVERSATION_STICK] && ![[conversationModel.emModel.ext objectForKey:CONVERSATION_STICK] isEqualToString:@""]) {
            [stickModelArray exchangeObjectAtIndex:i withObjectAtIndex:0];
        }
    }

    return [stickModelArray copy];
}

- (void)_reSortedConversationModelsAndReloadView
{
    NSArray *sorted = [self.dataArray sortedArrayUsingComparator:^(EMConversationModel *obj1, EMConversationModel *obj2) {
        EMMessage *message1 = [obj1.emModel latestMessage];
        EMMessage *message2 = [obj2.emModel latestMessage];
        if(message1.timestamp > message2.timestamp) {
            return(NSComparisonResult)NSOrderedAscending;
        } else {
            return(NSComparisonResult)NSOrderedDescending;
        }}];
    sorted = [self _stickSortedConversationModels:sorted];//置顶重排序
    NSMutableArray *conversationModels = [NSMutableArray array];
    for (EMConversationModel *model in sorted) {
        if (!model.emModel.latestMessage) {
            [EMClient.sharedClient.chatManager deleteConversation:model.emModel.conversationId
                                                 isDeleteMessages:NO
                                                       completion:nil];
            continue;
        }
        [conversationModels addObject:model];
    }
    
    [self.dataArray removeAllObjects];
    [self.dataArray addObjectsFromArray:conversationModels];
    [self.tableView reloadData];
    
    self.isNeedReload = NO;
}

- (void)_loadAllConversationsFromDBWithIsShowHud:(BOOL)aIsShowHUD
{
    if (aIsShowHUD) {
        [self showHudInView:self.view hint:@"加载会话列表..."];
    }
    
    __weak typeof(self) weakself = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *conversations = [[EMClient sharedClient].chatManager getAllConversations];
        NSArray *sorted = [conversations sortedArrayUsingComparator:^(EMConversation *obj1, EMConversation *obj2) {
            EMMessage *message1 = [obj1 latestMessage];
            EMMessage *message2 = [obj2 latestMessage];
            if(message1.timestamp > message2.timestamp) {
                return(NSComparisonResult)NSOrderedAscending;
            } else {
                return(NSComparisonResult)NSOrderedDescending;
            }
            
        }];
        
        [weakself.dataArray removeAllObjects];
        sorted = [self _stickSortedConversation:sorted];//置顶重排序
        NSArray *models = [EMConversationHelper modelsFromEMConversations:sorted];
        [weakself.dataArray addObjectsFromArray:models];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (aIsShowHUD) {
                [weakself hideHud];
            }
            
            [weakself tableViewDidFinishTriggerHeader:YES reload:NO];
            [weakself.tableView reloadData];
            weakself.isNeedReload = NO;
        });
    });
}

- (void)tableViewDidTriggerHeaderRefresh
{
    [self _loadAllConversationsFromDBWithIsShowHud:NO];
}

- (UIMenuItem *)deleteMenuItem
{
    if (_deleteMenuItem == nil) {
        _deleteMenuItem = [[UIMenuItem alloc] initWithTitle:@"删除会话" action:@selector(_deleteConversation)];
    }
    
    return _deleteMenuItem;
}

- (UIMenuItem *)stickMenuItem
{
    if (_stickMenuItem == nil) {
        _stickMenuItem = [[UIMenuItem alloc] initWithTitle:@"置顶" action:@selector(_stickConversation)];
    }
    
    return _stickMenuItem;
}

- (UIMenuItem *)cancelStickMenuItem
{
    if (_cancelStickMenuItem == nil) {
        _cancelStickMenuItem = [[UIMenuItem alloc] initWithTitle:@"取消置顶" action:@selector(_cancelStickConversation)];
    }
    
    return _cancelStickMenuItem;
}

- (UIMenuController *)menuController
{
    if (_menuController == nil) {
        _menuController = [UIMenuController sharedMenuController];
    }
    
    return _menuController;
}

@end
