//
//  BindDevProgressViewController.m
//  JiafeigouiOS
//
//  Created by 杨利 on 16/6/16.
//  Copyright © 2016年 lirenguang. All rights reserved.
//  

#import "BindDevProgressViewController.h"
#import "BindProgressAnimationView.h"
#import "UIView+FLExtensionForFrame.h"
#import "SetDevNicNameViewController.h"
#import "DevicesViewModel.h"
#import "AddDeviceErrorVC.h"
#import <JFGSDK/JFGSDKBindingDevice.h>
#import "JfgMsgDefine.h"
#import <JFGSDK/JFGSDK.h>
#import "JfgUserDefaultKey.h"
#import <JFGSDK/MPMessagePackReader.h>
#import "JfgLanguage.h"
#import "JfgConfig.h"
#import "dataPointMsg.h"
#import "AddDeviceMainViewController.h"
#import "JFGBoundDevicesMsg.h"
#import "NSTimer+FLExtension.h"
#import "VideoPlayFor720ViewController.h"
#import "UIColor+HexColor.h"
#import "LSAlertView.h"
#import "JFGGrayPolicyManager.h"
#import "PropertyManager.h"
#import "MTA.h"

@interface BindDevProgressViewController ()<JFGSDKBindDeviceDelegate,UIAlertViewDelegate,JFGSDKCallbackDelegate>
{
    NSString *currentCid;
    BOOL isShowOuttime;
    NSTimer *timeOutTimer;
    NSTimer *checkNetTimer;
    int timeCount;
}
@property (nonatomic,strong)UIButton *backBtn;
@property (nonatomic,strong)BindProgressAnimationView *animationView;
@property (nonatomic, strong) JFGSDKBindingDevice *bindingDeviceSDK;
@property (nonatomic,strong)UILabel *detailLabel;
@property (nonatomic,strong)PropertyManager *propertyTool;

@property (nonatomic, strong) DevicesViewModel *devicesVM;
@property (nonatomic, strong) NSMutableArray *cacheCidList;
@property (nonatomic, assign) BOOL deviceIsOnline;
@property (nonatomic, assign) BOOL isBindSuccess;
@property (nonatomic, assign) BOOL isPushedToSuccess;

@end

@implementation BindDevProgressViewController
int const timeoutDuration = 90; // 90秒 超时

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.automaticallyAdjustsScrollViewInsets = NO;
    self.navigationView.hidden = YES;
    [self.view addSubview:self.backBtn];
    [self.view addSubview:self.animationView];
    [self.view addSubview:self.detailLabel];
    //开启屏幕常亮
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
    [self.animationView starAnimation];
    [self getCacheCidList];
    if (self.pType == productType_720) {
        [self.bindingDeviceSDK bindDevFor720WithSn:@"" ssid:self.wifiName key:self.wifiPassWord];
    }else if (self.pType == productType_wired){
        [self.bindingDeviceSDK bindDevWithSn:self.cid devMacAddr:self.macAddr isRebind:NO];
    }else{
        [self.bindingDeviceSDK bindDevWithSn:@"" ssid:self.wifiName key:self.wifiPassWord];
    }
    
    isShowOuttime = YES;
    [JFGSDK appendStringToLogFile:@"startOuttimeCount"];
    
    timeCount = 0;
    timeOutTimer = [NSTimer bk_scheduledTimerWithTimeInterval:1 block:^(NSTimer *timer) {
        
        timeCount ++ ;
        if (timeCount > timeoutDuration) {
            [self netConnectTimeout];
            [timeOutTimer invalidate];
            timeOutTimer = nil;
            
            if (checkNetTimer && checkNetTimer.isValid) {
                [checkNetTimer invalidate];
                checkNetTimer = nil;
            }
        }
        [JFGSDK appendStringToLogFile:[NSString stringWithFormat:@"BindDevTimeCount:%d",timeCount]];
        
    } repeats:YES];
    
    [MTA trackCustomKeyValueEvent:@"AddDev_bindProgress" props:@{}];
    
