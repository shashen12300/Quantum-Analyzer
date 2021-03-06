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
#import <FMDB.h>
#import "CollectModel.h"
#import "TblSuggest.h"
#import "TblSuggestManager.h"

#define CHECK_RESULT_NORMAL            1
#define CHECK_RESULT_MIN_ABNORMAL      2
#define CHECK_RESULT_MEDIUM_ABNORMAL   3
#define CHECK_RESULT_MAX_ABNORMAL      4

static HealthReportManager *_healthReportManager = nil;

@implementation HealthReportManager{
    FMDatabase  *_db;
    
}

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
        // 获得Documents目录路径
        
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        
        // 文件路径
        
        NSString *filePath = [documentsPath stringByAppendingPathComponent:@"model.sqlite"];
        
        // 实例化FMDataBase对象
        
        _db = [FMDatabase databaseWithPath:filePath];
        
        [_db open];
        
        // 初始化数据表
        NSString *personSql2 = @"CREATE TABLE 'collectReport' ('id' INTEGER PRIMARY KEY AUTOINCREMENT  NOT NULL ,'n_MainItemID' VARCHAR(255),'str_SubItemName' VARCHAR(255),'db_SbuItemRange' VARCHAR(255),'db_subItemReal' VARCHAR(255),'n_Result' VARCHAR(255),'str_Record_Time' VARCHAR(255)) ";
        
        [_db executeUpdate:personSql2];
        [_db close];

    }
    return self;
}

- (void)addCollection:(CollectModel *)collect{
    [_db open];

    [_db executeUpdate:@"INSERT INTO collectReport(n_MainItemID,str_SubItemName,db_SbuItemRange,db_subItemReal,n_Result,str_Record_Time)VALUES(?,?,?,?,?,?)",collect.n_MainItemID,collect.str_SubItemName,collect.db_SbuItemRange,collect.db_subItemReal,collect.n_Result,collect.str_Record_Time];
    [_db close];
    
}


- (NSString *)htmlStr:(ReportContentData *)reportContentData {
    NSString *htmls = [NSString stringWithFormat:@"<TR class=td align=left bgcolor=EBF5FB><TD class=td align=middle>%@ </TD><TD class=td align=middle>%@ - %@ </TD><TD class=td align=middle>%@ </TD><TD class=td align=middle>%@</TD></TR>",reportContentData.name,reportContentData.minValue,reportContentData.maxValue,reportContentData.realValue,reportContentData.resultState];
    return htmls;
}

/* 获取所有综合表单信息*/
- (NSArray *)allCollectMessage {
    NSString *sqliteStr = @"SELECT * FROM collectReport";
    return [self queryAllSqlite:sqliteStr];
}

/* 获取当前报告的综合信息*/
- (NSArray *)getCollectSingle:(NSString *)reportID {
    
    NSString *sqliteStr = [NSString stringWithFormat:@"SELECT * FROM collectReport where n_MainItemID = %@",reportID];

    return [self queryAllSqlite:sqliteStr];
}

/* 获取当前报告的中度异常综合信息*/
- (NSArray *)getCollectResult:(NSString *)reportID Result:(NSString *) result{
    
    NSString *sqliteStr = [NSString stringWithFormat:@"SELECT * FROM collectReport where n_MainItemID = %@ and n_Result = %@",reportID,result];
    
    return [self queryAllSqlite:sqliteStr];
}

/* 删除所有综合表单信息*/
- (void)deleteAllCollectMessage{
    [_db open];
    
    [_db executeUpdate:@"DELETE  FROM collectReport "];
    
    [_db close];
}

- (NSMutableArray *)queryAllSqlite:(NSString *)sqliteStr {
    [_db open];
    
    NSMutableArray *dataArray = [[NSMutableArray alloc] init];
    
    FMResultSet *res = [_db executeQuery:sqliteStr];
    
    while ([res next]) {
        CollectModel *collect = [[CollectModel alloc] init];
        collect.n_MainItemID = [res stringForColumn:@"n_MainItemID"];
        collect.str_SubItemName = [res stringForColumn:@"str_SubItemName"];
        collect.db_SbuItemRange = [res stringForColumn:@"db_SbuItemRange"];
        collect.db_subItemReal = [res stringForColumn:@"db_subItemReal"];
        collect.n_Result = [res stringForColumn:@"n_Result"];
        
        [dataArray addObject:collect];
    }
    
    [_db close];
    
    return dataArray;
}




