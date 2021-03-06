//
//  ConfigWiFiViewController.m
//  JiafeigouiOS
//
//  Created by Michiko on 16/6/15.
//  Copyright © 2016年 lirenguang. All rights reserved.
//

#import "ConfigWiFiViewController.h"
#import "FLGlobal.h"
#import "DelButton.h"
#import "WifiListView.h"
#import "UIColor+HexColor.h"
#import "UIView+FLExtensionForFrame.h"
#import "BindDevProgressViewController.h"
#import "JfgUserDefaultKey.h"
#import "JfgLanguage.h"
#import <JFGSDK/JFGSDK.h>
#import "AddDeviceGuideViewController.h"
#import <KVOController.h>
#import "DeviceSettingVC.h"
#import "UIAlertView+FLExtension.h"
#import "ProgressHUD.h"
#import "SetWifiLoadingFor720VC.h"
#import "CommonMethod.h"
#import "PilotLampStateVC.h"
#import "LSAlertView.h"
#import "NSTimer+FLExtension.h"
#import <JFGSDK/JFGSDKDataPoint.h>
#import "PropertyManager.h"
#import "LoginManager.h"
#import "MTA.h"

#define kScreen_Scale [UIScreen mainScreen].bounds.size.width/375.0f
#define kTop 100*kScreen_Scale
#define kLeft 20*kScreen_Scale
#define kLineWidth Kwidth-40*kScreen_Scale

@interface ConfigWiFiViewController ()<UITextFieldDelegate,JFGSDKCallbackDelegate,UIAlertViewDelegate>
{
    NSDictionary *cacheWifiListDict;
    NSTimer *timeOutTimer;
    int timeCount;
    BOOL isAwaysFping;
}
@property(nonatomic, strong)UILabel * titleLabel;
@property(nonatomic, strong)UITextField * wifiNameTF;
@property(nonatomic, strong)UILabel * lineLabel_top;
@property(nonatomic, strong)UITextField * wifiPasswordTF;
@property(nonatomic, strong)UILabel * lineLabel_bottom;
@property(nonatomic, strong)UILabel * tipLabel;
@property(nonatomic, strong)UIButton * nextButton;
@property(nonatomic, strong)UIButton *wifiListButton;
@property(nonatomic, strong)DelButton *exitBtn;
@property(nonatomic, strong)UIButton *declareBtn;
@property(nonatomic, copy) NSString *ipAddress;
@property(nonatomic, copy) NSString *macStr;

@end

@implementation ConfigWiFiViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self.view addSubview:self.titleLabel];
    
    [self.view addSubview:self.wifiNameTF];

    [self.view addSubview:self.lineLabel_top];
    
    [self.view addSubview:self.wifiPasswordTF];
//
    [self.view addSubview:self.lineLabel_bottom];
    
    [self.view addSubview:self.tipLabel];
    
    [self.view addSubview:self.nextButton];
    
    [self.view addSubview:[self pwTextFieldRightView]];
    if (self.pType == productType_720) {
        [self.view addSubview:self.declareBtn];
    }
    if (self.configType == configWifiType_setHotspot) {
        self.wifiNameTF.text = [UIDevice currentDevice].name;
        self.wifiNameTF.enabled = NO;
    }

    [self.view addSubview:self.wifiListButton];
    [self.view insertSubview:self.wifiListButton aboveSubview:self.wifiNameTF];
    self.wifiListButton.hidden = YES;
    [self.view addSubview:self.exitBtn];
    [JFGSDK addDelegate:self];
    //fping获取设备信息
    [JFGSDK fping:@"255.255.255.255"];
    [JFGSDK fping:@"192.168.10.255"];
    [MTA trackCustomKeyValueEvent:@"AddDev_configWifi" props:@{}];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    // 禁用 iOS7 返回手势
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
    cacheWifiListDict = nil;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    // 开启
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    }
    [super viewDidDisappear:animated];
    [ProgressHUD dismiss];
}

