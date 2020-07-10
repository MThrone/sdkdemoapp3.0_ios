//
//  EMChatViewController.m
//  EMiOSDemo
//
//  Created by XieYajie on 2019/1/18.
//  Copyright © 2019 XieYajie. All rights reserved.
//

#import <AVKit/AVKit.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "EMChatViewController.h"

#import "EMImageBrowser.h"
#import "EMDateHelper.h"
#import "EMAudioPlayerHelper.h"
#import "EMConversationHelper.h"
#import "EMMessageModel.h"

#import "EMChatBar.h"
#import "EMMessageCell.h"
#import "EMMessageTimeCell.h"
#import "EMLocationViewController.h"
#import "EMMsgTranspondViewController.h"
#import "EMAtGroupMembersViewController.h"
#import "EMMsgRecordCell.h"

#import "PAirSandbox.h"
#import "EMPickFileViewController.h"

#import "EMMsgTouchIncident.h"
#import "EMChatViewController+EMMsgLongPressIncident.h"

@interface EMChatViewController ()<UIScrollViewDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, EMMultiDevicesDelegate, EMChatManagerDelegate, EMChatBarDelegate, EMMessageCellDelegate, EMChatBarEmoticonViewDelegate, EMChatBarRecordAudioViewDelegate,EMMoreFunctionViewDelegate,UIDocumentPickerDelegate>

@property (nonatomic, strong) NSString *moreMsgId;  //第一条消息的消息id

@property (nonatomic, strong) EMChatBar *chatBar;
@property (nonatomic, strong) UIImagePickerController *imagePicker;
@property (nonatomic, strong) UIDocumentPickerViewController *docFile;

//聊天页-查找记录页
@property (nonatomic) BOOL isChatRecord;
//聊天记录-全部按钮
@property (nonatomic, strong) UIButton *allRecordBtn;

//聊天记录-图片/视频按钮
@property (nonatomic, strong) UIButton *picAndVideoRecordBtn;
//聊天记录类型类型
@property (nonatomic) NSInteger type;
//聊天记录-图片与视频tableview
@property (nonatomic, strong) UITableView *picAndVideoRecordTableView;
//聊天记录数组
@property (nonatomic, strong) NSArray *recordArray;

@end

@implementation EMChatViewController

- (instancetype)initWithConversationId:(NSString *)aId
                                  type:(EMConversationType)aType
                      createIfNotExist:(BOOL)aIsCreate
                        isChatRecord:(BOOL)aIsChatRecord
{
    self = [super init];
    if (self) {
        EMConversation *conversation = [[EMClient sharedClient].chatManager getConversation:aId type:aType createIfNotExist:aIsCreate];
        [self setDefaultProperty:[[EMConversationModel alloc] initWithEMModel:conversation]];
        _isChatRecord = aIsChatRecord;
    }
    
    return self;
}

- (instancetype)initWithCoversationModel:(EMConversationModel *)aConversationModel
{
    self = [super init];
    if (self) {
        [self setDefaultProperty:aConversationModel];
    }
    
    return self;
}

- (void)setDefaultProperty:(EMConversationModel *)aConversationModel
{
    _conversationModel = aConversationModel;
    _msgQueue = dispatch_queue_create("emmessage.com", NULL);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.msgTimelTag = -1;
    self.type = 1;
    
    [self _setupChatSubviews];
    
    [[EMClient sharedClient] addMultiDevicesDelegate:self delegateQueue:nil];
    [[EMClient sharedClient].chatManager addDelegate:self delegateQueue:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWillPushCallController:) name:CALL_PUSH_VIEWCONTROLLER object:nil];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapTableViewAction:)];
    [self.tableView addGestureRecognizer:tap];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self tableViewDidTriggerHeaderRefresh];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [EMConversationHelper markAllAsRead:self.conversationModel];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyBoardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyBoardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    NSMutableDictionary *ext = [[NSMutableDictionary alloc]initWithDictionary:self.conversationModel.emModel.ext];
    //草稿
    if ([self.conversationModel.emModel.ext objectForKey:kConversation_Draft] && ![[self.conversationModel.emModel.ext objectForKey:kConversation_Draft] isEqualToString:@""]) {
        self.chatBar.textView.text = [self.conversationModel.emModel.ext objectForKey:kConversation_Draft];
        [self.chatBar textChangedExt];
        [ext setObject:@"" forKey:kConversation_Draft];
        [self.conversationModel.emModel setExt:ext];
    }
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void)dealloc
{
    [[EMClient sharedClient] removeMultiDevicesDelegate:self];
    [[EMClient sharedClient].chatManager removeDelegate:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Subviews

- (void)_setupChatSubviews
{
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[[UIImage imageNamed:@"backleft"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] style:UIBarButtonItemStylePlain target:self action:@selector(backAction)];
    [self _setupNavigationBarTitle];
    self.view.backgroundColor = [UIColor colorWithRed:242/255.0 green:242/255.0 blue:242/255.0 alpha:1.0];
    self.showRefreshHeader = YES;
    
    self.tableView.backgroundColor = kColor_LightGray;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 130;
    
    if (self.isChatRecord) [self _setupSwitchviews];
    
    self.searchBar.hidden = YES;
    self.chatBar = [[EMChatBar alloc] init];
    self.chatBar.delegate = self;
    [self.view addSubview:self.chatBar];
    [self.chatBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view);
        make.right.equalTo(self.view);
        make.bottom.equalTo(self.view);
    }];
    
    [self.chatBar.sendBtn addTarget:self action:@selector(_sendText) forControlEvents:UIControlEventTouchUpInside];
    //会话工具栏
    [self _setupChatBarMoreViews];
    
    [self.tableView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view);
        make.left.equalTo(self.view);
        make.right.equalTo(self.view);
        make.bottom.equalTo(self.chatBar.mas_top);
    }];
}

