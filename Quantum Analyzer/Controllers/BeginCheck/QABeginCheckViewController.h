//
//  QABeginCheckViewController.h
//  Quantum Analyzer
//
//  Created by 宋冲冲 on 2016/12/4.
//  Copyright © 2016年 宋冲冲. All rights reserved.
//

#import "QABaseViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>

@interface QABeginCheckViewController : QABaseViewController

- (void)OnReadChar:(CBCharacteristic *)characteristic;

@end