-(void)jfgFpingRespose:(JFGSDKUDPResposeFping *)ask
{
    if (isAwaysFping) {
        return;
    }
    //AP直连
    if ([[CommonMethod currentConnecttedWifi] hasPrefix:@"DOG"] || [[CommonMethod currentConnecttedWifi] hasPrefix:@"BELL"]) {
        
        self.cid = ask.cid;
        self.macStr = ask.mac;
        self.ipAddress = ask.address;
        [self devTypeWithCid:self.cid];
        
    }else{
        
        if ([self.cid isKindOfClass:[NSString class]] && [self.cid isEqualToString:ask.cid]) {
            self.macStr = ask.mac;
            self.ipAddress = ask.address;
            [self devTypeWithCid:self.cid];
        }
    }
}

-(void)devTypeWithCid:(NSString *)cid
{
    [JFGSDK appendStringToLogFile:[NSString stringWithFormat:@"bindDevFpingAction:%@",cid]];
    if (self.configType != configWifiType_setHotspot){
        
        if (cid && ![cid isEqualToString:@""]) {
            
            BOOL isDoor = NO;
            PropertyManager *pm = [[PropertyManager alloc]init];
            pm.propertyFilePath = [[NSBundle mainBundle] pathForResource:@"properties" ofType:@"json"];
            NSArray *propertyArr = [pm propertyArr];
            for (NSDictionary *dict in propertyArr) {
                NSString *pr = dict[pCidPrefixKey];
                if ([cid hasPrefix:pr]) {
                    
                    NSString *pid = dict[pOSKey];
                    //以下门铃设备不显示wifi下拉列表
                    NSArray *wifiListOS = @[@6,@15,@17,@22,@24,@26,@27,@28,@42,@44,@46,@50];
                    for (NSNumber *os in wifiListOS) {
                        if ([os integerValue] == [pid intValue]) {
                            isDoor = YES;
                            break;
                        }
                    }
                    break;
                }
            }
            isAwaysFping = YES;
            self.wifiListButton.hidden = isDoor;
        }
    }
}

#pragma mark - 按钮事件
-(void)nextButtonAction:(UIButton *)button
{
    // 公共判断区域
    //断开了ap连接
    BOOL isConnectAp = [jfgConfigManager isAPModel];
    /////
//    if (self.wifiNameTF.left == 0) {
//        
//        [ProgressHUD showText:[JfgLanguage getLanTextStrByKey:@"ENTER_WIFI"]];
//        return;
//    }
    
    // 分开 处理
    
    switch (self.configType)
    {
        case configWifiType_configWifi:
        {
            [JFGSDK appendStringToLogFile:[NSString stringWithFormat:@"wifiName:%@  wifiPasword:%@",self.wifiNameTF.text,self.wifiPasswordTF.text]];
            //@"192.168.10.255"
            if (self.pType == productType_AI_Camera || self.pType == productType_AI_Camera_outdoor) {
                 [JFGSDK wifiSetWithSSid:self.wifiNameTF.text keyword:self.wifiPasswordTF.text cid:self.cid ipAddr:@"192.168.10.255" mac:@""];
            }else{
                 [JFGSDK wifiSetWithSSid:self.wifiNameTF.text keyword:self.wifiPasswordTF.text cid:self.cid ipAddr:@"255.255.255.255" mac:@""];
            }
           
            [ProgressHUD showText:[JfgLanguage getLanTextStrByKey:@"DOOR_SET_WIFI_MSG"]];
            [self.navigationController popToRootViewControllerAnimated:YES];
        }
            break;
        case configWifiType_default:
        {
            if (!isConnectAp) {
                __weak typeof(self) weakSelf = self;
                [LSAlertView showAlertWithTitle:nil Message:[JfgLanguage getLanTextStrByKey:@"Item_ConnectionFail"] CancelButtonTitle:[JfgLanguage getLanTextStrByKey:@"OK"] OtherButtonTitle:nil CancelBlock:^{
                    
                    [weakSelf intoAddDevGuideVC];
                    
                } OKBlock:^{
                    
                }];
                return;
            }
            [JFGSDK appendStringToLogFile:[NSString stringWithFormat:@"wifiName:%@  wifiPasword:%@",self.wifiNameTF.text,self.wifiPasswordTF.text]];
            BindDevProgressViewController *bindDevice = [BindDevProgressViewController new];
            bindDevice.pType = self.pType;
            bindDevice.cid = self.cid;
            bindDevice.wifiName = self.wifiNameTF.text;
            bindDevice.wifiPassWord = self.wifiPasswordTF.text;
            [self.navigationController pushViewController:bindDevice animated:YES];
        }
            break;
        case configWifiType_resetWifi:{
            
            SetWifiLoadingFor720VC *setwifi = [SetWifiLoadingFor720VC new];
            setwifi.wifiName = self.wifiNameTF.text;
            setwifi.wifiPassword = self.wifiPasswordTF.text;
            setwifi.cid = self.cid;
            [self.navigationController pushViewController:setwifi animated:YES];
            
        }
            break;
        case configWifiType_setHotspot:{
            
            BOOL isConnectAp = [jfgConfigManager isAPModel];
            if (!isConnectAp && [LoginManager sharedManager].loginStatus != JFGSDKCurrentLoginStatusSuccess) {
                [ProgressHUD showText:@"OFFLINE_ERR_1"];
                return;
            }
            
            if (self.wifiPasswordTF.text.length<8) {
                [ProgressHUD showText:[JfgLanguage getLanTextStrByKey:@"HOTSPOT_PASSWORD_ERROR"]];
            }else{
                
                [JFGSDK wifiSetWithSSid:self.wifiNameTF.text keyword:self.wifiPasswordTF.text cid:self.cid ipAddr:self.ipAddress?self.ipAddress:@"" mac:self.macStr?self.macStr:@""];
                [ProgressHUD showProgress:nil Interaction:NO];//应测试要求，加载时候不允许操作
                [self startTimer];
                
                if (IOS_SYSTEM_VERSION_EQUAL_OR_ABOVE(10.0)) {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"App-Prefs:root=INTERNET_TETHERING"] options:@{} completionHandler:nil];
                } else {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"prefs:root=INTERNET_TETHERING"]];
                }
                
            }
            
        }
            break;
            
        default:
            
            break;
    }
    [self saveWifiInfoForName:self.wifiNameTF.text pw:self.wifiPasswordTF.text];
}