#pragma mark - SubviewsSwitch
//聊天记录类型
- (void)_setupSwitchviews
{
    self.chatBar.hidden = YES;
    self.searchBar.delegate = self;
    
    CGFloat width = (self.view.frame.size.width)/2;
    
    self.allRecordBtn = [[UIButton alloc]init];
    [_allRecordBtn setBackgroundColor:[UIColor whiteColor]];
    [_allRecordBtn setTitle:@"全部" forState:UIControlStateNormal];
    [_allRecordBtn setTitleColor:[UIColor colorWithRed:4/255.0 green:174/255.0 blue:240/255.0 alpha:1.0] forState:UIControlStateNormal];
    _allRecordBtn.titleLabel.font = [UIFont systemFontOfSize:16];
    _allRecordBtn.titleLabel.textAlignment = NSTextAlignmentCenter;
    _allRecordBtn.tag = 1;
    [_allRecordBtn addTarget:self action:@selector(cutRecordType:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.allRecordBtn];
    [_allRecordBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view);
        make.left.equalTo(self.view);
        make.width.mas_equalTo(width);
        make.height.equalTo(@40);
    }];
    
    self.picAndVideoRecordBtn = [[UIButton alloc]init];
    [_picAndVideoRecordBtn setBackgroundColor:[UIColor whiteColor]];
    [_picAndVideoRecordBtn setTitle:@"图片/视频" forState:UIControlStateNormal];
    _picAndVideoRecordBtn.titleLabel.font = [UIFont systemFontOfSize:16];
    _picAndVideoRecordBtn.titleLabel.textAlignment = NSTextAlignmentCenter;
    [_picAndVideoRecordBtn setTitleColor:[UIColor colorWithRed:51/255.0 green:51/255.0 blue:51/255.0 alpha:1.0] forState:UIControlStateNormal];
    _picAndVideoRecordBtn.tag = 2;
    [_picAndVideoRecordBtn addTarget:self action:@selector(cutRecordType:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.picAndVideoRecordBtn];
    [_picAndVideoRecordBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view);
        make.right.equalTo(self.view);
        make.width.mas_equalTo(width);
        make.height.equalTo(@40);
    }];
    
    [self.searchBar mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.allRecordBtn.mas_bottom);
        make.left.equalTo(self.view);
        make.width.mas_equalTo(width);
        make.height.equalTo(@40);
    }];
    
    self.picAndVideoRecordBtn = [[UIButton alloc]init];
    [_picAndVideoRecordBtn setBackgroundColor:[UIColor whiteColor]];
    [_picAndVideoRecordBtn setTitle:@"图片/视频" forState:UIControlStateNormal];
    _picAndVideoRecordBtn.titleLabel.font = [UIFont systemFontOfSize:16];
    _picAndVideoRecordBtn.titleLabel.textAlignment = NSTextAlignmentCenter;
    [_picAndVideoRecordBtn setTitleColor:[UIColor colorWithRed:51/255.0 green:51/255.0 blue:51/255.0 alpha:1.0] forState:UIControlStateNormal];
    _picAndVideoRecordBtn.tag = 2;
    [_picAndVideoRecordBtn addTarget:self action:@selector(cutRecordType:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.picAndVideoRecordBtn];
    [_picAndVideoRecordBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view);
        make.right.equalTo(self.view);
        make.height.equalTo(@50);
    }];
    
    [self.tableView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.searchBar.mas_bottom);
        make.left.right.bottom.equalTo(self.view);
    }];
    self.searchResultTableView.backgroundColor = kColor_LightGray;
    self.searchResultTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.searchResultTableView.rowHeight = UITableViewAutomaticDimension;
    self.searchResultTableView.estimatedRowHeight = 130;
    
}

- (void)_setupNavigationBarTitle
{
    UIView *titleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width * 06, 40)];
    titleView.backgroundColor = [UIColor lightGrayColor];
    
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [UIFont systemFontOfSize:18];
    self.titleLabel.textColor = [UIColor blackColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.backgroundColor = [UIColor redColor];
    self.titleLabel.text = self.isChatRecord ? @"查找聊天记录" : self.conversationModel.name;
    [titleView addSubview:self.titleLabel];
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(titleView);
        make.left.equalTo(titleView).offset(5);
        make.right.equalTo(titleView).offset(-5);
    }];
    
    self.titleDetailLabel = [[UILabel alloc] init];
    self.titleDetailLabel.font = [UIFont systemFontOfSize:15];
    self.titleDetailLabel.textColor = [UIColor grayColor];
    self.titleDetailLabel.textAlignment = NSTextAlignmentCenter;
    self.titleDetailLabel.backgroundColor = [UIColor blueColor];
    [titleView addSubview:self.titleDetailLabel];
    [self.titleDetailLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.titleLabel.mas_bottom);
        make.left.equalTo(self.titleLabel);
        make.right.equalTo(self.titleLabel);
        make.bottom.equalTo(titleView);
    }];
    
    self.navigationItem.titleView = titleView;
}

- (void)_setupChatBarMoreViews
{
    //语音
    NSString *path = [self _getAudioOrVideoPath];
    EMChatBarRecordAudioView *recordView = [[EMChatBarRecordAudioView alloc] initWithRecordPath:path];
    recordView.delegate = self;
    self.chatBar.recordAudioView = recordView;
    //表情
    EMChatBarEmoticonView *moreEmoticonView = [[EMChatBarEmoticonView alloc] init];
    moreEmoticonView.delegate = self;
    self.chatBar.moreEmoticonView = moreEmoticonView;
    
    //更多
    EMMoreFunctionView *moreFunction = [[EMMoreFunctionView alloc]initWithConversation:self.conversationModel.emModel];
    moreFunction.delegate = self;
    self.chatBar.moreFunctionView = moreFunction;
}

- (NSString *)_getAudioOrVideoPath
{
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    path = [path stringByAppendingPathComponent:@"EMDemoRecord"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return path;
}

//切换聊天记录类型
#pragma mark - cutRecordType
- (void)cutRecordType:(UIButton *)btn
{
    if (self.type == btn.tag) return;
    self.type = btn.tag;
    if (btn.tag == 1) {
        //全部记录
        [self.allRecordBtn setTitleColor:[UIColor colorWithRed:4/255.0 green:174/255.0 blue:240/255.0 alpha:1.0] forState:UIControlStateNormal];
        [self.picAndVideoRecordBtn setTitleColor:[UIColor colorWithRed:51/255.0 green:51/255.0 blue:51/255.0 alpha:1.0] forState:UIControlStateNormal];
        self.searchBar.hidden = NO;
        self.tableView.hidden = NO;
        self.searchResultTableView.hidden = NO;
        self.picAndVideoRecordTableView.hidden = YES;
        [self.tableView reloadData];
    }
    if (btn.tag == 2) {
        //图片与视频记录
        [self.allRecordBtn setTitleColor:[UIColor colorWithRed:51/255.0 green:51/255.0 blue:51/255.0 alpha:1.0] forState:UIControlStateNormal];
        [self.picAndVideoRecordBtn setTitleColor:[UIColor colorWithRed:4/255.0 green:174/255.0 blue:240/255.0 alpha:1.0] forState:UIControlStateNormal];
        self.searchBar.hidden = YES;
        self.tableView.hidden = YES;
        self.searchResultTableView.hidden = YES;
        self.picAndVideoRecordTableView.hidden = NO;
        [self picAndVideoRecord];
    }
}

//图片与视频
- (void)loadPicAndVideoRecordTableView
{
    self.picAndVideoRecordTableView = [[UITableView alloc] init];
    self.picAndVideoRecordTableView.tableFooterView = [[UIView alloc] init];
    self.picAndVideoRecordTableView.rowHeight = [UIScreen mainScreen].bounds.size.width / 4;
    self.picAndVideoRecordTableView.delegate = self;
    self.picAndVideoRecordTableView.dataSource = self;
    [self.view addSubview:self.picAndVideoRecordTableView];
    [self.picAndVideoRecordTableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view).offset(40);
        make.left.equalTo(self.view);
        make.right.equalTo(self.view);
        make.bottom.equalTo(self.view);
    }];
}

