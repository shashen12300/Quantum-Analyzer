//
//  QABeginCheckViewController.m
//  Quantum Analyzer
//
//  Created by 宋冲冲 on 2016/12/4.
//  Copyright © 2016年 宋冲冲. All rights reserved.
//

#import "QABeginCheckViewController.h"
#import "GifView.h"
#import "UIView+SDExtension.h"
#import "GraphView.h"
#import "DataBase.h"
#import "QABLEAdapter.h"
#import "HealthReportManager.h"
typedef NS_ENUM(NSInteger,Buttonype) {
    WaitCheck  = 0,
    BeginCheck = 1,
    PauseCheck = 2,
    ContinueCheck = 3,
    StopCheck  = 4,
    SaveCheck  = 5
};

@interface QABeginCheckViewController ()<UIAlertViewDelegate>

@property (nonatomic, strong) GifView *gifView;
@property (nonatomic, strong) UIImageView *scanNetImageView;
@property (weak, nonatomic) IBOutlet UIView *graphViewBg;
@property (weak, nonatomic) IBOutlet UIView *scanWindow;
@property (nonatomic, weak)   UIView *maskView;
@property (nonatomic, strong) GraphView *graphView;

@property (weak, nonatomic) IBOutlet UIButton *beginBtn;
@property (weak, nonatomic) IBOutlet UIButton *stopBtn;
@property (weak, nonatomic) IBOutlet UIButton *saveBtn;

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSTimer *checkTimer;
@property (nonatomic, strong) UIButton *lastBtn;
@property (nonatomic, assign) Buttonype buttonType;
@property (nonatomic, strong) QABLEAdapter *t;
@end

@implementation QABeginCheckViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initTitleLabel:@"开始检测"];
    self.view.backgroundColor = [UIColor blackColor];
    [QABLEAdapter sharedBLEAdapter].beginViewController = self;
    _t = [QABLEAdapter sharedBLEAdapter];
    _t.beginViewController = self;
    self.view.clipsToBounds=YES;
    self.scanNetImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"scan_net"]];
    [_scanWindow addSubview:_scanNetImageView];
    _scanNetImageView.hidden = YES;

    UIImageView *bgImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"scan_net"]];
    bgImageView.frame = _graphViewBg.bounds;
    bgImageView.clipsToBounds = YES;
    bgImageView.contentMode = UIViewContentModeScaleToFill;
    [_graphViewBg addSubview:bgImageView];
    _graphView = [[GraphView alloc]initWithFrame:self.graphViewBg.bounds];
    [_graphView setBackgroundColor:[UIColor clearColor]];
    [_graphView setSpacing:10];
    [_graphView setFill:NO];
    [_graphView setStrokeColor:navbackgroundColor];
    [_graphView setZeroLineStrokeColor:[UIColor greenColor]];
    [_graphView setFillColor:[UIColor orangeColor]];
    [_graphView setLineWidth:1];
    [_graphView setCurvedLines:YES];
    [_graphViewBg addSubview:_graphView];
    
   _timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(setPointButtonAction) userInfo:nil repeats:YES];
    //关闭定时器
    [_timer setFireDate:[NSDate distantFuture]];
    
    _checkTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:[QABLEAdapter sharedBLEAdapter] selector:@selector(voltageCheck) userInfo:nil repeats:YES];
    [_checkTimer setFireDate:[NSDate distantFuture]];

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (_lastBtn.tag == 0&&_lastBtn.selected == YES) {
        //继续动画
        [self resumeAnimation];
    }

}

- (IBAction)checkBtnClick:(UIButton *)sender {
    if (![CommonCore queryMessageKey:CurrentUserID]) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"提示" message:@"请先登录账户，再进行检测" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles: nil];
        [alertView show];
        return;
    }else if (!_t.activePeripheral) {
//        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"提示" message:@"请先通过蓝牙连接硬件设备" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles: nil];
//        [alertView show];
//        return;
    }
    if (sender.selected == YES) {
        return;
    }
    if (sender.tag == 0) {
        [self resetAllState];
        _saveBtn.enabled = NO;
        _saveBtn.backgroundColor = grayFontColor;
        //开启定时器
        _buttonType = WaitCheck;
        [_checkTimer setFireDate:[NSDate distantPast]];

    }else if (sender.tag == 1) {
        _saveBtn.enabled = YES;
        _saveBtn.backgroundColor = navbackgroundColor;
        //关闭定时器
        _buttonType = StopCheck;
        [_timer setFireDate:[NSDate distantFuture]];
        _scanNetImageView.hidden = YES;
        [_scanNetImageView.layer removeAllAnimations];
        [[QABLEAdapter sharedBLEAdapter] stopCheck];
        
    }else {
        _saveBtn.enabled = NO;
        _saveBtn.backgroundColor = grayFontColor;

        //保存结果
        _buttonType = SaveCheck;
        NSNumber *userID = [CommonCore queryMessageKey:CurrentUserID];
        Record *record = [[Record alloc] init];
        record.time = [CommonCore currentTime];
        record.own_id = userID;
        Person *person = [[DataBase sharedDataBase] getCurrentLoginUser];
        record.report = [[HealthReportManager sharedManager]saveUserDataToSqlite:record.time];
        [[DataBase sharedDataBase] addRecord:record toPerson:person];
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"提示" message:@"保存成功" delegate:self cancelButtonTitle:@"确定" otherButtonTitles: nil];
        [alertView show];
        
        [self resetAllState];
    }
    _lastBtn.selected = NO;
    sender.selected = YES;
    _lastBtn = sender;
}



