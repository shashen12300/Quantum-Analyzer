//
//  ReportContentData.h
//  Quantum Analyzer
//
//  Created by 宋冲冲 on 2016/12/28.
//  Copyright © 2016年 宋冲冲. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ReportContentData : NSObject

/* 项目名称*/
@property(nonatomic,copy) NSString *name;
/* 检测范围，最小值*/
@property(nonatomic,copy) NSString *minValue;
/* 检测范围，最大值*/
@property(nonatomic,copy) NSString *maxValue;
/* 实际测量值*/
@property(nonatomic,copy) NSString *realValue;
/* 检测结果*/
@property(nonatomic,copy) NSString *resultState;


@end