//获取聊天记录的图片&视频
- (void)picAndVideoRecord
{
    __weak typeof(self) weakself = self;
    //图片
    [self.conversationModel.emModel loadMessagesWithType:EMMessageBodyTypeImage timestamp:-1 count:50 fromUser:nil searchDirection:EMMessageSearchDirectionUp completion:^(NSArray *aMessages, EMError *aError) {
        NSArray *imgArray = [[NSArray alloc]init];
        imgArray = [weakself _formatRecordMsg:aMessages];
        //视频
        [self.conversationModel.emModel loadMessagesWithType:EMMessageBodyTypeVideo timestamp:-1 count:50 fromUser:nil searchDirection:EMMessageSearchDirectionUp completion:^(NSArray *aMessages, EMError *aError) {
            NSArray *videoArray = [[NSArray alloc]init];
            videoArray = [weakself _formatRecordMsg:aMessages];
            [weakself _sortChatRecord:imgArray videoArray:videoArray];
            [weakself loadPicAndVideoRecordTableView];
            [weakself.picAndVideoRecordTableView reloadData];
        }];
    }];
}
//格式化聊天记录图片&视频
- (NSArray *)_formatRecordMsg:(NSArray<EMMessage *> *)aMessages
{
    NSMutableArray *formated = [[NSMutableArray alloc] init];
    for (int i = 0; i < [aMessages count]; i++) {
        EMMessage *msg = aMessages[i];
        EMMessageModel *model = [[EMMessageModel alloc] initWithEMMessage:msg];
        [formated addObject:model];
    }
    return formated;
}

//排序聊天记录的图片与视频（按localtime本地时间）
- (void)_sortChatRecord:(NSArray *)imgArray videoArray:(NSArray *)videoArray
{
    NSMutableArray *recordMutableArray = [[NSMutableArray alloc]initWithArray:imgArray];
    long i = ([imgArray count] - 1);
    long v = ([videoArray count] - 1);
    
    EMMessageModel *imgModel;
    EMMessageModel *videoModel;
    while (v >= 0) {
        videoModel = (EMMessageModel *)[videoArray objectAtIndex:v];
        while (i > 0) {
            imgModel = (EMMessageModel *)[imgArray objectAtIndex:i];
            if (videoModel.emModel.localTime >= imgModel.emModel.localTime) {
                [recordMutableArray insertObject:videoModel atIndex:i+1];
                break;
            }
            if (videoModel.emModel.localTime < imgModel.emModel.localTime && videoModel.emModel.localTime >= ((EMMessageModel *)[imgArray objectAtIndex:(i-1)]).emModel.localTime) {
                [recordMutableArray insertObject:videoModel atIndex:i];
                break;
            }
            i--;
        }
        if (i == 0) {
            if (videoModel.emModel.localTime < ((EMMessageModel *)[imgArray objectAtIndex:0]).emModel.localTime) {
                [recordMutableArray insertObject:videoModel atIndex:0];
            }
        }
        v--;
    }
    NSMutableArray *tempArray1 = [[NSMutableArray alloc]init];
    NSMutableArray *tempArray2 = [[NSMutableArray alloc]init];
    i = 1;
    for (EMMessageModel *model in recordMutableArray) {
        [tempArray1 addObject:model];
        if (i % 4 == 0) {
            NSMutableArray *tempArray = [[NSMutableArray alloc]init];
            for (EMMessageModel *model in tempArray1) {
                [tempArray addObject:model];
            }
            [tempArray2 addObject:tempArray];
            [tempArray1 removeAllObjects];
        }
        ++i;
    }
    [tempArray2 addObject:tempArray1];
    self.recordArray = [[NSArray alloc]initWithArray:tempArray2];
}

#pragma mark - EMSearchBarDelegate

- (void)searchBarSearchButtonClicked:(NSString *)aString
{
    [self.view endEditing:YES];
    if (!self.isSearching) return;
    [self.conversationModel.emModel loadMessagesWithKeyword:aString timestamp:-1 count:50 fromUser:nil searchDirection:EMMessageSearchDirectionUp completion:^(NSArray *aMessages, EMError *aError) {
        if (!aError && [aMessages count] > 0) {
            __weak typeof(self) weakself = self;
            dispatch_async(self.msgQueue, ^{
                NSMutableArray *msgArray = [[NSMutableArray alloc] init];
                for (int i = 0; i < [aMessages count]; i++) {
                    EMMessage *msg = aMessages[i];
                    [msgArray addObject:msg];
                }
                NSArray *formated = [weakself _formatMessages:msgArray];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakself.searchResults removeAllObjects];
                    [weakself.searchResults addObjectsFromArray:formated];
                    [weakself.searchResultTableView reloadData];
                });
            });
        }
    }];
}

#pragma mark - Getter