//    int64_t delayInSeconds = timeoutDuration;
//    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
//    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
//        
//        if (isShowOuttime) {
//            [JFGSDK appendStringToLogFile:@"isShowOuttime"];
//            [self netConnectTimeout];
//        }else{
//            [JFGSDK appendStringToLogFile:@"isNotShowOuttime"];
//        }
//        
//    });
    //[self performSelector:@selector(netConnectTimeout) withObject:nil afterDelay:timeoutDuration];
    // Do any additional setup after loading the view.
}

-(void)getCacheCidList
{
    NSArray *cidlist = [[JFGBoundDevicesMsg sharedDeciceMsg] getDevicesList];
    self.cacheCidList = [[NSMutableArray alloc]init];
    for (JiafeigouDevStatuModel *model in cidlist) {
        [self.cacheCidList addObject:[NSString stringWithString:model.uuid]];
    }
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:JFGNotShowOffnetKey];
    [JFGSDK addDelegate:self];
    self.bindingDeviceSDK.delegate = self;
    // 禁用 iOS7 返回手势
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:JFGNotShowOffnetKey];
    [JFGSDK removeDelegate:self];
    self.bindingDeviceSDK.delegate = nil;
    
    if (timeOutTimer && timeOutTimer.isValid) {
        [timeOutTimer invalidate];
        timeOutTimer = nil;
    }
    
    if (checkNetTimer && checkNetTimer.isValid) {
        [checkNetTimer invalidate];
        checkNetTimer = nil;
    }
    
    //关闭屏幕常亮
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    // 开启
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    }
}

//重新开始绑定，动画重新开始
-(void)restartBindDev
{
    
}

-(void)back
{
    __weak typeof(self) weakSelf = self;
    [LSAlertView showAlertWithTitle:nil Message:[JfgLanguage getLanTextStrByKey:@"Tap1_AddDevice_tips"] CancelButtonTitle:[JfgLanguage getLanTextStrByKey:@"CANCEL"] OtherButtonTitle:[JfgLanguage getLanTextStrByKey:@"OK"] CancelBlock:^{
        
    } OKBlock:^{
        
        
        if (timeOutTimer && [timeOutTimer isValid]) {
            [timeOutTimer invalidate];
            timeOutTimer = nil;
        }
        
        if (weakSelf.navigationController){
            for (UIViewController *temp in weakSelf.navigationController.viewControllers)
            {
                if ([temp isKindOfClass:[AddDeviceMainViewController class]] || [temp isKindOfClass:[VideoPlayFor720ViewController class]])
                {
                    [weakSelf.navigationController popToViewController:temp animated:YES];
                    return ;
                }
            }
            [weakSelf.navigationController popViewControllerAnimated:YES];
            
        }else{
            
            [weakSelf dismissViewControllerAnimated:YES completion:nil];
        }
    }];
    
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 1024 && buttonIndex == 1) {
        
        if (self.navigationController){
            for (UIViewController *temp in self.navigationController.viewControllers)
            {
                if ([temp isKindOfClass:[AddDeviceMainViewController class]])
                {
                    [self.navigationController popToViewController:temp animated:YES];
                }else if ([temp isKindOfClass:[VideoPlayFor720ViewController class]]){
                    [self.navigationController popToViewController:temp animated:YES];
                }
            }
            
        }else{
            [self dismissViewControllerAnimated:YES completion:nil];
        }
        
    }
}


#pragma mark 
#pragma mark  push to VC
- (void)pushToBindErrorVC:(int)errorType errorMsg:(NSString *)msg
{
    //isShowOuttime = NO;
    if (timeOutTimer && [timeOutTimer isValid]) {
        [timeOutTimer invalidate];
        timeOutTimer = nil;
    }
    [JFGSDK appendStringToLogFile:[NSString stringWithFormat:@"bindError [%d]", errorType]];
    AddDeviceErrorVC *errorVC = [AddDeviceErrorVC new];
    errorVC.errorType = errorType;
    errorVC.pType = self.pType;
    errorVC.errorMsg = msg;
    [self.navigationController pushViewController:errorVC animated:YES];
    
    [MTA trackCustomKeyValueEvent:@"AddDev_bindResult" props:@{@"result":@"failed",@"error":[NSString stringWithFormat:@"%ld",(long)errorType]}];
}

