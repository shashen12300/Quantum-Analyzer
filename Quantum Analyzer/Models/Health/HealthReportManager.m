//
//  HealthReportManager.m
//  Quantum Analyzer
//
//  Created by 宋冲冲 on 2016/12/28.
//  Copyright © 2016年 宋冲冲. All rights reserved.
//

#import "HealthReportManager.h"
#import "TblSubItemCaseManager.h"
#import "TblSubItemCase.h"
#import "ReportContentData.h"
#import "TblMeasData.h"
#import "TblMeasDataManager.h"
#import "HealthModel.h"
#import "ReportList.h"
#import "ReportListManager.h"
#import <GRMustache.h>

#define CHECK_RESULT_NORMAL            1  //@"<font color=00FF00>正常(-)</font>"
#define CHECK_RESULT_MIN_ABNORMAL      2  //@"<font color=3368A1>轻度异常(+)</font>"
#define CHECK_RESULT_MEDIUM_ABNORMAL   3  //@"<font color=00FF00>正常(-)</font>"
#define CHECK_RESULT_MAX_ABNORMAL      4  //@"<font color=00FF00>正常(-)</font>"

static HealthReportManager *_healthReportManager = nil;

@implementation HealthReportManager

#pragma mark -
+ (HealthReportManager *) sharedManager
{
    @synchronized(self) {
        if (!_healthReportManager) {
            _healthReportManager = [[self alloc] init];
        }
    }
    return _healthReportManager;
}

- (id)init
{
    self = [super init];
    if (self) {

    }
    return self;
}


- (NSString *)htmlStr:(ReportContentData *)reportContentData {
    NSString *htmls = [NSString stringWithFormat:@"<TR class=td align=left bgcolor=EBF5FB><TD class=td align=middle>%@ </TD><TD class=td align=middle>%@ - %@ </TD><TD class=td align=middle>%@ </TD><TD class=td align=middle>%@</TD></TR>",reportContentData.name,reportContentData.minValue,reportContentData.maxValue,reportContentData.realValue,reportContentData.resultState];
    return htmls;
}

/* 心脑血管检测报告*/
- (NSString *)getCheckReport {
    NSString *htmlStr = @"";
    NSArray *allSubItems = [[NSArray alloc] initWithArray:[[TblSubItemCaseManager sharedManager] getSingleReportAllSubItem:@"1"]];
    for (TblSubItemCase *subItemCase in allSubItems) {
        if ([subItemCase isKindOfClass:[TblSubItemCase class]]) {
            ReportContentData *report = [[ReportContentData alloc] init];
            NSInteger minValue = [subItemCase.db_SubItemVal0 floatValue]*1000;
            NSInteger maxValue = [subItemCase.db_SubItemVal3 floatValue]*1000;
            NSInteger lengthValue = maxValue - minValue;
            CGFloat realValue = (minValue + arc4random()%lengthValue)/1000.0;
            report.name = subItemCase.str_SubItemName;
            report.minValue = subItemCase.db_SubItemVal0;
            report.maxValue = subItemCase.db_SubItemVal1;
            report.realValue = [NSString stringWithFormat:@"%.3f",realValue];
            if ((realValue>=[subItemCase.db_SubItemVal0 floatValue])&&(realValue<[subItemCase.db_SubItemVal1 floatValue])) {
                report.resultState = [self getCheckResultContent:subItemCase.str_NormalCall State:CHECK_RESULT_NORMAL];
            }else if ((realValue>=[subItemCase.db_SubItemVal1 floatValue])&&(realValue<[subItemCase.db_SubItemVal2 floatValue])) {
                report.resultState = [self getCheckResultContent:subItemCase.str_GentalCall State:CHECK_RESULT_MIN_ABNORMAL];
            }else if ((realValue>=[subItemCase.db_SubItemVal2 floatValue])&&(realValue<[subItemCase.db_SubItemVal3 floatValue])) {
                report.resultState = [self getCheckResultContent:subItemCase.str_TensionCall State:CHECK_RESULT_MEDIUM_ABNORMAL];
            }else {
                report.resultState = [self getCheckResultContent:subItemCase.str_SeriousCall State:CHECK_RESULT_MAX_ABNORMAL];
            }
            NSString *subItemStr = [self htmlStr:report];
            htmlStr = [htmlStr stringByAppendingString:subItemStr];
        }
    }
    
    return htmlStr;
}

