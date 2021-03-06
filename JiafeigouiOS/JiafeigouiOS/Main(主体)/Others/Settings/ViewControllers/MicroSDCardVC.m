//
//  MicroSDCardVC.m
//  JiafeigouiOS
//
//  Created by lirenguang on 2017/2/14.
//  Copyright © 2017年 lirenguang. All rights reserved.
//

#import "MicroSDCardVC.h"
#import "JfgGlobal.h"
#import "LSAlertView.h"
#import "JfgMsgDefine.h"
#import <JFGSDK/JFGSDKDataPoint.h>
#import "JfgLanguage.h"
#import "JfgHttp.h"
#import "ProgressHUD.h"
#import "dataPointMsg.h"
#import "LoginManager.h"
#import "CommonMethod.h"
#import "JfgConstKey.h"
#import "NetworkMonitor.h"
#import <JFGSDK/JFGSDK.h>
#import "MTA.h"

@interface MicroSDCardVC ()<JFGSDKCallbackDelegate, LoginManagerDelegate>

@property (nonatomic, strong) UIView *topBgView;
@property (nonatomic, strong) UIView *centerViewInTop;
@property (nonatomic, strong) UILabel *sdCardUseLabel; //SD卡 使用情况
@property (nonatomic, strong) UIProgressView *sdCardProgress;

@property (nonatomic, strong) UIButton *clearSDCardButton;

@property (nonatomic, strong) UILabel *resetTipLabel;

@property (nonatomic, strong) UIActivityIndicatorView *loadingActivity;

@property (nonatomic, assign) CGFloat totalSpace;
@property (nonatomic, copy) NSString *totalSpaceStr;

@property (nonatomic, assign) CGFloat usedSpace;
@property (nonatomic, copy) NSString *usedSpaceStr;

@property (nonatomic, copy) NSString *ipAddress;

@end

@implementation MicroSDCardVC

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self initView];
    [self initNavigation];
    [self initData];
    
    [JFGSDK addDelegate:self];
    [[LoginManager sharedManager] addDelegate:self];
    
    [self setButtonEnable:([NetworkMonitor sharedManager].currentNetworkStatu != NotReachable)];
    
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [JFGSDK removeDelegate:self];
    [ProgressHUD dismiss];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)initData
{
    if ([CommonMethod isConnectedAPWithPid:self.pType Cid:self.cid])
    {
        [JFGSDK fping:@"255.255.255.255"];
        [JFGSDK fping:@"192.168.10.255"];
        [self setButtonEnable:NO];
    }
    else
    {
        JFG_WS(weakSelf);
        
        switch (self.pType)
        {
            case productType_720:
            case productType_720p:
            {
                // sd卡状态
                DataPointSeg *seg1 = [DataPointSeg new];
                seg1.msgId = dpMsgBase_SDStatus;
                seg1.value = [NSData data];
                seg1.version = 0;
                
                // net
                DataPointSeg *seg2 = [DataPointSeg new];
                seg2.msgId = dpMsgBase_Net;
                seg2.value = [NSData data];
                seg2.version = 0;
                
                
                [JFGSDK sendDPDataMsgForSockWithPeer:self.cid dpMsgIDs:@[seg1, seg2]];
            }
                break;
                
            default:
            {
                [[dataPointMsg shared] packSingleDataPointMsg:@[@(dpMsgBase_SDStatus), @(dpMsgBase_Net)] withCid:self.cid SuccessBlock:^(NSMutableDictionary *dic)
                 {
                     NSArray *sdInfos = [dic objectForKey:msgBaseSDStatusKey];
                     if (sdInfos.count >= 4)
                     {
                         BOOL sdCardError = [[sdInfos objectAtIndex:2] intValue];
                         BOOL isSDCardExist = [[sdInfos objectAtIndex:3] boolValue];
                         
                         if (isSDCardExist && sdCardError == 0)
                         {
                             weakSelf.totalSpace = [[sdInfos objectAtIndex:0] longLongValue];
                             weakSelf.usedSpace = [[sdInfos objectAtIndex:1] longLongValue];
                             weakSelf.sdCardProgress.progress = weakSelf.usedSpace/weakSelf.totalSpace;
                             weakSelf.sdCardUseLabel.text = [NSString stringWithFormat:[JfgLanguage getLanTextStrByKey:@"Tap1_Camera_SpaceUsage"],weakSelf.usedSpaceStr, weakSelf.totalSpaceStr];
                         }
                         
                     }
                     
                     NSArray *netArr = [dic objectForKey:msgBaseNetKey];
                     if (netArr.count >= 2)
                     {
                         int netType = [[netArr objectAtIndex:0] intValue];
                         
                         if (netType == DeviceNetType_Offline || netType == DeviceNetType_Connetct)
                         {
                             [weakSelf setButtonEnable:NO];
                         }
                     }
                 } FailBlock:^(RobotDataRequestErrorType error) {
                     
                 }];
            }
                break;
        }
    }
    
    
    
}

