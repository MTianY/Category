//
//  TYPerson+sleep.m
//  Category01
//
//  Created by 马天野 on 2018/8/20.
//  Copyright © 2018年 Maty. All rights reserved.
//

#import "TYPerson+sleep.h"

@implementation TYPerson (sleep)

- (void)sleep {
    NSLog(@"%s",__func__);
}

+ (void)classMethod_sleep {
    NSLog(@"%s",__func__);
}

- (void)test {
    NSLog(@"%s",__func__);
}

@end