- (UIImagePickerController *)imagePicker
{
    if (_imagePicker == nil) {
        _imagePicker = [[UIImagePickerController alloc] init];
        _imagePicker.modalPresentationStyle = UIModalPresentationOverFullScreen;
        _imagePicker.delegate = self;
    }
    
    return _imagePicker;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.tableView) return [self.dataArray count];
    if (tableView == self.searchResultTableView) return [self.searchResults count];
    return [self.recordArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    id obj = [self.recordArray objectAtIndex:indexPath.row];;
    if (tableView == self.tableView)
        obj = [self.dataArray objectAtIndex:indexPath.row];
    if (tableView == self.searchResultTableView)
        obj = [self.searchResults objectAtIndex:indexPath.row];
    NSString *cellString = nil;
    if ([obj isKindOfClass:[NSString class]])
        cellString = (NSString *)obj;
    if ([obj isKindOfClass:[EMMessageModel class]]) {
        EMMessageModel *model = (EMMessageModel *)obj;
        if (model.type == EMMessageTypeExtRecall)
            cellString = @"您撤回一条消息";
        if (model.type == EMMessageTypeExtNewFriend || model.type == EMMessageTypeExtAddGroup)
            cellString = ((EMTextMessageBody *)(model.emModel.body)).text;
    }
    
    if ([cellString length] > 0) {
        EMMessageTimeCell *cell = (EMMessageTimeCell *)[tableView dequeueReusableCellWithIdentifier:@"EMMessageTimeCell"];
        // Configure the cell...
        if (cell == nil)
            cell = [[EMMessageTimeCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"EMMessageTimeCell"];
        cell.timeLabel.text = cellString;
        return cell;
    }
    
    UITableViewCell *cell;
    if (!(tableView == self.picAndVideoRecordTableView)) {
        EMMessageModel *model = (EMMessageModel *)obj;
        NSString *identifier;
        identifier = [EMMessageCell cellIdentifierWithDirection:model.direction type:model.type];
        EMMessageCell *msgCell = (EMMessageCell *)[tableView dequeueReusableCellWithIdentifier:identifier];
        // Configure the cell...
        if (msgCell == nil) {
            msgCell = [[EMMessageCell alloc] initWithDirection:model.direction type:model.type];
            msgCell.delegate = self;
        }
        msgCell.model = model;
        cell = msgCell;
    } else {
        NSArray *modelArray = (NSArray *)obj;
        EMMsgRecordCell *msgCell = (EMMsgRecordCell *)[tableView dequeueReusableCellWithIdentifier:@"msgRecordCell"];
        // Configure the cell...
        if (msgCell == nil) {
            msgCell = [[EMMsgRecordCell alloc] init];
            //msgCell.delegate = self;
        }
        msgCell.models = modelArray;
        cell = msgCell;
    }
    return cell;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self.view endEditing:YES];
    [self.chatBar clearMoreViewAndSelectedButton];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    NSString *mediaType = info[UIImagePickerControllerMediaType];
    if ([mediaType isEqualToString:(NSString *)kUTTypeMovie]) {
        NSURL *videoURL = info[UIImagePickerControllerMediaURL];
        // we will convert it to mp4 format
        NSURL *mp4 = [self _videoConvert2Mp4:videoURL];
        NSFileManager *fileman = [NSFileManager defaultManager];
        if ([fileman fileExistsAtPath:videoURL.path]) {
            NSError *error = nil;
            [fileman removeItemAtURL:videoURL error:&error];
            if (error) {
                NSLog(@"failed to remove file, error:%@.", error);
            }
        }
        [self _sendVideoAction:mp4];
    } else {
        NSURL *url = info[UIImagePickerControllerReferenceURL];
        if (url == nil) {
            UIImage *orgImage = info[UIImagePickerControllerOriginalImage];
            NSData *data = UIImageJPEGRepresentation(orgImage, 1);
            [self _sendImageDataAction:data];
        } else {
            if ([[UIDevice currentDevice].systemVersion doubleValue] >= 9.0f) {
                PHFetchResult *result = [PHAsset fetchAssetsWithALAssetURLs:@[url] options:nil];
                [result enumerateObjectsUsingBlock:^(PHAsset *asset , NSUInteger idx, BOOL *stop){
                    if (asset) {
                        [[PHImageManager defaultManager] requestImageDataForAsset:asset options:nil resultHandler:^(NSData *data, NSString *uti, UIImageOrientation orientation, NSDictionary *dic){
                            if (data != nil) {
                                [self _sendImageDataAction:data];
                            } else {
                                [EMAlertController showErrorAlert:@"图片太大，请选择其他图片"];
                            }
                        }];
                    }
                }];
            } else {
                ALAssetsLibrary *alasset = [[ALAssetsLibrary alloc] init];
                [alasset assetForURL:url resultBlock:^(ALAsset *asset) {
                    if (asset) {
                        ALAssetRepresentation* assetRepresentation = [asset defaultRepresentation];
                        Byte *buffer = (Byte*)malloc((size_t)[assetRepresentation size]);
                        NSUInteger bufferSize = [assetRepresentation getBytes:buffer fromOffset:0.0 length:(NSUInteger)[assetRepresentation size] error:nil];
                        NSData *fileData = [NSData dataWithBytesNoCopy:buffer length:bufferSize freeWhenDone:YES];
                        [self _sendImageDataAction:fileData];
                    }
                } failureBlock:NULL];
            }
        }
    }
    
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    //TODO: 当弹出call页面时，与imagePicker冲突
    //    self.isViewDidAppear = YES;
    //    [[EaseSDKHelper shareHelper] setIsShowingimagePicker:NO];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self.imagePicker dismissViewControllerAnimated:YES completion:nil];
    
    //    self.isViewDidAppear = YES;
    //    [[EaseSDKHelper shareHelper] setIsShowingimagePicker:NO];
}

#pragma mark - EMMoreFunctionViewDelegate

- (void)chatBarMoreFunctionLocation
{
    EMLocationViewController *controller = [[EMLocationViewController alloc] init];
    [controller setSendCompletion:^(CLLocationCoordinate2D aCoordinate, NSString * _Nonnull aAddress) {
        [self _sendLocationAction:aCoordinate address:aAddress];
    }];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:controller];
    navController.modalPresentationStyle = 0;
    [self.navigationController presentViewController:navController animated:YES completion:nil];
}

