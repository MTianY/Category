//
//  TYPerson+Test1.m
//  category_addProperty
//
//  Created by 马天野 on 2018/8/27.
//  Copyright © 2018年 Maty. All rights reserved.
//

#import "TYPerson+Test1.h"

//int height_test;
NSMutableDictionary *dict_test;
NSMutableDictionary *name_dict;

@implementation TYPerson (Test1)

+ (void)load {
    dict_test = [NSMutableDictionary dictionary];
    name_dict = [NSMutableDictionary dictionary];
}

- (void)setHeight:(int)height {
    
    // 方案1
//    height_test = height;
    
    // 方案2
    NSString *p = [[NSString alloc] initWithFormat:@"%p",self];
    dict_test[p] = @(height);
    
}

- (int)height {
//    return height_test;
    
    NSString *p = [[NSString alloc] initWithFormat:@"%p",self];
    return [dict_test[p] intValue];
}

- (void)setName:(NSString *)name {
    NSString *p = [[NSString alloc] initWithFormat:@"%p",self];
    name_dict[p] = name;
}

- (NSString *)name {
    NSString *p = [[NSString alloc] initWithFormat:@"%p",self];
    return name_dict[p];
}

@end