-(void)jfgSetWifiRespose:(JFGSDKUDPResposeSetWifi *)ask
{
    
}

-(void)startTimer
{
    if (timeOutTimer && timeOutTimer.isValid) {
        [timeOutTimer invalidate];
    }
    __weak typeof(self) weakSelf = self;
    timeCount = 0;
    timeOutTimer = [NSTimer bk_scheduledTimerWithTimeInterval:1 block:^(NSTimer *timer) {
        
        timeCount ++;
        if (timeCount%2==0) {
            [weakSelf checkDeviceNetStatue];
        }
        if (timeCount > 90) {
            [timeOutTimer invalidate];
            timeOutTimer = nil;
            [weakSelf netConnectTimeout];
        }
        [JFGSDK appendStringToLogFile:[NSString stringWithFormat:@"setwifi:%d",timeCount]];
        
    } repeats:YES];
}


-(void)checkDeviceNetStatue
{
    if (self.cid && ![self.cid isEqualToString:@""]) {
        
        __weak typeof(self) blockself = self;
        [[JFGSDKDataPoint sharedClient] robotGetSingleDataWithPeer:self.cid msgIds:@[@(201)] success:^(NSString *identity, NSArray<NSArray<DataPointSeg *> *> *idDataList) {
            
            for (NSArray *subArr in idDataList) {
                for (DataPointSeg *seg in subArr) {
                    id obj = [MPMessagePackReader readData:seg.value error:nil];
                    if ([obj isKindOfClass:[NSArray class]]) {
                        NSArray *objArr = obj;
                        [JFGSDK appendStringToLogFile:[NSString stringWithFormat:@"设置热点主动网络检测，%@",obj]];
                        if (objArr.count>1) {
                            
                            int netType = [[objArr objectAtIndex:0] intValue];
                            NSString *ssid = [objArr objectAtIndex:1];
                            
                            if (netType != -1 && netType != 0 && [ssid isEqualToString:[UIDevice currentDevice].name]) {
                                //设置成功
                                if (timeOutTimer && timeOutTimer.isValid) {
                                    [timeOutTimer invalidate];
                                }
                                timeOutTimer = nil;
                                [ProgressHUD showText:[JfgLanguage getLanTextStrByKey:@"SCENE_SAVED"]];
                                int64_t delayInSeconds = 1.0;
                                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
                                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                                    
                                    NSArray *vcList = self.navigationController.viewControllers;
                                    for (UIViewController *vc in vcList) {
                                        
                                        if ([vc isKindOfClass:[DeviceSettingVC class]]) {
                                            [blockself.navigationController popToViewController:vc animated:YES];
                                            return;
                                        }
                                        
                                    }
                                    [self dismissViewControllerAnimated:YES completion:nil];
                                    
                                });
                                
                            }
                            
                            
                        }
                    }
                    
                }
            }
            
            
        } failure:^(RobotDataRequestErrorType type) {
            
        }];
        
    }else{
        [JFGSDK appendStringToLogFile:@"720网络检测，cid为空"];
        
    }
    
}

