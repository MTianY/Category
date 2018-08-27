//
//  TYPerson+Test2.m
//  category_addProperty
//
//  Created by 马天野 on 2018/8/28.
//  Copyright © 2018年 Maty. All rights reserved.
//

#import "TYPerson+Test2.h"
#import <objc/runtime.h>

/**
 * 这种写法的 key 相当于 NULL, 取值时会发生冲突
 */
//const void * TYNameKey;
//const void * TYNoKey;

/**
 * 给每个 key 都赋一个唯一的值
 * 这里将每个 key 的内存地址赋值给它
 *
 * 这个写法外面可以拿到,所以要加 static
 */
//const void * TYNameKey = &TYNameKey;
//const void * TYNoKey = &TYNoKey;

/**
 * 传自己的地址
 *
 * 可以简化
 */
//static const void * TYNameKey = &TYNameKey;
//static const void * TYNoKey = &TYNoKey;

///**
// * 简化写法, char 占1个字节,空间小
// * 而且不用给它赋值,我们只需要其内存地址而已
// */
//static const char TYNameKey;
//static const char TYNoKey;

///**
// * 直接传字符串,可读性高一些
// */
//#define TYNameKey @"name"
//#define TYNoKey @"no"

@implementation TYPerson (Test2)

- (void)setCountry:(NSString *)country {
    // TYNameKey 相当于 NSString *str = @"name"; 其实是相当于将@"name"的内存地址传进去
    objc_setAssociatedObject(self, @selector(country), country, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)country {
    return objc_getAssociatedObject(self, @selector(country));
}

- (void)setNo:(int)no {
    objc_setAssociatedObject(self, @selector(no), @(no), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (int)no {
    return [objc_getAssociatedObject(self, @selector(no)) intValue];
}

@end