- (void)beginClearSDCard
{
    JFG_WS(weakself);
    
    if (self.usedSpace == 0)
    {
        [ProgressHUD showText:[JfgLanguage getLanTextStrByKey:@"Clear_Sdcard_tips3"]];
        return;
    }
    
    [MTA trackCustomKeyValueEvent:@"DevSetting_clearSDCard" props:@{}];
    
    [LSAlertView showAlertWithTitle:[JfgLanguage getLanTextStrByKey:@"Clear_Sdcard_tips"] Message:nil CancelButtonTitle:[JfgLanguage getLanTextStrByKey:@"CANCEL"] OtherButtonTitle:[JfgLanguage getLanTextStrByKey:@"CARRY_ON"] CancelBlock:^{
        
    } OKBlock:^{
        [weakself performSelector:@selector(clearSDCardError) withObject:nil afterDelay:120.0];
        [weakself setButtonEnable:NO];
        DataPointSeg *seg =[[DataPointSeg alloc]init];
        seg.msgId = dpMsgBase_FormatSD;
        seg.version = 0;
        [ProgressHUD showProgress:nil Interaction:YES];
        
        if (self.ipAddress != nil && ![self.ipAddress isEqualToString:@""])
        {
            [[JfgHttp sharedHttp] get:[NSString stringWithFormat:@"http://%@/cgi/ctrl.cgi?Msg=sdFormat", self.ipAddress] parameters:nil progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
                
                if ([[responseObject objectForKey:panoSdCardError] intValue] == 0)
                {
                    [weakself sdCardClearFinished];
                }
                
            } failure:^(NSURLSessionDataTask *task, NSError *error) {
                
            }];
        }
        else
        {
            [[JFGSDKDataPoint sharedClient] robotSetDataWithPeer:weakself.cid dps:@[seg] success:^(NSArray<DataPointIDVerRetSeg *> *dataList) {
            } failure:^(RobotDataRequestErrorType type) {
                [weakself clearSDCardError];
            }];
        }
        
        
    }];
}

- (void)sdCardClearFinished
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    [self setButtonEnable:YES];
    self.usedSpace = 0;
    self.sdCardUseLabel.text = [NSString stringWithFormat:[JfgLanguage getLanTextStrByKey:@"Tap1_Camera_SpaceUsage"],self.usedSpaceStr, self.totalSpaceStr];
    self.sdCardProgress.progress = 0.0f;
    
    [ProgressHUD showText:[JfgLanguage getLanTextStrByKey:@"Clear_Sdcard_tips3"]];
}