- (void)chatBarMoreFunctionDidCallAction
{
    self.alertController = [UIAlertController alertControllerWithTitle:@"实时通话类型" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    __weak typeof(self) weakself = self;
    if (self.conversationModel.emModel.type == EMConversationTypeChat) {
        [self.alertController addAction:[UIAlertAction actionWithTitle:@"语音通话" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakself.chatBar clearMoreViewAndSelectedButton];
            [[NSNotificationCenter defaultCenter] postNotificationName:CALL_MAKE1V1 object:@{CALL_CHATTER:weakself.conversationModel.emModel.conversationId, CALL_TYPE:@(EMCallTypeVoice)}];
        }]];
        [self.alertController addAction:[UIAlertAction actionWithTitle:@"视频通话" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakself.chatBar clearMoreViewAndSelectedButton];
            [[NSNotificationCenter defaultCenter] postNotificationName:CALL_MAKE1V1 object:@{CALL_CHATTER:weakself.conversationModel.emModel.conversationId, CALL_TYPE:@(EMCallTypeVideo)}];
        }]];
        [self.alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        }]];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"didAlert" object:@{@"alert":self.alertController}];
        [self presentViewController:self.alertController animated:YES completion:nil];
        return;
    }
    [weakself.chatBar clearMoreViewAndSelectedButton];
    [[NSNotificationCenter defaultCenter] postNotificationName:CALL_MAKECONFERENCE object:@{CALL_TYPE:@(EMConferenceTypeCommunication), CALL_MODEL:weakself.conversationModel, NOTIF_NAVICONTROLLER:self.navigationController}];
}

- (void)chatBarDidShowMoreViewAction
{
    [self.tableView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self.chatBar.mas_top);
    }];
    
    [self performSelector:@selector(scrollToBottomRow) withObject:nil afterDelay:0.1];
}

- (void)chatBarMoreFunctionCameraAction
{
    [self.view endEditing:YES];
    
#if TARGET_IPHONE_SIMULATOR
    [EMAlertController showErrorAlert:@"模拟器不支持照相机"];
#elif TARGET_OS_IPHONE
    self.imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
    self.imagePicker.mediaTypes = @[(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie];
    [self presentViewController:self.imagePicker animated:YES completion:nil];
#endif
}

- (void)chatBarMoreFunctionPictureOption
{
    [self.view endEditing:YES];
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            switch (status) {
                case PHAuthorizationStatusAuthorized: //已获取权限
                {
                    self.imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
                    self.imagePicker.mediaTypes = @[(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie];
                    [self presentViewController:self.imagePicker animated:YES completion:nil];
                }
                    break;
                case PHAuthorizationStatusDenied: //用户已经明确否认了这一照片数据的应用程序访问
                    [EMAlertController showErrorAlert:@"不允许访问相册"];
                    break;
                case PHAuthorizationStatusRestricted://此应用程序没有被授权访问的照片数据。可能是家长控制权限
                    [EMAlertController showErrorAlert:@"没有授权访问相册"];
                    break;
                    
                default:
                    [EMAlertController showErrorAlert:@"访问相册失败"];
                    break;
            }
        });
    }];
}

- (void)chatBarMoreFunctionFileOption
{
    NSArray *documentTypes = @[@"public.content", @"public.text", @"public.source-code", @"public.image", @"public.jpeg", @"public.png", @"com.adobe.pdf", @"com.apple.keynote.key", @"com.microsoft.word.doc", @"com.microsoft.excel.xls", @"com.microsoft.powerpoint.ppt"];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:documentTypes inMode:UIDocumentPickerModeOpen];
    picker.delegate = self;
    picker.modalPresentationStyle = 0;
    [self presentViewController:picker animated:YES completion:nil];
    
    /*
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[PAirSandbox sharedInstance] showSandboxBrowser];
        [[PAirSandbox sharedInstance] setSendCompletion:^(NSURL *url) {
            NSRange rage = [[url absoluteString] rangeOfString:@"/" options:NSBackwardsSearch];
            NSString *displayName;
            if (rage.location != NSNotFound) {
                displayName = [[url absoluteString] substringFromIndex:rage.location+1];
            }
            EMFileMessageBody *body = [[EMFileMessageBody alloc]initWithLocalPath:[url relativePath] displayName:displayName];
            [self sendMessageWithBody:body ext:nil isUpload:NO];
        }];
    });*/
    /*
    EMPickFileViewController *pickFileController = [[EMPickFileViewController alloc]init];
    [self.navigationController pushViewController:pickFileController animated:NO];*/
}

#pragma mark - UIDocumentPickerDelegate
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray <NSURL *>*)urls
{
    BOOL fileAuthorized = [urls.firstObject startAccessingSecurityScopedResource];
    if (fileAuthorized) {
        [self selectedDocumentAtURLs:urls reName:nil];
        [urls.firstObject stopAccessingSecurityScopedResource];
        return;
    }
    [self showHint:@"授权失败!"];
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url
{
    BOOL fileAuthorized = [url startAccessingSecurityScopedResource];
    if (fileAuthorized) {
        [self selectedDocumentAtURLs:@[url] reName:nil];
        [url stopAccessingSecurityScopedResource];
        return;
    }
    [self showHint:@"授权失败!"];
}

//icloud
- (void)selectedDocumentAtURLs:(NSArray <NSURL *>*)urls reName:(NSString *)rename
{
    NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc]init];
    for (NSURL *url in urls) {
        NSError *error;
        [fileCoordinator coordinateReadingItemAtURL:url options:0 error:&error byAccessor:^(NSURL * _Nonnull newURL) {
            //读取文件
            NSString *fileName = [newURL lastPathComponent];
            NSError *error = nil;
            NSData *fileData = [NSData dataWithContentsOfURL:newURL options:NSDataReadingMappedIfSafe error:&error];
            if (error) {
                [self showHint:@"文件读取失败!"];
                return;
            }
            NSLog(@"fileName: %@\nfileUrl: %@", fileName, newURL);
            EMFileMessageBody *body = [[EMFileMessageBody alloc]initWithData:fileData displayName:fileName];
            [self sendMessageWithBody:body ext:nil isUpload:NO];
        }];
    }
}

#pragma mark - EMChatBarRecordAudioViewDelegate

- (void)chatBarRecordAudioViewStartRecord
{
    
}

- (void)chatBarRecordAudioViewStopRecord:(NSString *)aPath
                              timeLength:(NSInteger)aTimeLength
{
    EMVoiceMessageBody *body = [[EMVoiceMessageBody alloc] initWithLocalPath:aPath displayName:@"audio"];
    body.duration = (int)aTimeLength;
    if(body.duration < 1){
        [self showHint:@"按键时间太短."];
        return;
    }
    [self sendMessageWithBody:body ext:nil isUpload:YES];
}

- (void)chatBarRecordAudioViewCancelRecord
{
    
}

#pragma mark - EMChatBarEmoticonViewDelegate