/* 复位状态*/
- (void)resetAllState {
    //关闭定时器
    [_timer setFireDate:[NSDate distantFuture]];
    _scanNetImageView.hidden = YES;
    [_scanNetImageView.layer removeAllAnimations];
    [_graphView resetGraph];
    [[QABLEAdapter sharedBLEAdapter] saveCheckResult];

}

/* 获取反馈数据*/
-(void) OnReadChar:(CBCharacteristic *)characteristic{
    NSLog(@"KeyfobViewController didUpdateValueForCharacteristic %@", characteristic);
    NSLog(@"接收到的数据:%@",[[characteristic value] description]);
    if (characteristic.value.length != 7) {
        return;
    }
    NSString *valueStr = [self convertDataToHexStr:[characteristic value]];
    valueStr = [valueStr substringToIndex:10];
    NSInteger value = [[CommonCore convertHexStrToString:valueStr] integerValue];
    NSLog(@"valueStr: %@   value: %ld",valueStr,value);

    if (_buttonType == WaitCheck) {
        
        if (value < 20000) {
            _buttonType = BeginCheck;
            [[QABLEAdapter sharedBLEAdapter] startCheck];
            [_timer setFireDate:[NSDate distantPast]];
            [self resumeAnimation];
            _scanNetImageView.hidden = NO;
            [[QABLEAdapter sharedBLEAdapter] voltageCheck];
        }
        
    }else if (_buttonType == BeginCheck) {
        if (value > 20000) {
            _buttonType = ContinueCheck;
            [[QABLEAdapter sharedBLEAdapter] pauseCheck];
            [_timer setFireDate:[NSDate distantFuture]];
            _scanNetImageView.hidden = YES;
            [_scanNetImageView.layer removeAllAnimations];

        }
    } else if (_buttonType == PauseCheck) {
        
        if (value < 20000) {
            _buttonType = ContinueCheck;
            [[QABLEAdapter sharedBLEAdapter] continueCheck];
            [self resumeAnimation];
            _scanNetImageView.hidden = NO;


        }
    }else if (_buttonType == ContinueCheck) {
        if (value>20000) {
            _buttonType = PauseCheck;
            [[QABLEAdapter sharedBLEAdapter] pauseCheck];
            [_timer setFireDate:[NSDate distantFuture]];
            _scanNetImageView.hidden = YES;
            [_scanNetImageView.layer removeAllAnimations];
        }
    }
    
}

- (NSString *)convertDataToHexStr:(NSData *)data {
    if (!data || [data length] == 0) {
        return @"";
    }
    NSMutableString *string = [[NSMutableString alloc] initWithCapacity:[data length]];
    
    [data enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
        unsigned char *dataBytes = (unsigned char*)bytes;
        for (NSInteger i = 0; i < byteRange.length; i++) {
            NSString *hexStr = [NSString stringWithFormat:@"%x", (dataBytes[i]) & 0xff];
            if ([hexStr length] == 2) {
                [string appendString:hexStr];
            } else {
                [string appendFormat:@"0%@", hexStr];
            }
        }
    }];
    
    return string;
}



-(NSData *)dataFromHexString:(NSString *)string {
    string = [string lowercaseString];
    NSMutableData *data= [NSMutableData new];
    
    unsigned char whole_byte;
    char byte_chars[3] = {'\0','\0','\0'};
    int i = 0;
    int length = string.length;
    while (i < length-1) {
        char c = [string characterAtIndex:i++];
        if (c < '0' || (c > '9' && c < 'a') || c > 'f')
            continue;
        byte_chars[0] = c;
        byte_chars[1] = [string characterAtIndex:i++];
        whole_byte = strtol(byte_chars, NULL, 16);
        [data appendBytes:&whole_byte length:1];
        
    }
    
    return data;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {

}

-(void)setPointButtonAction {
    
    // generate random numbers between +100 and -100
    float low_bound = -100.00;
    float high_bound = 100.00;
    float rndValue = (((float)arc4random()/0x100000000)*(high_bound-low_bound)+low_bound);
    int intRndValue = (int)(rndValue + 0.5);
    [_graphView setPoint:intRndValue];
    
}



#pragma mark 恢复动画
- (void)resumeAnimation
{
    CAAnimation *anim = [_scanNetImageView.layer animationForKey:@"translationAnimation"];
    if(anim){
        // 1. 将动画的时间偏移量作为暂停时的时间点
        CFTimeInterval pauseTime = _scanNetImageView.layer.timeOffset;
        // 2. 根据媒体时间计算出准确的启动动画时间，对之前暂停动画的时间进行修正
        CFTimeInterval beginTime = CACurrentMediaTime() - pauseTime;
        
        // 3. 要把偏移时间清零
        [_scanNetImageView.layer setTimeOffset:0.0];
        // 4. 设置图层的开始动画时间
        [_scanNetImageView.layer setBeginTime:beginTime];
        
        [_scanNetImageView.layer setSpeed:1.0];
    }else{
    
        CGFloat scanNetImageViewH = _scanWindow.sd_height;
//        CGFloat scanWindowH = self.view.sd_width - kMargin * 2;
        CGFloat scanNetImageViewW = _scanWindow.sd_width;
        _scanNetImageView.frame = CGRectMake(0, -scanNetImageViewH, scanNetImageViewW, scanNetImageViewH);
        CABasicAnimation *scanNetAnimation = [CABasicAnimation animation];
        scanNetAnimation.keyPath = @"transform.translation.y";
        scanNetAnimation.byValue = @(scanNetImageViewH);
        scanNetAnimation.duration = 1.0;
        scanNetAnimation.repeatCount = MAXFLOAT;
        [_scanNetImageView.layer addAnimation:scanNetAnimation forKey:@"translationAnimation"];
    }

    
    
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
