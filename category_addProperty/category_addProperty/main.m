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

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        TYPerson *person = [[TYPerson alloc] init];
        person.age = 10;
        person.height = 20;
        
        TYPerson *person2 = [[TYPerson alloc] init];
        person2.age = 30;
        person2.height = 40;
        
        NSLog(@"person:  age = %d\n height = %d\n",person.age, person.height);
        NSLog(@"perspn2: age = %d\n height = %d\n",person2.age, person2.height);
        
    }
    return 0;
}