- (void)didSelectedEmoticonModel:(EMEmoticonModel *)aModel
{
    if (aModel.type == EMEmotionTypeEmoji)
        [self.chatBar inputViewAppendText:aModel.name];
    
    if (aModel.type == EMEmotionTypeGif) {
        NSDictionary *ext = @{MSG_EXT_GIF:@(YES), MSG_EXT_GIF_ID:aModel.eId};
        [self sendTextAction:aModel.name ext:ext];
    }
}

- (void)didChatBarEmoticonViewSendAction
{
    [self sendTextAction:self.chatBar.textView.text ext:nil];
}

#pragma mark - EMMessageCellDelegate

- (void)messageCellDidSelected:(EMMessageCell *)aCell
{
    //消息事件策略分类
    EMMessageEventStrategy *eventStrategy = [EMMessageEventStrategyFactory getStratrgyImplWithMsgCell:aCell];
    eventStrategy.chatController = self;
    [eventStrategy messageCellEventOperation:aCell];
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)messageCellDidLongPress:(EMMessageCell *)aCell
{
    self.menuIndexPath = [self.tableView indexPathForCell:aCell];
    [UIMenuController sharedMenuController].menuItems = [self showMenuViewController:aCell model:aCell.model];
    [UIMenuController sharedMenuController].menuVisible = YES;
    [[UIMenuController sharedMenuController] setTargetRect:aCell.bubbleView.frame inView:aCell];
}

- (void)messageCellDidResend:(EMMessageModel *)aModel
{
    if (aModel.emModel.status != EMMessageStatusFailed && aModel.emModel.status != EMMessageStatusPending) {
        return;
    }
    
    __weak typeof(self) weakself = self;
    [[[EMClient sharedClient] chatManager] resendMessage:aModel.emModel progress:nil completion:^(EMMessage *message, EMError *error) {
        [weakself.tableView reloadData];
    }];
    
    [self.tableView reloadData];
}

#pragma mark -- UIDocumentInteractionControllerDelegate
- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller
{
    return self;
}
- (UIView*)documentInteractionControllerViewForPreview:(UIDocumentInteractionController*)controller
{
    return self.view;
}
- (CGRect)documentInteractionControllerRectForPreview:(UIDocumentInteractionController*)controller
{
    return self.view.frame;
}

#pragma mark - EMMultiDevicesDelegate

- (void)multiDevicesGroupEventDidReceive:(EMMultiDevicesEvent)aEvent
                                 groupId:(NSString *)aGroupId
                                     ext:(id)aExt
{
    if (aEvent == EMMultiDevicesEventGroupDestroy || aEvent == EMMultiDevicesEventGroupLeave) {
        if ([self.conversationModel.emModel.conversationId isEqualToString:aGroupId]) {
            [self.navigationController popToViewController:self animated:YES];
            [self.navigationController popViewControllerAnimated:YES];
        }
    }
}

#pragma mark - EMChatManagerDelegate

- (void)messagesDidReceive:(NSArray *)aMessages
{
    __weak typeof(self) weakself = self;
    dispatch_async(self.msgQueue, ^{
        NSString *conId = weakself.conversationModel.emModel.conversationId;
        NSMutableArray *msgArray = [[NSMutableArray alloc] init];
        for (int i = 0; i < [aMessages count]; i++) {
            EMMessage *msg = aMessages[i];
            if (![msg.conversationId isEqualToString:conId]) {
                continue;
            }
            [weakself returnReceipt:msg];
            [weakself.conversationModel.emModel markMessageAsReadWithId:msg.messageId error:nil];
            [msgArray addObject:msg];
        }
        
        NSArray *formated = [weakself _formatMessages:msgArray];
        [weakself.dataArray addObjectsFromArray:formated];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakself refreshTableView];
        });
    });
}

- (void)messagesDidRecall:(NSArray *)aMessages {
    __block NSMutableArray *sameObject = [NSMutableArray array];
    [aMessages enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        EMMessage *msg = (EMMessage *)obj;
        [self.dataArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj isKindOfClass:[EMMessageModel class]]) {
                EMMessageModel *model = (EMMessageModel *)obj;
                if ([model.emModel.messageId isEqualToString:msg.messageId]) {
                    // 如果上一行是时间，且下一行也是时间
                    if (idx - 1 >= 0) {
                        id nextMessage = nil;
                        id prevMessage = [self.dataArray objectAtIndex:(idx - 1)];
                        if (idx + 1 < [self.dataArray count]) {
                            nextMessage = [self.dataArray objectAtIndex:(idx + 1)];
                        }
                        if ((!nextMessage
                             || [nextMessage isKindOfClass:[NSString class]])
                            && [prevMessage isKindOfClass:[NSString class]]) {
                            [sameObject addObject:prevMessage];
                        }
                    }
                    
                    [sameObject addObject:model];
                    *stop = YES;
                }
            }
        }];
    }];
    
    if (sameObject.count > 0) {
        for (id obj in sameObject) {
            [self.dataArray removeObject:obj];
        }
        
        [self.tableView reloadData];
    }
}

//为了从home会话列表切进来触发 群组阅读回执 和 消息已读回执
- (void)sendDidReadReceipt
{
    __weak typeof(self) weakself = self;
    NSString *conId = weakself.conversationModel.emModel.conversationId;
    void (^block)(NSArray *aMessages, EMError *aError) = ^(NSArray *aMessages, EMError *aError) {
        if (!aError && [aMessages count]) {
            for (int i = 0; i < [aMessages count]; i++) {
                   EMMessage *msg = aMessages[i];
                   if (![msg.conversationId isEqualToString:conId]) {
                       continue;
                   }
                   [weakself returnReceipt:msg];
                [weakself.conversationModel.emModel markMessageAsReadWithId:msg.messageId error:nil];
               }
        }
    };
    
    [self.conversationModel.emModel loadMessagesStartFromId:self.moreMsgId count:self.conversationModel.emModel.unreadMessagesCount searchDirection:EMMessageSearchDirectionUp completion:block];
}