/* 检测报告*/
- (NSString *)getCheckReportHtml:(NSString *)mainItemID RecordTime:(NSString *)recordTime{
    NSString *htmlStr = @"";
    Person *person = [[DataBase sharedDataBase] getCurrentLoginUser];
    NSArray *allSubItems = [[NSArray alloc] initWithArray:[[TblSubItemCaseManager sharedManager] getSingleReportAllSubItem:mainItemID]];
    for (TblSubItemCase *subItemCase in allSubItems) {
        if ([subItemCase isKindOfClass:[TblSubItemCase class]]) {
            TblMeasData *measData = [[TblMeasDataManager sharedManager] getHealthStateSubItemID:subItemCase.n_SubItemID Age:person.age type:person.health];
            NSInteger n_Result = [measData.n_Result integerValue];
            ReportContentData *report = [[ReportContentData alloc] init];
            NSInteger minValue=0,maxValue=0;
            if ([subItemCase.n_NormaBegin isEqualToString:@"0"]) {
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
                
                if (n_Result >= 2) {
                    CollectModel *collect = [[CollectModel alloc] init];
                    collect.n_MainItemID = mainItemID;
                    collect.str_SubItemName = report.name;
                    collect.db_subItemReal = report.realValue;
                    collect.db_SbuItemRange = [NSString stringWithFormat:@"%@-%@",report.minValue,report.maxValue];
                    collect.str_Record_Time = recordTime;
                    collect.n_Result = measData.n_Result;
                    [[HealthReportManager sharedManager]addCollection:collect];
                }
            }
            else {
                
                switch (n_Result) {
                    case -1:
                    {
                        minValue = [subItemCase.db_SubItemVal0 floatValue]*1000;
                        maxValue = [subItemCase.db_SubItemVal1 floatValue]*1000;
                        report.resultState = [self getCheckResultContent:subItemCase.str_GentalCall State:CHECK_RESULT_MIN_ABNORMAL];
                        break;
                    }
                    case 0:
                    {
                        minValue = [subItemCase.db_SubItemVal1 floatValue]*1000;
                        maxValue = [subItemCase.db_SubItemVal2 floatValue]*1000;
                        report.resultState = [self getCheckResultContent:subItemCase.str_NormalCall State:CHECK_RESULT_NORMAL];
                        break;
                    }
                    case 1:
                    {
                        minValue = [subItemCase.db_SubItemVal2 floatValue]*1000;
                        maxValue = [subItemCase.db_SubItemVal3 floatValue]*1000;
                        report.resultState = [self getCheckResultContent:subItemCase.str_TensionCall State:CHECK_RESULT_MEDIUM_ABNORMAL];
                        
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
                report.minValue = [NSString stringWithFormat:@"%.3f",MIN([subItemCase.db_SubItemVal1 floatValue], [subItemCase.db_SubItemVal2 floatValue])];
                report.maxValue = [NSString stringWithFormat:@"%.3f",MAX([subItemCase.db_SubItemVal1 floatValue], [subItemCase.db_SubItemVal2 floatValue])];
                report.realValue = [NSString stringWithFormat:@"%.3f",realValue];
                NSString *subItemStr = [self htmlStr:report];
                htmlStr = [htmlStr stringByAppendingString:subItemStr];
            
            }

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
            NSString *str = [[HealthReportManager sharedManager] getCheckReportHtml:reportList.reportID RecordTime:time];
            health.table = str;
            NSString *htmlPath = [[NSBundle mainBundle] pathForResource:reportList.reportName ofType:@"htm"];
            NSString *template = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
            template = [template stringByReplacingOccurrencesOfString:@"{{table}}" withString:str];
            NSDictionary *renderObject = [CommonCore dictionaryWithModel:health];
            NSString *content = [GRMustacheTemplate renderObject:renderObject fromString:template error:nil];
            [dictionary setObject:content forKey:reportList.reportName];
        }
    }
      NSString *collectHtmlString  = [self creatCollectDataHtml:health];
    [dictionary setObject:collectHtmlString forKey:@"量子检测综合报告单"];

    NSString *jsonString = [CommonCore jsonWithArray:dictionary];
    return jsonString;
   
}

/* 创建综合表单的html标签*/
- (NSString *)creatCollectDataHtml:(HealthModel *)health {
    NSString *htmlString1 = @"<TABLE cellSpacing=0 cellPadding=0 width=590 align=center border=0><TBODY><TR><TD height=20></TD></TR></TBODY></TABLE><TABLE width=590 align=center border=0><TBODY><TR><TD><FONT size=3><STRONG>可能有隐患的问题</STRONG></FONT></TD></TR></TBODY></TABLE><TABLE class=table cellSpacing=0 cellPadding=3 width=590 align=center border=0><TBODY><TR class=td height=28 align=center bgColor=#b3d9ed><TD class=td><STRONG>系统</STRONG></TD><TD class=td><STRONG>检测项目</STRONG></TD><TD class=td><STRONG>正常范围</STRONG></TD><TD class=td><STRONG>实际测量值</STRONG></TD><TD class=td><STRONG>专家建议</STRONG></TD></TR>";
    
    NSString *htmlString2 = @"<TABLE cellSpacing=0 cellPadding=0 width=590 align=center border=0><TBODY><TR><TD height=20></TD></TR></TBODY></TABLE><TABLE width=590 align=center border=0><TBODY><TR><TD><FONT size=3><STRONG>有亚健康趋势的问题</STRONG></FONT></TD></TR></TBODY></TABLE><TABLE class=table cellSpacing=0 cellPadding=3 width=590 align=center border=0><TBODY><TR class=td height=28 align=center bgColor=#b3d9ed><TD class=td><STRONG>系统</STRONG></TD><TD class=td><STRONG>检测项目</STRONG></TD><TD class=td><STRONG>正常范围</STRONG></TD><TD class=td><STRONG>实际测量值</STRONG></TD><TD class=td><STRONG>专家建议</STRONG></TD></TR>";
    
    //亚健康问题
    for (int i = 1 ; i < 100; ++i) {
        NSString *reportID = [NSString stringWithFormat:@"%d",i];
        NSArray *collects = [[HealthReportManager sharedManager] getCollectResult:reportID Result:@"2"];
        if (collects.count >0) {
            TblSuggest *suggest = [[TblSuggestManager sharedManager] getSuggests:reportID];
            for (int index = 0; index < collects.count; ++index) {
                CollectModel *collect = collects[index];
                if ([collect isKindOfClass:[CollectModel class]]) {
                        if (index == 0) {
                            htmlString2 = [htmlString2 stringByAppendingFormat:@"<TR class=td align=left bgColor=#ebf5fb><TD class=td rowSpan=%ld align=center>%@</TD><TD class=td align=center>%@</TD><TD class=td align=center>%@</TD><TD class=td align=center>%@</TD><TD class=td rowSpan=%ld width=200 align=left>%@</TD></TR>",collects.count,suggest.system,collect.str_SubItemName,collect.db_SbuItemRange,collect.db_subItemReal,collects.count,suggest.suggest];
                        }else {
                            htmlString2 = [htmlString2 stringByAppendingFormat:@"  <TR class=td align=left bgColor=#ebf5fb><TD class=td align=center>%@</TD><TD class=td align=center>%@</TD><TD class=td align=center>%@</TD></TR>",collect.str_SubItemName,collect.db_SbuItemRange,collect.db_subItemReal];
                        }

                }
            }

        }
    }
    //隐患问题
    for (int i = 1 ; i < 100; ++i) {
        NSString *reportID = [NSString stringWithFormat:@"%d",i];
        NSArray *collects = [[HealthReportManager sharedManager] getCollectResult:reportID Result:@"3"];
        if (collects.count >0) {
            TblSuggest *suggest = [[TblSuggestManager sharedManager] getSuggests:reportID];
            for (int index = 0; index < collects.count; ++index) {
                CollectModel *collect = collects[index];
                if ([collect isKindOfClass:[CollectModel class]]) {

                    if (index == 0) {
                        htmlString1 = [htmlString1 stringByAppendingFormat:@"<TR class=td align=left bgColor=#ebf5fb><TD class=td rowSpan=%ld align=center>%@</TD><TD class=td align=center>%@</TD><TD class=td align=center>%@</TD><TD class=td align=center>%@</TD><TD class=td rowSpan=%ld width=200 align=left>%@</TD></TR>",collects.count,suggest.system,collect.str_SubItemName,collect.db_SbuItemRange,collect.db_subItemReal,collects.count,suggest.suggest];
                    }else {
                        htmlString1 = [htmlString1 stringByAppendingFormat:@"  <TR class=td align=left bgColor=#ebf5fb><TD class=td align=center>%@</TD><TD class=td align=center>%@</TD><TD class=td align=center>%@</TD></TR>",collect.str_SubItemName,collect.db_SbuItemRange,collect.db_subItemReal];
                    }
                    
                }
            }
            
        }
    }
    htmlString1 = [htmlString1 stringByAppendingString:@"</TBODY></TABLE>"];
    htmlString2 = [htmlString2 stringByAppendingString:@"</TBODY></TABLE>"];

    health.table = [htmlString1 stringByAppendingString:htmlString2];
    NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"量子检测综合报告单" ofType:@"htm"];
    NSString *template = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
    template = [template stringByReplacingOccurrencesOfString:@"{{table}}" withString:health.table];
    NSDictionary *renderObject = [CommonCore dictionaryWithModel:health];
    NSString *content = [GRMustacheTemplate renderObject:renderObject fromString:template error:nil];
    if (content) {
        [self deleteAllCollectMessage];
    }
    return content;
}



@end