- (void)pushToBindSuccessVC:(NSString *)cid
{
       //[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(netConnectTimeout) object:nil];
    [JFGSDK appendStringToLogFile:[NSString stringWithFormat:@"deviceIsOnline[%d]   isReceiveRsp [%d]",self.deviceIsOnline,self.isBindSuccess]];

    //设置默认值方法已经转移到JFGBoundDevicesMsg.m类中的#setDefaultValue方法。（次数设置，因为cidList还没有返回，会导致设置失败，而且pType绑定的时候并不准确）
    [self setSettingsRedDot:cid]; // 红点
    if (!self.isPushedToSuccess)
    {
        if (self.deviceIsOnline && self.isBindSuccess)
        {
            if (timeOutTimer && [timeOutTimer isValid]) {
                [timeOutTimer invalidate];
                timeOutTimer = nil;
            }
            
            [MTA trackCustomKeyValueEvent:@"AddDev_bindResult" props:@{@"result":@"success",@"error":@"0"}];

            __block BindDevProgressViewController *blockSelf = self;
            
            [self.animationView successAnimationWithCompletionBlock:^{
                SetDevNicNameViewController *se = [SetDevNicNameViewController new];
                se.cid = currentCid;
                se.pType = blockSelf.pType;
                se.configType = blockSelf.configType;
                [blockSelf.navigationController pushViewController:se animated:YES];
                blockSelf.isPushedToSuccess = YES;
            }];
        }
        
    }else{
        [JFGSDK appendStringToLogFile:[NSString stringWithFormat:@"already pushed to successVC [%d]",self.isPushedToSuccess]];
    }
}

#pragma mark- JFG SDK Delegate
-(void)jfgNetworkChanged:(JFGNetType)netType
{
    if (netType == JFGNetTypeOffline) {
        [JFGSDK appendStringToLogFile:@"bindDev netOffline"];
    }else{
        [JFGSDK appendStringToLogFile:@"bindDev netRecover"];
    }
}

#pragma mark receive push_msg
- (void)jfgRobotSyncDataForPeer:(NSString *)peer fromDev:(BOOL)isDev msgList:(NSArray<DataPointSeg *> *)msgList
{
    @try
    {
        BOOL isNewDevice = YES;
        for (NSString *cid in self.cacheCidList) {
            if ([peer isEqualToString:cid]) {
                isNewDevice = NO;
            }
        }
        
        if (isNewDevice || [self.cid isEqualToString:peer]) {
            for (DataPointSeg *seg in msgList)
            {
                NSError *error = nil;
                id obj = [MPMessagePackReader readData:seg.value error:&error];
                [JFGSDK appendStringToLogFile:[NSString stringWithFormat:@"被动网络推送:%@: %@",peer,[obj description]]];
                switch (seg.msgId)
                {
                    case dpMsgBase_Net:
                    {
                        if ([obj isKindOfClass:[NSArray class]])
                        {
                            NSArray *objArr = obj;
                            if (objArr.count>0)
                            {
                                int netType = [[objArr objectAtIndex:0] intValue];
                                switch (netType)
                                {
                                    case DeviceNetType_2G:
                                    case DeviceNetType_3G:
                                    case DeviceNetType_4G:
                                    case DeviceNetType_5G:
                                    case DeviceNetType_Wifi:
                                    case DeviceNetType_Wired:
                                    {
                                        self.isBindSuccess = YES;
                                        self.deviceIsOnline = YES;
                                        [self pushToBindSuccessVC:currentCid];
                                    }
                                    default:
                                        break;
                                }
                                
                            }
                        }
                        
                    }
                        break;
                }
            }

        }
    } @catch (NSException *exception) {
        [JFGSDK appendStringToLogFile:[NSString stringWithFormat:@"jifeigou RootViewControl %@",exception]];
    } @finally {
        
    }
}

