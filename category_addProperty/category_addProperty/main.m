//
//  main.m
//  category_addProperty
//
//  Created by 马天野 on 2018/8/26.
//  Copyright © 2018年 Maty. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TYPerson.h"
#import "TYPerson+Test1.h"
#import "TYPerson+Test2.h"

// 加上 static 之后,就拿不到了
extern const void * TYNameKey;

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        

        TYPerson *person = [[TYPerson alloc] init];
        person.age = 10;
        person.height = 20;
        person.name = @"ttt";
        person.country = @"China";
        person.no = 1000;
        
        TYPerson *person2 = [[TYPerson alloc] init];
        person2.age = 30;
        person2.height = 40;
        person2.name = @"eed";
        
        NSLog(@"\nperson:  age = %d\n height = %d\n name = %@\n country = %@\n no = %d\n",person.age, person.height,person.name, person.country, person.no);
        NSLog(@"\nperspn2: age = %d\n height = %d\n name = %@\n",person2.age, person2.height, person2.name);
        
    }
    return 0;
}
