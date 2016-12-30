//
//  HealthReportManager.h
//  Quantum Analyzer
//
//  Created by 宋冲冲 on 2016/12/28.
//  Copyright © 2016年 宋冲冲. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HealthReportManager : NSObject

+ (HealthReportManager *) sharedManager;

/* 心脑血管检测报告*/
- (NSString *)getCheckReport;
- (NSString *)getCheckReportHtml:(NSString *)mainItemID;
- (NSString *)saveUserDataToSqlite:(NSString *)time;
@end