- (void)messageStatusDidChange:(EMMessage *)aMessage
                         error:(EMError *)aError
{
    __weak typeof(self) weakself = self;
    dispatch_async(self.msgQueue, ^{
        NSString *conId = weakself.conversationModel.emModel.conversationId;
        if (![conId isEqualToString:aMessage.conversationId]){
            return ;
        }
        
        __block NSUInteger index = NSNotFound;
        __block EMMessageModel *reloadModel = nil;
        [self.dataArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj isKindOfClass:[EMMessageModel class]]) {
                EMMessageModel *model = (EMMessageModel *)obj;
                if ([model.emModel.messageId isEqualToString:aMessage.messageId]) {
                    reloadModel = model;
                    index = idx;
                    *stop = YES;
                }
            }
        }];
        
        if (index != NSNotFound) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakself.dataArray replaceObjectAtIndex:index withObject:reloadModel];
                [weakself.tableView beginUpdates];
                [weakself.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
                [weakself.tableView endUpdates];
            });
        }
        
    });
}

#pragma mark - KeyBoard

- (void)keyBoardWillShow:(NSNotification *)note
{
    // 获取用户信息
    NSDictionary *userInfo = [NSDictionary dictionaryWithDictionary:note.userInfo];
    // 获取键盘高度
    CGRect keyBoardBounds  = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat keyBoardHeight = keyBoardBounds.size.height;
    // 获取键盘动画时间
    CGFloat animationTime  = [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    
    // 定义好动作
    void (^animation)(void) = ^void(void) {
        [self.chatBar mas_updateConstraints:^(MASConstraintMaker *make) {
            make.bottom.equalTo(self.view).offset(-keyBoardHeight);
        }];
    };
    
    if (animationTime > 0) {
        [UIView animateWithDuration:animationTime animations:animation completion:^(BOOL finished) {
            [self scrollToBottomRow];
        }];
    } else {
        animation();
    }
}

- (void)keyBoardWillHide:(NSNotification *)note
{
    // 获取用户信息
    NSDictionary *userInfo = [NSDictionary dictionaryWithDictionary:note.userInfo];
    // 获取键盘动画时间
    CGFloat animationTime  = [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    
    // 定义好动作
    void (^animation)(void) = ^void(void) {
        [self.chatBar mas_updateConstraints:^(MASConstraintMaker *make) {
            make.bottom.equalTo(self.view);
        }];
    };
    
    if (animationTime > 0) {
        [UIView animateWithDuration:animationTime animations:animation];
    } else {
        animation();
    }
}

#pragma mark - NSNotification

- (void)handleWillPushCallController:(NSNotification *)aNotif
{
    [self.imagePicker dismissViewControllerAnimated:YES completion:nil];
    [[EMImageBrowser sharedBrowser] dismissViewController];
    [[EMAudioPlayerHelper sharedHelper] stopPlayer];
}

#pragma mark - Gesture Recognizer

- (void)handleTapTableViewAction:(UITapGestureRecognizer *)aTap
{
    if (aTap.state == UIGestureRecognizerStateEnded) {
        [self.view endEditing:YES];
        [self.chatBar clearMoreViewAndSelectedButton];
    }
}

- (void)scrollToBottomRow
{
    NSInteger toRow = -1;
    if (self.isSearching) {
        if ([self.searchResults count] > 0) {
            toRow = self.searchResults.count - 1;
            NSIndexPath *toIndexPath = [NSIndexPath indexPathForRow:toRow inSection:0];
            [self.searchResultTableView scrollToRowAtIndexPath:toIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:NO];
        }
        return;
    }
    if ([self.dataArray count] > 0) {
        toRow = self.dataArray.count - 1;
        NSIndexPath *toIndexPath = [NSIndexPath indexPathForRow:toRow inSection:0];
        [self.tableView scrollToRowAtIndexPath:toIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:NO];
    }
}

- (void)_showCustomTransferFileAlertView
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"(づ｡◕‿‿◕｡)づ" message:@"需要自定义实现上传附件方法" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:okAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (NSURL *)_videoConvert2Mp4:(NSURL *)movUrl
{
    NSURL *mp4Url = nil;
    AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:movUrl options:nil];
    NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:avAsset];
    
    if ([compatiblePresets containsObject:AVAssetExportPresetHighestQuality]) {
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc]initWithAsset:avAsset presetName:AVAssetExportPresetHighestQuality];
        NSString *mp4Path = [NSString stringWithFormat:@"%@/%d%d.mp4", [self _getAudioOrVideoPath], (int)[[NSDate date] timeIntervalSince1970], arc4random() % 100000];
        mp4Url = [NSURL fileURLWithPath:mp4Path];
        exportSession.outputURL = mp4Url;
        exportSession.shouldOptimizeForNetworkUse = YES;
        exportSession.outputFileType = AVFileTypeMPEG4;
        dispatch_semaphore_t wait = dispatch_semaphore_create(0l);
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            switch ([exportSession status]) {
                case AVAssetExportSessionStatusFailed: {
                    NSLog(@"failed, error:%@.", exportSession.error);
                } break;
                case AVAssetExportSessionStatusCancelled: {
                    NSLog(@"cancelled.");
                } break;
                case AVAssetExportSessionStatusCompleted: {
                    NSLog(@"completed.");
                } break;
                default: {
                    NSLog(@"others.");
                } break;
            }
            dispatch_semaphore_signal(wait);
        }];
        long timeout = dispatch_semaphore_wait(wait, DISPATCH_TIME_FOREVER);
        if (timeout) {
            NSLog(@"timeout.");
        }
        
        if (wait) {
            //dispatch_release(wait);
            wait = nil;
        }
    }
    
    return mp4Url;
}

#pragma mark - Send Message

- (void)_sendText
{
    if(self.chatBar.sendBtn.tag == 1){
        [self sendTextAction:self.chatBar.textView.text ext:nil];
    }
}

- (void)sendTextAction:(NSString *)aText
                    ext:(NSDictionary *)aExt
{
    if(![aExt objectForKey:MSG_EXT_GIF]){
        [self.chatBar clearInputViewText];
    }
    if ([aText length] == 0) {
        return;
    }
    
    //TODO: 处理@
    //messageExt
    
    //TODO: 处理表情
    //    NSString *sendText = [EaseConvertToCommonEmoticonsHelper convertToCommonEmoticons:aText];
    
    EMTextMessageBody *body = [[EMTextMessageBody alloc] initWithText:aText];
    [self sendMessageWithBody:body ext:aExt isUpload:NO];
}

- (void)_sendImageDataAction:(NSData *)aImageData
{
    EMImageMessageBody *body = [[EMImageMessageBody alloc] initWithData:aImageData displayName:@"image"];
    [self sendMessageWithBody:body ext:nil isUpload:YES];
}