/* 检测报告*/
- (NSString *)getCheckReportHtml:(NSString *)mainItemID {
    NSString *htmlStr = @"";
    Person *person = [[DataBase sharedDataBase] getCurrentLoginUser];
    NSArray *allSubItems = [[NSArray alloc] initWithArray:[[TblSubItemCaseManager sharedManager] getSingleReportAllSubItem:mainItemID]];
    for (TblSubItemCase *subItemCase in allSubItems) {
        if ([subItemCase isKindOfClass:[TblSubItemCase class]]) {
            TblMeasData *measData = [[TblMeasDataManager sharedManager] getHealthStateSubItemID:subItemCase.n_SubItemID Age:person.age type:person.health];
            NSInteger n_Result = [measData.n_Result integerValue];
            ReportContentData *report = [[ReportContentData alloc] init];
            NSInteger minValue=0,maxValue=0;
            switch (n_Result) {
                case 0:
                {
                    minValue = [subItemCase.db_SubItemVal0 floatValue]*1000;
                    maxValue = [subItemCase.db_SubItemVal1 floatValue]*1000;
                    report.resultState = [self getCheckResultContent:subItemCase.str_NormalCall State:CHECK_RESULT_NORMAL];
                    break;
                }
                case 1:
                {
                    minValue = [subItemCase.db_SubItemVal1 floatValue]*1000;
                    maxValue = [subItemCase.db_SubItemVal2 floatValue]*1000;
                    report.resultState = [self getCheckResultContent:subItemCase.str_GentalCall State:CHECK_RESULT_MIN_ABNORMAL];
                    break;
                }
                case 2:
                {
                    minValue = [subItemCase.db_SubItemVal2 floatValue]*1000;
                    maxValue = [subItemCase.db_SubItemVal3 floatValue]*1000;
                    report.resultState = [self getCheckResultContent:subItemCase.str_TensionCall State:CHECK_RESULT_MEDIUM_ABNORMAL];

                    break;
                }
                case 3:
                {
                    minValue = [subItemCase.db_SubItemVal3 floatValue]*1000;
                    maxValue = subItemCase.db_SubItemVal0 < subItemCase.db_SubItemVal3 ? minValue + 1000 : MAX(minValue - 1000,1000/arc4random());
                    report.resultState = [self getCheckResultContent:subItemCase.str_SeriousCall State:CHECK_RESULT_MAX_ABNORMAL];

                    break;
                }
                default:
                    break;
            }
            if (minValue > maxValue) {
                NSInteger tempValue = minValue;
                minValue = maxValue;
                maxValue = tempValue;
            }
            NSInteger lengthValue = maxValue - minValue;
            CGFloat realValue = (minValue + arc4random()%lengthValue)/1000.0;
            report.name = subItemCase.str_SubItemName;
            report.minValue = [NSString stringWithFormat:@"%.3f",MIN([subItemCase.db_SubItemVal0 floatValue], [subItemCase.db_SubItemVal1 floatValue])];
            report.maxValue = [NSString stringWithFormat:@"%.3f",MAX([subItemCase.db_SubItemVal0 floatValue], [subItemCase.db_SubItemVal1 floatValue])];
            report.realValue = [NSString stringWithFormat:@"%.3f",realValue];
            
            NSString *subItemStr = [self htmlStr:report];
            htmlStr = [htmlStr stringByAppendingString:subItemStr];
        }
    }
    
    return htmlStr;
}

- (NSString *)getCheckResultContent:(NSString *)content State:(NSInteger)state {
    NSString *resultStr = @"";
    if (state == CHECK_RESULT_NORMAL) {
        resultStr = [NSString stringWithFormat:@"<font color=00FF00>%@</font>",content];
    }else if (state == CHECK_RESULT_MIN_ABNORMAL){
        resultStr = [NSString stringWithFormat:@"<font color=3368A1>%@</font>",content];//3368a1
    }else if (state == CHECK_RESULT_MEDIUM_ABNORMAL){
        resultStr = [NSString stringWithFormat:@"<font color=DBB403>%@</font>",content];
    }else if (state == CHECK_RESULT_MAX_ABNORMAL){
        resultStr = [NSString stringWithFormat:@"<font color=C60709>%@</font>",content];
    }else {
        resultStr = [NSString stringWithFormat:@"<font color=C60709>%@</font>",content];
    }
    return resultStr;
}


- (NSString *)saveUserDataToSqlite:(NSString *)time {
    Person *person = [[DataBase sharedDataBase]getCurrentLoginUser];
    HealthModel *health = [[HealthModel alloc] init];
    health.sex = person.sex;
    health.name = person.name;
    health.age = person.age;
    health.weight = person.weight;
    health.stature = person.stature;
    health.time = time;
    health.health = person.health;
    NSArray *sourceArray;
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    if ([person.age intValue] <= 14) {
        sourceArray = [[ReportListManager sharedManager] getAllChildrenReport];
    }else if ([person.sex isEqualToString:@"男"]) {
        sourceArray = [[ReportListManager sharedManager] getAllManReport];
    }else {
        sourceArray = [[ReportListManager sharedManager] getAllWomanReport];
    }
    for (ReportList *reportList in sourceArray) {
        if ([reportList isKindOfClass:[ReportList class]]) {
            NSString *str = [[HealthReportManager sharedManager] getCheckReportHtml:reportList.reportID];
            health.table = str;
            NSString *htmlPath = [[NSBundle mainBundle] pathForResource:reportList.reportName ofType:@"htm"];
            NSString *template = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
            template = [template stringByReplacingOccurrencesOfString:@"{{table}}" withString:str];
            NSDictionary *renderObject = [CommonCore dictionaryWithModel:health];
            NSString *content = [GRMustacheTemplate renderObject:renderObject fromString:template error:nil];
            [dictionary setObject:content forKey:reportList.reportName];
        }
    }
    NSString *jsonString = [CommonCore jsonWithArray:dictionary];
    return jsonString;
   
}

//- (NSString *)demoFormatWithPerson:(ReportList *)reportList {
//    HealthModel *health = [[HealthModel alloc] init];
//    health.sex = person.sex;
//    health.name = person.name;
//    health.age = [self getAgeDate:person.date];
//    health.weight = person.weight;
//    health.stature = person.stature;
//    health.time = person.date;
//    health.health = person.health;
//    NSString *str = [[HealthReportManager sharedManager] getCheckReportHtml:reportList.reportID];
//    health.table = str;
//    NSString *htmlPath = [[NSBundle mainBundle] pathForResource:reportList.reportName ofType:@"htm"];
//    NSString *template = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
//    template = [template stringByReplacingOccurrencesOfString:@"{{table}}" withString:str];
//    NSDictionary *renderObject = [CommonCore dictionaryWithModel:health];
//    NSString *content = [GRMustacheTemplate renderObject:renderObject fromString:template error:nil];
//    return content;
//}

@end