- (void)clearSDCardError
{
    [self setButtonEnable:YES];
    [ProgressHUD showText:[JfgLanguage getLanTextStrByKey:@"Clear_Sdcard_tips4"]];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

#pragma mark
#pragma mark  action
- (void)leftButtonAction:(UIButton *)sender
{
    [super leftButtonAction:sender];
}

- (void)clearSDCardAction:(UIButton *)sender
{
    [self beginClearSDCard];
}

#pragma mark
#pragma mark  view
- (void)initView
{
    [self.view addSubview:self.topBgView];
    [self.topBgView addSubview:self.sdCardUseLabel];
    [self.topBgView addSubview:self.sdCardProgress];
    
    [self.view addSubview:self.clearSDCardButton];
    [self.clearSDCardButton addSubview:self.loadingActivity];
    [self.view addSubview:self.resetTipLabel];
    
    self.view.backgroundColor = [UIColor colorWithHexString:@"#f0f0f0"];
}

- (void)initNavigation
{
    self.titleLabel.text = [JfgLanguage getLanTextStrByKey:@"SETTING_SD"];
    
    [self.leftButton addTarget:self action:@selector(leftButtonAction:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)setButtonEnable:(BOOL)enable
{
    self.clearSDCardButton.enabled = enable;
    self.clearSDCardButton.alpha = enable?1.0:0.6;
}

#pragma mark
#pragma mark login delegate
- (void)loginSuccess
{
    [self initData];
}

#pragma mark
#pragma mark delegate
- (void)jfgFpingRespose:(JFGSDKUDPResposeFping *)ask
{
    if ([self.cid isEqualToString:ask.cid])
    {
        [self setButtonEnable:YES];
        self.ipAddress = ask.address;
        
        JFG_WS(weakself);
        
        [[JfgHttp sharedHttp] get:[NSString stringWithFormat:@"http://%@/cgi/ctrl.cgi?Msg=getSdInfo", self.ipAddress] parameters:nil progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
            
            weakself.totalSpace = [[responseObject objectForKey:panoSdCardTotalStorage] floatValue];
            weakself.usedSpace = [[responseObject objectForKey:panoSdCardUsedStorage] floatValue];
            weakself.sdCardProgress.progress = weakself.usedSpace/weakself.totalSpace;
            weakself.sdCardUseLabel.text = [NSString stringWithFormat:[JfgLanguage getLanTextStrByKey:@"Tap1_Camera_SpaceUsage"],weakself.usedSpaceStr, weakself.totalSpaceStr];
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            
        }];
    }
}

-(void)jfgNetworkChanged:(JFGNetType)netType
{
    if (netType == JFGNetTypeOffline || netType == JFGNetTypeConnect)
    {
        [self setButtonEnable:NO];
    }
    else
    {
        [self setButtonEnable:YES];
    }
    
}

-(void)jfgDPMsgRobotForwardDataV2AckForTcpWithMsgID:(NSString *)msgID
                                               mSeq:(uint64_t)mSeq
                                                cid:(NSString *)cid
                                               type:(int)type
                                       isInitiative:(BOOL)initiative
                                           dpMsgArr:(NSArray *)dpMsgArr
{
    
    JFG_WS(weakSelf);
    for (DataPointSeg *seg in dpMsgArr)
    {
        NSError *error = nil;
        id obj = [MPMessagePackReader readData:seg.value error:&error];
        if (error == nil)
        {
            switch (seg.msgId)
            {
                // SDCard 插拔
                case dpMsgBase_SDStatus:
                {
                    if ([obj isKindOfClass:[NSArray class]])
                    {
                        BOOL isExistSDCard = [[obj objectAtIndex:3] boolValue];
                        int sdCardError = [[obj objectAtIndex:2] intValue];
                        
                        if (isExistSDCard == NO && self.isShare == NO)
                        {
                            [LSAlertView disMiss];
                            
                            //创建一个调度时间,相对于默认时钟或修改现有的调度时间。
                            dispatch_time_t delayInNanoSeconds =dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC);
                            //推迟两纳秒执行
                            dispatch_queue_t concurrentQueue =dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                            dispatch_after(delayInNanoSeconds, concurrentQueue, ^(void){
                                [LSAlertView showAlertWithTitle:[JfgLanguage getLanTextStrByKey:@"MSG_SD_OFF"] Message:nil CancelButtonTitle:[JfgLanguage getLanTextStrByKey:@"OK"] OtherButtonTitle:nil CancelBlock:^{
                                    [self leftButtonAction:nil];
                                } OKBlock:^{
                                    
                                }];
                            });
                            
                        }
                        else // exist SDcard
                        {
                            if (sdCardError == 0)
                            {
                                weakSelf.totalSpace = [[obj objectAtIndex:0] longLongValue];
                                weakSelf.usedSpace = [[obj objectAtIndex:1] longLongValue];
                                weakSelf.sdCardProgress.progress = weakSelf.usedSpace/weakSelf.totalSpace;
                                weakSelf.sdCardUseLabel.text = [NSString stringWithFormat:[JfgLanguage getLanTextStrByKey:@"Tap1_Camera_SpaceUsage"],weakSelf.usedSpaceStr, weakSelf.totalSpaceStr];
                            }
                        }
                        
                    }
                }
                    break;
                case dpMsgBase_SDCardFomat:
                {
                    [self sdCardClearFinished];
                }
                    break;
            }
        }
    }
}

- (void)jfgRobotSyncDataForPeer:(NSString *)peer fromDev:(BOOL)isDev msgList:(NSArray<DataPointSeg *> *)msgList
{
    @try
    {
        if ([peer isEqualToString:self.cid])
        {
            for (DataPointSeg *seg in msgList)
            {
                [self handlePushMsg:seg];
            }
        }
        
    } @catch (NSException *exception) {
        [JFGSDK appendStringToLogFile:[NSString stringWithFormat:@"jifeigou MicroDSCardVC %@",exception]];
    } @finally {
        
    }
}

- (void)handlePushMsg:(DataPointSeg *)seg
{
    NSError *error = nil;
    id obj = [MPMessagePackReader readData:seg.value error:&error];
    if (error == nil)
    {
        switch (seg.msgId)
        {
                // SDCard 插拔
            case dpMsgBase_SDCardInfoList:
            {
                if ([obj isKindOfClass:[NSArray class]])
                {
                    BOOL isExistSDCard = [[obj objectAtIndex:0] boolValue];
                    
                    if (isExistSDCard == NO && self.isShare == NO)
                    {
                        [LSAlertView disMiss];
                        
                        //创建一个调度时间,相对于默认时钟或修改现有的调度时间。
                        dispatch_time_t delayInNanoSeconds =dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC);
                        //推迟两纳秒执行
                        dispatch_queue_t concurrentQueue =dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                        dispatch_after(delayInNanoSeconds, concurrentQueue, ^(void){
                            [LSAlertView showAlertWithTitle:[JfgLanguage getLanTextStrByKey:@"MSG_SD_OFF"] Message:nil CancelButtonTitle:[JfgLanguage getLanTextStrByKey:@"OK"] OtherButtonTitle:nil CancelBlock:^{
                                [self leftButtonAction:nil];
                            } OKBlock:^{
                                
                            }];
                        });
                        
                    }
                    
                }
            }
                break;
            case dpMsgBase_SDStatus:
            {
                self.totalSpace = [[obj objectAtIndex:0] longLongValue];
                self.usedSpace = [[obj objectAtIndex:1] longLongValue];
                self.sdCardProgress.progress = self.usedSpace/self.totalSpace;
                self.sdCardUseLabel.text = [NSString stringWithFormat:[JfgLanguage getLanTextStrByKey:@"Tap1_Camera_SpaceUsage"],self.usedSpaceStr, self.totalSpaceStr];
            }
                break;
            case dpMsgBase_SDCardFomat:
            {
                [self sdCardClearFinished];
            }
                break;
        }
    }
}

