// =======================================================
// This file is auto generated by [Convert Excel To .plist and .sqlite] convertor,
// do not edit by youself!
// >>>> by HuMinghua <<<<  2016年12月27日 下午3:55:35
// ======================================================


#import <Foundation/Foundation.h>

#pragma mark - 
@class TblMeasData;
@interface TblMeasDataManager : NSObject
{
    NSMutableArray  *_tblMeasDatas;
}
+ (TblMeasDataManager *) sharedManager;

- (NSArray *)allTblMeasDatas;

- (TblMeasData *)getHealthStateSubItemID:(NSString *)subItemID Age:(NSString *)age type:(NSString *)type;

@end