-(void)netConnectTimeout
{
    [ProgressHUD showText:[JfgLanguage getLanTextStrByKey:@"HOTSPOTS_CONNECT_TIMEOUT_TIPS"]];
}

-(void)saveWifiInfoForName:(NSString *)wifiName pw:(NSString *)pw
{
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library"];
    path = [path stringByAppendingPathComponent:@"jfgou"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    path = [path stringByAppendingPathComponent:@"wifi.plist"];
    NSMutableDictionary *dict = [[NSMutableDictionary alloc]initWithContentsOfFile:path];
    if (dict) {
        NSString *oldPw = [dict objectForKey:wifiName];
        if (oldPw) {
            [dict removeObjectForKey:wifiName];
        }
    }else{
        dict = [NSMutableDictionary new];
    }
    [dict setObject:pw forKey:wifiName];
    [dict writeToFile:path atomically:YES];
}

-(void)removeWifiPWForKey:(NSString *)key
{
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library"];
    path = [path stringByAppendingPathComponent:@"jfgou"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    path = [path stringByAppendingPathComponent:@"wifi.plist"];
    NSMutableDictionary *dict = [[NSMutableDictionary alloc]initWithContentsOfFile:path];
    if (dict) {
        NSString *va = [dict objectForKey:key];
        if (va) {
            [dict removeObjectForKey:va];
        }
        cacheWifiListDict = nil;
        cacheWifiListDict = [[NSDictionary alloc]initWithDictionary:dict];
        [dict writeToFile:path atomically:YES];
    }
}

-(NSDictionary *)getWifiInfo
{
    if (cacheWifiListDict == nil) {
        NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library"];
        path = [path stringByAppendingPathComponent:@"jfgou"];
        path = [path stringByAppendingPathComponent:@"wifi.plist"];
        NSDictionary *dict = [[NSDictionary alloc]initWithContentsOfFile:path];
        if (dict) {
            cacheWifiListDict = [[NSDictionary alloc]initWithDictionary:dict];
        }
    }
    return cacheWifiListDict;
}



-(void)getWiFiListAciton:(UIButton *)button
{
    [self.view endEditing:YES];
    
    [WifiListView createWifiListViewForType:WifiListTypeWifiName commplete:^(id obj) {
        
        if ([obj isKindOfClass:[JFGSDKUDPResposeScanWifi class]]) {
            JFGSDKUDPResposeScanWifi *wifi = obj;
            NSString *wifiNameString = wifi.ssid;
            self.wifiNameTF.text = wifiNameString;
            self.wifiPasswordTF.text = @"";
            NSDictionary *dic = [self getWifiInfo];
            if (dic) {
                for (NSString *key in dic) {
                    if ([key isEqualToString:wifiNameString]) {
                        self.wifiPasswordTF.text = [dic objectForKey:key];
                        break;
                    }
                }
            }
        }
        
        
    }];
    
}

-(void)exitAction
{
    //弹框逻辑处理
    __weak typeof(self) weakSelf = self;
    [LSAlertView showAlertWithTitle:nil Message:[JfgLanguage getLanTextStrByKey:@"Tap1_AddDevice_tips"] CancelButtonTitle:[JfgLanguage getLanTextStrByKey:@"OK"] OtherButtonTitle:[JfgLanguage getLanTextStrByKey:@"CANCEL"] CancelBlock:^{
        
        [weakSelf intoAddDevGuideVC];
        
    } OKBlock:^{
        
    }];
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 10245 && buttonIndex == 0) {
        [self intoAddDevGuideVC];
    }
}

-(void)intoAddDevGuideVC
{
    switch (self.configType)
    {
        case configWifiType_configWifi:
        {
            for (UIViewController *temp in self.navigationController.viewControllers)
            {
                if ([temp isKindOfClass:[DeviceSettingVC class]]  )
                {
                    [self.navigationController popToViewController:temp animated:YES];
                    break;
                }
            }
        }
            break;
        
        case configWifiType_setHotspot:{
            NSArray *vcList = self.navigationController.viewControllers;
            for (UIViewController *vc in vcList) {
                
                if ([vc isKindOfClass:[DeviceSettingVC class]]) {
                    [self.navigationController popToViewController:vc animated:YES];
                    return;
                }
                
            }
        }
            break;
        case configWifiType_default:
            default:
        {
            for (UIViewController *temp in self.navigationController.viewControllers)
            {
                if ([temp isKindOfClass:[AddDeviceGuideViewController class]]   || [temp isKindOfClass:[DeviceSettingVC class]])
                {
                    [self.navigationController popToViewController:temp animated:YES];
                }
                
            }
        }
            break;
    }
    
}

#pragma  mark - UITouch
-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.view endEditing:YES];
}