-(void)netConnectTimeout
{
    [self.animationView failedAnimation];
    [self pushToBindErrorVC:BindResultType_Timeout errorMsg:@""];
}

-(void)jfgBindDeviceProgressStatus:(JFGSDKBindindProgressStatus)status
{
    switch (status)
    {
        case JFGSDKBindindProgressStatusPing:
            break;
        case JFGSDKBindindProgressStatusConfigureStart:
            break;
        case JFGSDKBindindProgressStatusConfigureSuccess:
            break;
        case JFGSDKBindindProgressStatusStartBinding:
            break;
        case JFGSDKBindindProgressStatusSuccess:
        {
            
        }
            break;
        case JFGSDKBindindProgressStatusCIDBinding:
        {
            
        }
            break;
        default:
            break;
    }
}

-(void)fjgBindDeviceSuccessForPeer:(NSString *)peer
{
    //重置灰度时间
    [JFGGrayPolicyManager resetGrayTime];
    self.isBindSuccess = YES;
    if ([peer isKindOfClass:[NSString class]] && ![peer isEqualToString:@""]) {
        self.cid = [NSString stringWithString:peer];
    }
    currentCid = self.cid;
    [JFGSDK appendStringToLogFile:[NSString stringWithFormat:@"bindSuccess:%@",peer?peer:nil]];
    [self pushToBindSuccessVC:peer];
    //记录新增加的设备cid，用于刷新cid列表时候，设置默认值
    [[JFGBoundDevicesMsg sharedDeciceMsg] addNewDeviceForCid:self.cid];
    [self startCheckNetTimer];
    
}

-(void)jfgBindDeviceFailed:(JFGSDKBindindProgressStatus)errorType errorMsg:(NSString *)errorMsg
{
    [self.animationView failedAnimation];
    [self pushToBindErrorVC:errorType errorMsg:errorMsg];
    
}

-(void)jfgDeviceList:(NSArray<JFGSDKDevice *> *)deviceList
{
    NSString *addCid = nil;
    for (JFGSDKDevice *dev in deviceList) {
        
        BOOL isExist = NO;
        for (NSString *cid in self.cacheCidList) {
            if ([dev.uuid isEqualToString:cid]) {
                isExist = YES;
                break;
            }
        }
        if (!isExist) {
            
            addCid = dev.uuid;
            
        }
    }
    
    if (addCid) {
        currentCid = addCid;
    }
    [JFGSDK appendStringToLogFile:[NSString stringWithFormat:@"deviceListForAddCid:%@",addCid?addCid:@""]];
    [self startCheckNetTimer];
}

-(void)startCheckNetTimer
{
    if (checkNetTimer && checkNetTimer.isValid) {
        [checkNetTimer invalidate];
        checkNetTimer = nil;
    }
    
    __weak typeof(self) weakSelf = self;
    
    checkNetTimer = [NSTimer bk_scheduledTimerWithTimeInterval:3 block:^(NSTimer *timer) {
        NSLog(@"检测网络");
        [weakSelf checkDeviceNetStatue];
    } repeats:YES];
}

- (void)setSettingsRedDot:(NSString *)peer
{
    BOOL isOpenDeepSleep = NO;//绑定后是否会自动开启省电休眠模式
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    [dateFormatter setDateFormat:@"HH"];
    NSString *hour = [dateFormatter stringFromDate:[NSDate date]];
    if ([hour intValue]>=22 || [hour intValue] <=8) {
        isOpenDeepSleep = YES;
    }
    
    if ([self.propertyTool showRowWithPid:self.pType key:pRemoteWatchKey] && isOpenDeepSleep) {
        //绑定设备后，会自动设置默认22：00 -- 8：00开启省电休眠模式，如果设备支持此功能，且在这个时间段绑定设备，设置默认之后，就会进入休眠，所有设置功能不可用，小红点也不显示
    }else{
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:isShowAutoPhotoRedDot(peer)];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:isShowRecordRedDot(peer)];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:isShowSafeAIRedDot(peer)];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    if ([self.propertyTool showRowWithPid:self.pType key:pRemoteWatchKey]) {
         [[NSUserDefaults standardUserDefaults] setBool:YES forKey:isShowDeepSleepRedDot(peer)];
    }
}

