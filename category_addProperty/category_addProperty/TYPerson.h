//
//  TYPerson.h
//  category_addProperty
//
//  Created by 马天野 on 2018/8/26.
//  Copyright © 2018年 Maty. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TYPerson : NSObject

{
    int _age;
}

//@property (nonatomic, assign) int age;

- (void)setAge:(int)age;
- (int)age;

@end