#pragma mark - 控件
-(UILabel *)titleLabel{
    if (!_tipLabel) {
        _titleLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, kTop, Kwidth, 27*kScreen_Scale)];
        _titleLabel.font = [UIFont fontWithName:@"PingFangSC-regular" size:27*kScreen_Scale];
        _titleLabel.font = [UIFont systemFontOfSize:27*kScreen_Scale];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.textColor = [UIColor colorWithHexString:@"#333333"];
        _titleLabel.text = [JfgLanguage getLanTextStrByKey:@"Tap1_AddDevice_WifiConfTips"];
        if (self.configType == configWifiType_setHotspot) {
            _titleLabel.text = [JfgLanguage getLanTextStrByKey:@"SETTINGS_MOBILE_HOTSPOT"];
        }
    }
    return _titleLabel;
}
-(UITextField *)wifiNameTF{
    if (!_wifiNameTF) {
        _wifiNameTF = [self creatTextField];
        _wifiNameTF.frame = CGRectMake(kLeft+35, self.titleLabel.bottom+76*kScreen_Scale, kLineWidth-70, 16);
        _wifiNameTF.placeholder = [JfgLanguage getLanTextStrByKey:@"ENTER_WIFI"];
        NSString *availabelwifi = [[NSUserDefaults standardUserDefaults] objectForKey:availableWIFI];
        if ([availabelwifi hasPrefix:@"DOG"] || [availabelwifi hasPrefix:@"dog"]) {
            availabelwifi = @"";
        }
        _wifiNameTF.text = availabelwifi;
        _wifiNameTF.delegate = self;
        _wifiNameTF.returnKeyType = UIReturnKeyNext;
        _wifiNameTF.clearButtonMode = UITextFieldViewModeWhileEditing;
        
        NSString *wifiNam = [[NSUserDefaults standardUserDefaults] objectForKey:availableWIFI];
        if ([wifiNam isKindOfClass:[NSString class]]) {
            
            _wifiNameTF.text = wifiNam;
//            NSDictionary *dic = [self getWifiInfo];
//            if (dic) {
//                for (NSString *key in dic) {
//                    if ([key isEqualToString:wifiNam]) {
//                        
//                        break;
//                    }
//                }
//            }
        }
        
    }
    return _wifiNameTF;
}
-(UITextField *)wifiPasswordTF
{
    if (!_wifiPasswordTF) {
        _wifiPasswordTF = [self creatTextField];
        _wifiPasswordTF.frame = CGRectMake(kLeft+35, self.lineLabel_top.bottom+41*kScreen_Scale, kLineWidth-70, 16);
        _wifiPasswordTF.placeholder = [JfgLanguage getLanTextStrByKey:@"ENTER_WIFI_PWD"];
        _wifiPasswordTF.secureTextEntry = YES;
        _wifiPasswordTF.delegate = self;
        _wifiPasswordTF.keyboardType = UIKeyboardTypeEmailAddress;
        _wifiPasswordTF.returnKeyType = UIReturnKeyDone;
        _wifiPasswordTF.clearButtonMode = UITextFieldViewModeWhileEditing;
        _wifiPasswordTF.rightViewMode = UITextFieldViewModeAlways;
        NSString *wifiNam = [[NSUserDefaults standardUserDefaults] objectForKey:availableWIFI];
        if ([wifiNam isKindOfClass:[NSString class]]) {
            
            NSDictionary *dic = [self getWifiInfo];
            if (dic) {
                for (NSString *key in dic) {
                    if ([key isEqualToString:wifiNam]) {
                        _wifiPasswordTF.text = [dic objectForKey:key];
                        break;
                    }
                }
            }
            
        }
    }
    return _wifiPasswordTF;
}

