//
//  main.m
//  Category01
//
//  Created by 马天野 on 2018/8/20.
//  Copyright © 2018年 Maty. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TYPerson.h"
#import "TYPerson+eat.h"
#import "TYPerson+sleep.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        TYPerson *person = [[TYPerson alloc] init];
        
//        [person run];
//        [person eat];
//        [person sleep];
        
        [person test];
        
    }
    return 0;
}