- (void)_sendLocationAction:(CLLocationCoordinate2D)aCoord
                    address:(NSString *)aAddress
{
    EMLocationMessageBody *body = [[EMLocationMessageBody alloc] initWithLatitude:aCoord.latitude longitude:aCoord.longitude address:aAddress];
    [self sendMessageWithBody:body ext:nil isUpload:NO];
}

- (void)_sendVideoAction:(NSURL *)aUrl
{
    EMVideoMessageBody *body = [[EMVideoMessageBody alloc] initWithLocalPath:[aUrl path] displayName:@"video.mp4"];
    [self sendMessageWithBody:body ext:nil isUpload:YES];
}

#pragma mark - Data

- (NSArray *)_formatMessages:(NSArray<EMMessage *> *)aMessages
{
    NSMutableArray *formated = [[NSMutableArray alloc] init];

    for (int i = 0; i < [aMessages count]; i++) {
        EMMessage *msg = aMessages[i];
        if (msg.chatType == EMChatTypeChat && msg.isReadAcked && (msg.body.type == EMMessageBodyTypeText || msg.body.type == EMMessageBodyTypeLocation)) {
            //
            [[EMClient sharedClient].chatManager sendMessageReadAck:msg.messageId toUser:msg.conversationId completion:nil];
        } else if (msg.chatType == EMChatTypeGroupChat && !msg.isReadAcked && (msg.body.type == EMMessageBodyTypeText || msg.body.type == EMMessageBodyTypeLocation)) {
        }
        
        CGFloat interval = (self.msgTimelTag - msg.timestamp) / 1000;
        if (self.msgTimelTag < 0 || interval > 60 || interval < -60) {
            NSString *timeStr = [EMDateHelper formattedTimeFromTimeInterval:msg.timestamp];
            [formated addObject:timeStr];
            self.msgTimelTag = msg.timestamp;
        }
        
        EMMessageModel *model = [[EMMessageModel alloc] initWithEMMessage:msg];

        [formated addObject:model];
    }
    
    return formated;
}

- (void)tableViewDidTriggerHeaderRefresh
{
    __weak typeof(self) weakself = self;
    void (^block)(NSArray *aMessages, EMError *aError) = ^(NSArray *aMessages, EMError *aError) {
        if (!aError && [aMessages count]) {
            EMMessage *msg = aMessages[0];
            weakself.moreMsgId = msg.messageId;
            
            dispatch_async(self.msgQueue, ^{
                NSArray *formated = [weakself _formatMessages:aMessages];
                [weakself.dataArray insertObjects:formated atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [formated count])]];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakself refreshTableView];
                });
            });
        }
        
        [weakself tableViewDidFinishTriggerHeader:YES reload:NO];
    };
    
    if ([EMDemoOptions sharedOptions].isPriorityGetMsgFromServer) {
        EMConversation *conversation = self.conversationModel.emModel;
        [EMClient.sharedClient.chatManager asyncFetchHistoryMessagesFromServer:conversation.conversationId conversationType:conversation.type startMessageId:self.moreMsgId pageSize:50 completion:^(EMCursorResult *aResult, EMError *aError) {
            block(aResult.list, aError);
         }];
    } else {
        /*
        *  从数据库获取指定数量的消息，取到的消息按时间排序，并且不包含参考的消息，如果参考消息的ID为空，则从最新消息取
        *
        *  @param aMessageId       参考消息的ID
        *  @param count            获取的条数
        *  @param aDirection       消息搜索方向
        *  @param aCompletionBlock 完成的回调
         */
        [self.conversationModel.emModel loadMessagesStartFromId:self.moreMsgId count:50 searchDirection:EMMessageSearchDirectionUp completion:block];
        if(self.conversationModel.emModel.unreadMessagesCount > 0){
            [self sendDidReadReceipt];
        }
    }
}

#pragma mark - Action

- (void)backAction
{
    [[EMAudioPlayerHelper sharedHelper] stopPlayer];
    [EMConversationHelper resortConversationsLatestMessage];
    
    EMConversation *conversation = self.conversationModel.emModel;
    if (conversation.type == EMChatTypeChatRoom) {
        [[EMClient sharedClient].roomManager leaveChatroom:conversation.conversationId completion:nil];
    } else {
        //草稿
        if (self.chatBar.textView.text.length > 0) {
            NSMutableDictionary *ext = [[NSMutableDictionary alloc]initWithDictionary:self.conversationModel.emModel.ext];
            [ext setObject:self.chatBar.textView.text forKey:kConversation_Draft];
            [self.conversationModel.emModel setExt:ext];
        }
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}

//发送消息体
- (void)sendMessageWithBody:(EMMessageBody *)aBody
                         ext:(NSDictionary * __nullable)aExt
                    isUpload:(BOOL)aIsUpload
{
    if (!([EMClient sharedClient].options.isAutoTransferMessageAttachments) && aIsUpload) {
        [self _showCustomTransferFileAlertView];
        return;
    }
    
    NSString *from = [[EMClient sharedClient] currentUsername];
    NSString *to = self.conversationModel.emModel.conversationId;
    EMMessage *message = [[EMMessage alloc] initWithConversationID:to from:from to:to body:aBody ext:aExt];
    
    //是否需要发送阅读回执
    if([aExt objectForKey:MSG_EXT_READ_RECEIPT])
        message.isNeedGroupAck = YES;
    
    message.chatType = (EMChatType)self.conversationModel.emModel.type;
    
    __weak typeof(self) weakself = self;
    NSArray *formated = [weakself _formatMessages:@[message]];
    [self.dataArray addObjectsFromArray:formated];
    if (!self.moreMsgId)
        //新会话的第一条消息
        self.moreMsgId = message.messageId;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakself refreshTableView];
    });
    [[EMClient sharedClient].chatManager sendMessage:message progress:nil completion:^(EMMessage *message, EMError *error) {
        NSLog(@"errorCode    %u   errorDesc    %@",error.code,error.errorDescription);
        if (error) [EMAlertController showErrorAlert:error.errorDescription];
        [weakself messageStatusDidChange:message error:error];
    }];
}

#pragma mark - Public

- (void)returnReceipt:(EMMessage *)msg{}

- (void)refreshTableView
{
    [self.tableView reloadData];
    [self.tableView setNeedsLayout];
    [self.tableView layoutIfNeeded];
    [self scrollToBottomRow];
}

@end