#pragma mark
#pragma mark property
- (UIView *)topBgView
{
    if (_topBgView == nil)
    {
        CGFloat x = 0;
        CGFloat y = 20 + 44 + 20;
        CGFloat width = Kwidth;
        CGFloat height = 80.0f;
        
        _topBgView = [[UIView alloc] initWithFrame:CGRectMake(x, y, width, height)];
        _topBgView.backgroundColor = [UIColor whiteColor];
        // 射🐔 描边癖
        _topBgView.layer.borderWidth = 0.5f;
        _topBgView.layer.borderColor = [UIColor colorWithHexString:@"#e1e1e1"].CGColor;
    }
    
    return _topBgView;
}

- (UILabel *)sdCardUseLabel
{
    CGFloat height = 13.0f;
    CGFloat x = 15;
    CGFloat y = self.topBgView.height*0.5 - height - 5.0;
    CGFloat width = Kwidth - x*2;
    
    if (_sdCardUseLabel == nil)
    {
        _sdCardUseLabel = [[UILabel alloc] initWithFrame:CGRectMake(x, y, width, height)];
        _sdCardUseLabel.textAlignment = NSTextAlignmentLeft;
        _sdCardUseLabel.font = [UIFont systemFontOfSize:height];
        _sdCardUseLabel.text = [NSString stringWithFormat:[JfgLanguage getLanTextStrByKey:@"Tap1_Camera_SpaceUsage"],self.usedSpaceStr, self.totalSpaceStr];
        _sdCardUseLabel.textColor = [UIColor colorWithHexString:@"8c8c8c"];
    }
    return _sdCardUseLabel;
}