-(UILabel *)lineLabel_top
{
    if (!_lineLabel_top) {
        _lineLabel_top = [self creatLineLabel];
        _lineLabel_top.frame = CGRectMake(kLeft, self.wifiNameTF.bottom+13*kScreen_Scale, kLineWidth, 0.5);
    }
    return _lineLabel_top;
}

-(UILabel *)lineLabel_bottom{
    if (!_lineLabel_bottom) {
        _lineLabel_bottom = [self creatLineLabel];
        _lineLabel_bottom.frame = CGRectMake(kLeft, self.wifiPasswordTF.bottom+13*kScreen_Scale, kLineWidth, 0.5);
    }
    return _lineLabel_bottom;
}
-(UILabel *)tipLabel{
    if (!_tipLabel) {
        _tipLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, self.lineLabel_bottom.bottom+15*kScreen_Scale, Kwidth, 13*kScreen_Scale)];
        _tipLabel.textAlignment = NSTextAlignmentCenter;
        _tipLabel.font = [UIFont fontWithName:@"PingFangSC-medium" size:13*kScreen_Scale];
        _tipLabel.font = [UIFont systemFontOfSize:13*kScreen_Scale];
        _tipLabel.textColor = [UIColor colorWithHexString:@"#4b9fd5"];
        _tipLabel.text = [JfgLanguage getLanTextStrByKey:@"WIFI_SET_5GTIPS"];
        if (self.configType == configWifiType_setHotspot) {
             _tipLabel.text = [JfgLanguage getLanTextStrByKey:@"TURN_ON_HOTSPOT_GUIDE"];
        }
    }
    return _tipLabel;
}
-(UIButton *)nextButton{
    if (!_nextButton) {
        _nextButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _nextButton.frame = CGRectMake(0, self.tipLabel.bottom+40*kScreen_Scale, 360*0.5, 44);
        _nextButton.layer.masksToBounds = YES;
        _nextButton.x = self.view.x;
        _nextButton.layer.cornerRadius = 22;
        _nextButton.layer.borderColor = [UIColor colorWithHexString:@"#e8e8e8"].CGColor;
        _nextButton.layer.borderWidth = 1;
        [_nextButton setTitleColor:[UIColor colorWithHexString:@"#4b9fd5"] forState:UIControlStateNormal];
        [_nextButton setTitle:[JfgLanguage getLanTextStrByKey:@"NEXT"] forState:UIControlStateNormal];
        _nextButton.titleLabel.font = [UIFont systemFontOfSize:18];
        [_nextButton addTarget:self action:@selector(nextButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _nextButton;
}
-(UIButton *)wifiListButton{
    if (!_wifiListButton) {
        _wifiListButton= [UIButton buttonWithType:UIButtonTypeCustom];
        _wifiListButton.frame = CGRectMake(self.lineLabel_top.right-35, self.lineLabel_top.bottom-2-35, 35, 35);
        [_wifiListButton setBackgroundColor:[UIColor clearColor]];
        [_wifiListButton setImage:[UIImage imageNamed:@"add_btn_wifiList"] forState:UIControlStateNormal];
        [_wifiListButton addTarget:self action:@selector(getWiFiListAciton:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _wifiListButton;
}
-(DelButton *)exitBtn
{
    if (!_exitBtn) {
        _exitBtn = [DelButton buttonWithType:UIButtonTypeCustom];
        _exitBtn.frame = CGRectMake(10, 37, 10, 18);
        [_exitBtn setImage:[UIImage imageNamed:@"btn_return"] forState:UIControlStateNormal];
        [_exitBtn addTarget:self action:@selector(exitAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _exitBtn;
}

-(UILabel *)creatLineLabel
{
    UILabel * lineLabel = [[UILabel alloc]init];
    lineLabel.backgroundColor = [UIColor colorWithHexString:@"#cecece"];
    return lineLabel;
}

-(UITextField *)creatTextField
{
    UITextField * textField = [[UITextField alloc]init];
    textField.textAlignment = NSTextAlignmentCenter;
    textField.font = [UIFont systemFontOfSize:16*kScreen_Scale];
    textField.textColor = [UIColor colorWithHexString:@"#666666"];
    [textField setValue:[UIColor colorWithHexString:@"#cecece"] forKeyPath:@"_placeholderLabel.textColor"];
    textField.delegate = self;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    [textField addTarget:self action:@selector(textFieldValueChanged:)  forControlEvents:UIControlEventAllEditingEvents];
    return textField;
}

//创建密码输入框右边控件
-(UIView *)pwTextFieldRightView
{
    UIView *bgView = [[UIView alloc]initWithFrame:CGRectMake(self.wifiPasswordTF.right, self.wifiPasswordTF.top-10, 35, 35)];
    UIButton *lockBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    lockBtn.frame = CGRectMake(0, 0, 35, 35);
    [lockBtn setImage:[UIImage imageNamed:@"lock_btn_noshow password"] forState:UIControlStateNormal];
    [lockBtn setImage:[UIImage imageNamed:@"lock_btn_show password"] forState:UIControlStateSelected];
    lockBtn.adjustsImageWhenHighlighted = NO;
    [lockBtn addTarget:self action:@selector(lockPwAction:) forControlEvents:UIControlEventTouchUpInside];
    lockBtn.selected = NO;
    [bgView addSubview:lockBtn];
    
    return bgView;
}

//密码明文密文切换
-(void)lockPwAction:(UIButton *)sender
{
    NSString *text = self.wifiPasswordTF.text;
    if (sender.selected) {
        self.wifiPasswordTF.secureTextEntry = YES;
        sender.selected  = NO;
    }else{
        self.wifiPasswordTF.secureTextEntry = NO;
        self.wifiPasswordTF.keyboardType = UIKeyboardTypeASCIICapable;
        sender.selected  = YES;
    }
    self.wifiPasswordTF.text = text;
}

-(UIButton *)declareBtn
{
    if (!_declareBtn) {
        _declareBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _declareBtn.frame = CGRectMake(self.view.width-15-25, 40, 25, 25);
        [_declareBtn setImage:[UIImage imageNamed:@"icon_explain_gray"] forState:UIControlStateNormal];
        [_declareBtn addTarget:self action:@selector(intoVC) forControlEvents:UIControlEventTouchUpInside];
    }
    return _declareBtn;
}

-(void)intoVC
{
    PilotLampStateVC *lampVC = [PilotLampStateVC new];
    [self presentViewController:lampVC animated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITextfieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string{
    
    NSString * maxLString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (textField == self.wifiNameTF) {
        if (maxLString.length > 31) {
            return NO;
        }
    }else{
        if (maxLString.length > 63) {
            return NO;
        }
    }
   
    if (textField == self.wifiNameTF) {
        NSDictionary *dic = [self getWifiInfo];
        if (dic) {
            for (NSString *key in dic) {
                if ([key isEqualToString:maxLString]) {
                    self.wifiPasswordTF.text = [dic objectForKey:key];
                    break;
                }
                if ([key isEqualToString:textField.text]) {
                    
                    if ([self.wifiPasswordTF.text isEqualToString:[dic objectForKey:key]]) {
                        self.wifiPasswordTF.text = @"";
                    }
                    break;
                }
            }
        }
    }
    
    return YES;
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    if (textField == _wifiNameTF) {
        [textField resignFirstResponder];
        [_wifiPasswordTF becomeFirstResponder];
    }else if (textField == _wifiPasswordTF){
        [textField resignFirstResponder];
    }else{
        [textField resignFirstResponder];
    }
    return YES;
}

-(void)textFieldValueChanged:(UITextField *)textField
{

}

-(BOOL)textFieldShouldClear:(UITextField *)textField
{
    if (textField == self.wifiPasswordTF) {
        NSDictionary *dic = [self getWifiInfo];
        if (dic) {
            for (NSString *key in dic) {
                if ([key isEqualToString:self.wifiNameTF.text]) {
                    
                    NSString *pw = [dic objectForKey:key];
                    if ([pw isEqualToString:textField.text]) {
                        [self removeWifiPWForKey:key];
                    }
                    break;
                }
            }
        }
    }
//    else{
//        self.wifiPasswordTF.text = @"";
//    }
    
    return YES;
}

-(void)dealloc
{
    [JFGSDK removeDelegate:self];
}

@end
