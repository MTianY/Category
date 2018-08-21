//
//  TYPerson+sleep.h
//  Category01
//
//  Created by 马天野 on 2018/8/20.
//  Copyright © 2018年 Maty. All rights reserved.
//

#import "TYPerson.h"

@interface TYPerson (sleep) <
NSCoding
>

@property (nonatomic, assign) int sleepPropertyOne;

- (void)sleep;

+ (void)classMethod_sleep;

- (void)test;

@end