- (UIProgressView *)sdCardProgress
{
    if (_sdCardProgress == nil)
    {
        CGFloat x = 15;
        CGFloat y = self.topBgView.height*0.5 + 5;
        CGFloat width = Kwidth - x*2;
        CGFloat height = 5.0f;
        
        _sdCardProgress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        _sdCardProgress.frame = CGRectMake(x, y, width, height);
        _sdCardProgress.progress = 0.0f;
        _sdCardProgress.progressTintColor = [UIColor colorWithHexString:@"#6fa3fd"];
        _sdCardProgress.trackTintColor = [UIColor colorWithHexString:@"#d2d2d2"];
    }
    return _sdCardProgress;
}

- (UIButton *)clearSDCardButton
{
    if (_clearSDCardButton == nil)
    {
        CGFloat x = 0;
        CGFloat y = self.topBgView.bottom + 20.0f;
        CGFloat width = Kwidth;
        CGFloat height = 44.0f;
        
        _clearSDCardButton = [[UIButton alloc] initWithFrame:CGRectMake(x, y, width, height)];
        [_clearSDCardButton.titleLabel setFont:[UIFont systemFontOfSize:16.0f]];
        [_clearSDCardButton setTitle:[JfgLanguage getLanTextStrByKey:@"Clear_Sdcard"] forState:UIControlStateNormal];
        [_clearSDCardButton setTitleColor:[UIColor colorWithHexString:@"#333333"] forState:UIControlStateNormal];
        [_clearSDCardButton setBackgroundColor:[UIColor whiteColor]];
        // 射🐔 描边癖
        _clearSDCardButton.layer.borderWidth = 0.5f;
        _clearSDCardButton.layer.borderColor = [UIColor colorWithHexString:@"#e1e1e1"].CGColor;
        [_clearSDCardButton addTarget:self action:@selector(clearSDCardAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _clearSDCardButton;
}

- (UILabel *)resetTipLabel
{
    if (_resetTipLabel == nil)
    {
        CGFloat x = 0;
        CGFloat y = self.clearSDCardButton.bottom + 9.0f;
        CGFloat width = Kwidth;
        CGFloat height = 13.0f;
        
        _resetTipLabel = [[UILabel alloc] initWithFrame:CGRectMake(x, y, width, height)];
        _resetTipLabel.textAlignment = NSTextAlignmentCenter;
        _resetTipLabel.text = [JfgLanguage getLanTextStrByKey:@"Clear_Sdcard_tips2"];
        _resetTipLabel.textColor = [UIColor colorWithHexString:@"#666666"];
        _resetTipLabel.font = [UIFont systemFontOfSize:height];
        _resetTipLabel.hidden = (self.pType == productType_3G || self.pType == productType_3G_2X)?NO:YES;
    }
    
    return _resetTipLabel;
}

- (UIActivityIndicatorView *)loadingActivity
{
    if (_loadingActivity == nil)
    {
        CGSize labelSize = CGSizeOfString([JfgLanguage getLanTextStrByKey:@"Clear_Sdcard"], CGSizeMake(self.clearSDCardButton.width, kheight), [UIFont systemFontOfSize:16.0f]);
        
        CGFloat width = 35.0f;
        CGFloat height = 35.0f;
        CGFloat y = (self.clearSDCardButton.height - height)*0.5;
        CGFloat x = (labelSize.width+self.clearSDCardButton.width)*0.5 + 5.0f;
        
        _loadingActivity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _loadingActivity.frame = CGRectMake(x, y, width, height);
        _loadingActivity.hidden = YES;
    }
    
    return _loadingActivity;
}

- (NSString *)totalSpaceStr
{
    _totalSpaceStr = [NSString stringWithFormat:@"%.2f GB",self.totalSpace/1024/1024/1024.0];
    
    return _totalSpaceStr;
}
- (NSString *)usedSpaceStr
{
    _usedSpaceStr = [NSString stringWithFormat:@"%.2f GB",self.usedSpace/1024/1024/1024.0];
    
    return _usedSpaceStr;
}
@end