-(void)checkDeviceNetStatue
{
    if (currentCid && ![currentCid isEqualToString:@""]) {
        
        [[dataPointMsg shared] packSingleDataPointMsg:@[@(dpMsgBase_Net)] withCid:currentCid SuccessBlock:^(NSMutableDictionary *dic) {
            NSArray *wifiArray = [dic objectForKey:msgBaseNetKey];
            [JFGSDK appendStringToLogFile:[NSString stringWithFormat:@"主动检测网络:%@",[wifiArray description]]];
            
            if (wifiArray.count >= 2)
            {
                switch ([[wifiArray objectAtIndex:0] integerValue])
                {
                    case DeviceNetType_2G:
                    case DeviceNetType_3G:
                    case DeviceNetType_4G:
                    case DeviceNetType_5G:
                    case DeviceNetType_Wifi:
                    case DeviceNetType_Wired:
                    {
                        self.deviceIsOnline = YES;
                        [self pushToBindSuccessVC:currentCid];
                    }
                        break;
                        
                    default:
                        break;
                }
            }else{
                
                
            }
        } FailBlock:^(RobotDataRequestErrorType error) {
            
            
            
        }];
    }
   
}

#pragma mark- getter
-(UIButton *)backBtn
{
    if (!_backBtn) {
        //20 36
        _backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _backBtn.frame = CGRectMake(10, 74*0.5, 30, 30);
        [_backBtn setImage:[UIImage imageNamed:@"btn_return"] forState:UIControlStateNormal];
        [_backBtn addTarget:self action:@selector(back) forControlEvents:UIControlEventTouchUpInside];
    }
    return _backBtn;
}



-(BindProgressAnimationView *)animationView
{
    if (!_animationView) {
        _animationView = [[BindProgressAnimationView alloc]initWithFrame:CGRectMake(0, self.view.height*0.28-25, 0, 0)];
        _animationView.x = self.view.x;
        __block id blockSelf = self;
        _animationView.bindResetBlock = ^(){
            [blockSelf restartBindDev];
        };
    }
    return _animationView;
}

- (JFGSDKBindingDevice *)bindingDeviceSDK
{
    if (_bindingDeviceSDK == nil)
    {
        _bindingDeviceSDK = [[JFGSDKBindingDevice alloc] init];
        _bindingDeviceSDK.delegate = self;
    }
    return _bindingDeviceSDK;
}

- (DevicesViewModel *)devicesVM
{
    if (_devicesVM == nil)
    {
        _devicesVM = [[DevicesViewModel alloc] init];
        _devicesVM.pType = self.pType;
    }
    
    return _devicesVM;
}

-(UILabel *)detailLabel
{
    if (!_detailLabel) {
        _detailLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, self.animationView.bottom, self.view.width, 19)];
        _detailLabel.font = [UIFont systemFontOfSize:18];
        _detailLabel.textColor = [UIColor colorWithHexString:@"#888888"];
        _detailLabel.text = [JfgLanguage getLanTextStrByKey:@"PLEASE_WAIT_2"];
        _detailLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _detailLabel;
}

- (PropertyManager *)propertyTool
{
    if (_propertyTool == nil)
    {
        _propertyTool = [[PropertyManager alloc] init];
        _propertyTool.propertyFilePath = [[NSBundle mainBundle] pathForResource:@"properties" ofType:@"json"];
    }
    return _propertyTool;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
