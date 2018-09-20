# Category

## 一. category 的基本使用

有如下类: `TYPerson`.

- 对象方法: `- (void)run;`

及其分类: `TYPerson+eat`

- 对象方法: `- (void)eat;`

分类:`TYPerson+sleep`

- 属性: `@property (nonatomic, assign) int sleepPropertyOne;`
- 对象方法: `- (void)sleep;`
- 类方法: `+ (void)classMethod_sleep;`
- 遵守的协议: `<NSCoding>`

调用分类方法

```objc
TYPerson *person = [[TYPerson alloc] init];
        
[person run];
[person eat];
[person sleep];
```

## 二. category 的底层结构

分别将`TYPerson+eat.m`和`TYPerson+sleep.m`编译成`.cpp`文件.查看其底层实现结构.

#### 1.对比两个分类对象生成的`.cpp`文件分析

在这个文件中,可以看到分类编译完毕后,其底层结构如下:

```c++
// TYPerson_eat.m 结构体对象
struct _category_t {
	const char *name;
	struct _class_t *cls;
	const struct _method_list_t *instance_methods;
	const struct _method_list_t *class_methods;
	const struct _protocol_list_t *protocols;
	const struct _prop_list_t *properties;
};
```

- 当分类编译完毕后,其中所有的信息(属性,协议,方法...)都会整合到`struct _category_t`这个结构体对象中.
- `TYPerson+sleep`这个分类,其信息是整合到另一个结构体对象中.如下:

```c++
// TYPerson+sleep.m 结构体对象
struct _category_t {
	const char *name;
	struct _class_t *cls;
	const struct _method_list_t *instance_methods;
	const struct _method_list_t *class_methods;
	const struct _protocol_list_t *protocols;
	const struct _prop_list_t *properties;
};
```

**对比发现,两个结构体对象的结构的相同.**

接着看`TYPerson+eat.cpp`文件中的`_OBJC_$_CATEGORY_TYPerson_$_eat` 对象

```c++
// 因为 TYPerson+eat 这个分类只有一个对象方法 -(void)eat;
static struct _category_t _OBJC_$_CATEGORY_TYPerson_$_eat __attribute__ ((used, section ("__DATA,__objc_const"))) = 
{
	"TYPerson",
	0, // &OBJC_CLASS_$_TYPerson,
	(const struct _method_list_t *)&_OBJC_$_CATEGORY_INSTANCE_METHODS_TYPerson_$_eat,
	0,
	0,
	0,
};
```

- 上面这个对象和之前的结构一一对应赋值的.

下面看`TYPerson+sleep.cpp`中的`_OBJC_$_CATEGORY_TYPerson_$_sleep`对象
    
```c++
// 因为 TYPerson+sleep 中有属性,协议,对象方法及类方法
static struct _category_t _OBJC_$_CATEGORY_TYPerson_$_sleep __attribute__ ((used, section ("__DATA,__objc_const"))) = 
{
	"TYPerson",
	0, // &OBJC_CLASS_$_TYPerson,
	(const struct _method_list_t *)&_OBJC_$_CATEGORY_INSTANCE_METHODS_TYPerson_$_sleep,
	(const struct _method_list_t *)&_OBJC_$_CATEGORY_CLASS_METHODS_TYPerson_$_sleep,
	(const struct _protocol_list_t *)&_OBJC_CATEGORY_PROTOCOLS_$_TYPerson_$_sleep,
	(const struct _prop_list_t *)&_OBJC_$_PROP_LIST_TYPerson_$_sleep,
};
```

## 三.通过分析 runtime 运行时源码了解 category 的本质

- runtime 运行时源码下载地址

[Source Browser](https://opensource.apple.com/tarballs/objc4/)

#### 1. runtime 中 category_t 的结构

- 运行时会将分类(category_t)中的 `instanceMethods` 合并到 `class 对象`中去
- 会将 `classMethods` 合并到 `meta-class对象` 中去

```objc
struct category_t {
    const char *name;
    classref_t cls;
    struct method_list_t *instanceMethods;
    struct method_list_t *classMethods;
    struct protocol_list_t *protocols;
    struct property_list_t *instanceProperties;
    // Fields below this point are not always present on disk.
    struct property_list_t *_classProperties;

    method_list_t *methodsForMeta(bool isMeta) {
        if (isMeta) return classMethods;
        else return instanceMethods;
    }

    property_list_t *propertiesForMeta(bool isMeta, struct header_info *hi);
};
```

#### 2.解读上述合并的实现流程

- 首先来到 `objc-os.mm` 文件的 `_objc_init`方法.

![Snip20180821_1](https://lh3.googleusercontent.com/-GW1z0IJ-XOs/W3tIBulQ9RI/AAAAAAAAAE4/h0UssipDrHsRKQhCQutih64xPi0YlvAHgCHMYCw/I/Snip20180821_1.png)

```objc
void _objc_init(void)
{
    static bool initialized = false;
    if (initialized) return;
    initialized = true;
    
    // fixme defer initialization until an objc-using image is found?
    environ_init();
    tls_init();
    static_init();
    lock_init();
    exception_init();

    _dyld_objc_notify_register(&map_images, load_images, unmap_image);
}
```

- 发现`_dyld_objc_notify_register(&map_images, load_images, unmap_image)`这个方法,会调用 `map_images`,跳到`map_images`方法内:

```objc
/***********************************************************************
* map_images
* Process the given images which are being mapped in by dyld.
* Calls ABI-agnostic code after taking ABI-specific locks.
*
* Locking: write-locks runtimeLock
**********************************************************************/
void
map_images(unsigned count, const char * const paths[],
           const struct mach_header * const mhdrs[])
{
    rwlock_writer_t lock(runtimeLock);
    return map_images_nolock(count, paths, mhdrs);
}
```

- `map_images`方法返回`map_images_nolock(count, paths, mhdrs)`, 跳到其实现:

```objc
void 
map_images_nolock(unsigned mhCount, const char * const mhPaths[],
                  const struct mach_header * const mhdrs[])
{
    
    // ... 省略若干方法
    ...
    
    if (hCount > 0) {
        // 加载镜像
        _read_images(hList, hCount, totalClasses, unoptimizedTotalClasses);
    }

    firstTime = NO;
}
```

- 接着来到`_read_images(...)`这个方法,

```objc
/***********************************************************************
* _read_images
* Perform initial processing of the headers in the linked 
* list beginning with headerList. 
*
* Called by: map_images_nolock
*
* Locking: runtimeLock acquired by map_images
**********************************************************************/
void _read_images(header_info **hList, uint32_t hCount, int totalClasses, int unoptimizedTotalClasses)
{
    // 省略若干方法...
    ...
    
    // Discover categories. 
    for (EACH_HEADER) {
        // 二维数组
        category_t **catlist = 
            _getObjc2CategoryList(hi, &count);
        bool hasClassProperties = hi->info()->hasCategoryClassProperties();

        for (i = 0; i < count; i++) {
            category_t *cat = catlist[i];
            Class cls = remapClass(cat->cls);

            if (!cls) {
                // Category's target class is missing (probably weak-linked).
                // Disavow any knowledge of this category.
                catlist[i] = nil;
                if (PrintConnecting) {
                    _objc_inform("CLASS: IGNORING category \?\?\?(%s) %p with "
                                 "missing weak-linked target class", 
                                 cat->name, cat);
                }
                continue;
            }

            // Process this category. 
            // First, register the category with its target class. 
            // Then, rebuild the class's method lists (etc) if 
            // the class is realized. 
            bool classExists = NO;
            if (cat->instanceMethods ||  cat->protocols  
                ||  cat->instanceProperties) 
            {
                addUnattachedCategoryForClass(cat, cls, hi);
                if (cls->isRealized()) {
                    // 重新组织下 class 对象的方法
                    remethodizeClass(cls);
                    classExists = YES;
                }
                if (PrintConnecting) {
                    _objc_inform("CLASS: found category -%s(%s) %s", 
                                 cls->nameForLogging(), cat->name, 
                                 classExists ? "on existing class" : "");
                }
            }

            if (cat->classMethods  ||  cat->protocols  
                ||  (hasClassProperties && cat->_classProperties)) 
            {
                addUnattachedCategoryForClass(cat, cls->ISA(), hi);
                if (cls->ISA()->isRealized()) {
                    // 重新组织下 meta-class 对象的方法
                    remethodizeClass(cls->ISA());
                }
                if (PrintConnecting) {
                    _objc_inform("CLASS: found category +%s(%s)", 
                                 cls->nameForLogging(), cat->name);
                }
            }
        }
    }

    ts.log("IMAGE TIMES: discover categories");

    // Category discovery MUST BE LAST to avoid potential races 
    // when other threads call the new category code before 
    // this thread finishes its fixups.
    
    // 省略若干方法
    ...
    
}
```

- 来到 `remethodizeClass(cls)` 方法

```objc
/***********************************************************************
* remethodizeClass
* Attach outstanding categories to an existing class.
* Fixes up cls's method list, protocol list, and property list.
* Updates method caches for cls and its subclasses.
* Locking: runtimeLock must be held by the caller
**********************************************************************/
static void remethodizeClass(Class cls)
{
    category_list *cats;
    bool isMeta;

    runtimeLock.assertWriting();

    isMeta = cls->isMetaClass();

    // Re-methodizing: check for more categories
    if ((cats = unattachedCategoriesForClass(cls, false/*not realizing*/))) {
        if (PrintConnecting) {
            _objc_inform("CLASS: attaching categories to class '%s' %s", 
                         cls->nameForLogging(), isMeta ? "(meta)" : "");
        }
        
        // 核心方法: 将 cats(分类对象)附加到 cls(这里为类对象) 中去
        attachCategories(cls, cats, true /*flush caches*/);        
        free(cats);
    }
}
```

- 来到`attachCategories(cls, cats, true /*flush caches*/) ` 方法

```objc
// Attach method lists and properties and protocols from categories to a class.
// Assumes the categories in cats are all loaded and sorted by load order, 
// oldest categories first.

// 参数1: Class cls -- 类对象(元类对象同理)
// 参数2: category_list *cats -- 分类列表(装着每个分类的结构体)

static void 
attachCategories(Class cls, category_list *cats, bool flush_caches)
{
    if (!cats) return;
    if (PrintReplacedMethods) printReplacements(cls, cats);
    
    // 是否是元类对象
    bool isMeta = cls->isMetaClass();

    // fixme rearrange to remove these intermediate allocations
    /** 方法列表的数组(下面的属性和协议同理)
     * 二维数组:大的数组里包含小的数组,形式如下
     
     [
        [method_t, method_t],
        [method_t, method_t],
        ...
     ]
     
     */
    
    method_list_t **mlists = (method_list_t **)
        malloc(cats->count * sizeof(*mlists));
    // 属性列表的数组
    property_list_t **proplists = (property_list_t **)
        malloc(cats->count * sizeof(*proplists));
    // 协议列表的数组
    protocol_list_t **protolists = (protocol_list_t **)
        malloc(cats->count * sizeof(*protolists));

    // Count backwards through cats to get newest categories first
    int mcount = 0;
    int propcount = 0;
    int protocount = 0;
    int i = cats->count;
    bool fromBundle = NO;
    while (i--) {
        // 取出某个分类
        auto& entry = cats->list[i];
    
        // 1. entry.cat 中的 cat 就是 category_t.所以说上面的 entry 就是一个分类.
        // 2. 根据 isMeta 决定取出的是类方法还是对象方法.这里统一按类对象处理,元类对象同理.
        method_list_t *mlist = entry.cat->methodsForMeta(isMeta);
        
        // 将取出的方法 mlist 放到 mlists 这个大的数组中去
        if (mlist) {
            mlists[mcount++] = mlist;
            fromBundle |= entry.hi->isBundle();
        }
        
        // 取出属性
        property_list_t *proplist = 
            entry.cat->propertiesForMeta(isMeta, entry.hi);
        // 将属性放到大的数组中去
        if (proplist) {
            proplists[propcount++] = proplist;
        }
        
        // 取出协议
        protocol_list_t *protolist = entry.cat->protocols;
        // 将协议放到大的数组中去
        if (protolist) {
            protolists[protocount++] = protolist;
        }
    }

    // 得到类对象中的数据
    auto rw = cls->data();

    prepareMethodLists(cls, mlists, mcount, NO, fromBundle);
    
    // 取出类对象中的方法列表,将所有分类的对象方法 mlists 加进去
    rw->methods.attachLists(mlists, mcount);
    free(mlists);
    if (flush_caches  &&  mcount > 0) flushCaches(cls);
    
    // 将所有分类的属性加到类对象中去
    rw->properties.attachLists(proplists, propcount);
    free(proplists);

    // 将所有分类的协议加到类对象中去
    rw->protocols.attachLists(protolists, protocount);
    free(protolists);
}
```

- 经过上面的操作,会将所有的 分类中的 `对象方法(类方法)`,`属性`,`协议`都`合并到类对象(元类对象)`中去.
- 看上面的`attachLists`方法:

```objc
/**
 * 参数一 addedLists : 分类的列表
 * 参数二 addedCount : 分类的个数
 */
void attachLists(List* const * addedLists, uint32_t addedCount) {
        if (addedCount == 0) return;

        if (hasArray()) {
            // many lists -> many lists
            uint32_t oldCount = array()->count;
            uint32_t newCount = oldCount + addedCount;
            // 根据 newCount 重新分配内存(扩容)
            setArray((array_t *)realloc(array(), array_t::byteSize(newCount)));
            array()->count = newCount;
            
            // array()->lists 指的是原先类对象的信息列表
            // 将原先类对象的信息列表,在内存中向后移动 addedCount 位
            memmove(array()->lists + addedCount, array()->lists, 
                    oldCount * sizeof(array()->lists[0]));
                    
            // 将分类的总信息列表 copy 到原先类的信息列表中.
            memcpy(array()->lists, addedLists, 
                   addedCount * sizeof(array()->lists[0]));
        }
        else if (!list  &&  addedCount == 1) {
            // 0 lists -> 1 list
            list = addedLists[0];
        } 
        else {
            // 1 list -> many lists
            List* oldList = list;
            uint32_t oldCount = oldList ? 1 : 0;
            uint32_t newCount = oldCount + addedCount;
            setArray((array_t *)malloc(array_t::byteSize(newCount)));
            array()->count = newCount;
            if (oldList) array()->lists[addedCount] = oldList;
            memcpy(array()->lists, addedLists, 
                   addedCount * sizeof(array()->lists[0]));
        }
    }
```
    

- 大致流程如下,以方法列表为例:
    
    ![](https://lh3.googleusercontent.com/_4UIzitLVyRlIiP8tYhjQI9iPAjF8DBdFKiAgVIMCS1Pu5vzX2OiLf9uK4ASqPgykrq3d3ZKkdxeCyGdqIHkq5tKPJXnP40scjUPuzSgLxQpqT4BHipB0753QJDqAbgQ1ZiB4iJtLIaXIeRtlsk5XU3zAgfpsOmmSsMmPeshkrYfYiiXhJqArA98MsL2YlGWQOOYfb-gQSDO6m5X8D-asO0JMylGMvetyt_Oxy1aYHpczalH8mCoX4e_cUuMGIgTmA9PD_Iws3SAtIIn5iYGrd9Nf2FGP7uVIKEqc3rA4jrcNot1LAZB7aw2rdWgpli-5PQho5uUrHcdvmdGEFOQbYUkQZVEl4dr4HxLxpHr2x53Q_dOq5MG4Ox1q4ANuJURd7IuLfR7bnuQYGKY2_iD68JMJvttyMibU-VDTWaOEdOxl7WrYyrVpVQkqr6l98LyJt9hYJi4jgEjxARcr7GJAsKTtSna3F-Ckss6umXHujakLAWf_rDn4FsWzH8T251kQOCw6XJQnXPlQFCRLCb9SmGDJqi6wBFjepWzX49bpj_YWZgnHFgCbVtwcE9JMqgbjSVGlCJqNVJMGuXBXnt873lI-26670wM1O1g14FaAaQfTce9SL4kaIkz_EWjkw=w2400-h1170-no)
    
- 从上面也看出,`分类中方法会被优先调用.`
    - 如上面的分类,每个中都有`test`方法.那么用`[person test]`会先执行谁的方法呢?

    ```c
    // 打印结果.这里是先执行 sleep 分类的 test 方法.
    [TYPerson(sleep) test]
    ```
    
    - 最后编译的分类,如果找到方法会优先调用.

    ![](https://lh3.googleusercontent.com/MkDp0VF2KSR8SWYJJJcibTfpV0w1ZuYtmdKDhGwtt-XNbAK6hNJAQ7npRZzp4xT--_rhjZ8nhKJGAftzh7kFsx5r_5OV3JVSBPvKMJO5-WIEmL0QkhYYBCu1XmzFy3dbNcBFTDCgXTN7Ou6d4rxsAi_Z6pH2VUo7lSVj3a8tZbXPoHR30JLwppkgzjk-SPRqVozymeVBkaYjUtWCQl0XKkiCStk5IIiA_qLA1xmP6t-5CztjezlWAltSx4MirUXM4QQA0WDKry8opFGj7YuZawS8C45kodoDrpleJ4nGSTdWsUjr7kTHh6Wip2ffm1MhtZnMtMcxzBryIr9LB3TNsx94MlkEYl1QzfJcMAiOFBGQK5DZsDJaiDIFVusJFpi0y_g8wmXvVBnmsUWbiwAB9PcG-GQP1_UrzpTX2Qad6fvjXXUxxCFs34Sfs0wXIRutRVdPzeKFdmSCZZhhIhUgiK4a2zoJmojdFHpsgUBRZ9bH2zYsCOLAaIGWoxJJsgJwVeNRX21LYaEvS8ZGW-pasubbku6TGVUb0O3QLBCFCwOC3gXmPK0YMP4xwRbBbyUEqLSs9PTdaj_1bjQFp4iZ8p9x1NYqKpl4vwDYcWPVd_9g7vJzBzbUrxfixKd_jA=w1292-h292-no)
    
- 那么分类和类扩展的区别是什么呢?
    -  分类是在`运行时`,将数据合并到类信息中.
    -  而类拓展是在`编译时`,它的数据就已经包含在类信息中了. 

```objc

// TYPerson.m 文件
// 类拓展
@interface TYPerson ()
@end
```

## 四.分类能否添加成员变量?

> 分类中不能`直接`添加成员变量.但是可以间接实现`有成员变量的效果.`

### 1.类的属性

`TYPerson`类,有个属性`@property (nonatomic, assign) int age;` 如:

```objc
@interface TYPerson : NSObject
@property (nonatomic, assign) int age;
@end
```

- 我们知道上面那样声明属性有如下几层意思:
    - 它会自动生成一个 `_age` 成员变量.
    - 会生成 `- (void)setAge:(int)age`方法的声明
    - 会生成 `- (int)age` 方法的声明.
    - 同时它还会生成 `setAge:`和`-(int)age`方法的实现:

    ```objc
    // .h 文件
    #import <Foundation/Foundation.h>

    @interface TYPerson : NSObject
    
    {
        int _age;
    }
    
    //@property (nonatomic, assign) int age;
    
    - (void)setAge:(int)age;
    - (int)age;
    
    @end
    
    /**************/
    // .m 文件
    #import "TYPerson.h"

    @implementation TYPerson
    
    - (void)setAge:(int)age {
        _age = age;
    
    
    }
    
    - (int)age {
        return _age;
    }
    
    @end
    ``` 

### 2.分类中添加属性

在分类`TYPerson+Test1`中添加属性`@property (nonatomic, assign) int height;`.那么它只有如下一层意思:

- 会自动生成`setHeight:`和`- (int)height;` 方法的`声明`
- `不会生成带下划线的成员变量`
- `不会生成方法的实现.`

```objc
#import "TYPerson.h"

@interface TYPerson (Test1)

//@property (nonatomic, assign) int height;

- (void)setHeight:(int)height;
- (int)height;

@end
```

### 3. 分类中能否添加成员变量?

分类中可以添加属性,但是其不会自动生成`带下划线的成员变量`.那么是否可以手动添加呢?

- 答案是: `分类中也不能手动添加成员变量.`

在分类中写入如下代码,编译器会报错:

![](https://lh3.googleusercontent.com/71VIj6sJrHQTQXLzmUkmwcVSGgkEU-hkzNRtkrXQhYC_cjHP2aWVNjHJkQCsIP__VzpqeP7b0a3_aUKcc6HqNMwthyBWfX-YKEy4oKX7njI8qVXbaTCZ6yQtoLC7-JBDQiMRYokXMQFRyO08C_kqZ1iZ6lAw0Ty64c5dPYhezOKKfeijs7POLZ0jw26fFIpvbtgjUNb3GG7DdE8NhQ6wft88Tq_ilNDrQzVHbuTFNdxWdDAuvJvZ7NjlwoXXgLIOLHAYi1uTbka0sob_bGfmD95z-iMkl4QMhLjrqByW2_8DSnBx_uHrDZieE4zIf0bFNDtUJQjTl1E0BILy24PCrBmZ5-nZ_4VgihtSKRRDFusK7groHBvX9D4qZ917XCf8PXa7y5QbRpvmQzqgywDX2nQRk2ShF911FbDp0ZWlj4k9DpetAdFBNoapHCj9Bfx-CHHuYnZJ5lYNOeOr62k0WiJyhC_ef_wCegL2g_XZg2d-d4hyG2LTaur1YWqvhWIR3NZWX6Z-HqSNLjgV8f9cgKs2i6kErQk6Uper1qJ9f9CLUZ2MwiV3I6PPdaxztpa1q5C6YBZyUVCsha1PxvFXx_J1CJTHau1-zEB8-1jsQ3dwbK0aBKyBFYLFt26fG_o=w966-h128-no)

```objc
#import "TYPerson.h"

@interface TYPerson (Test1)

{
    // 此处编译器会报错: 
    // Instance variables may not be placed in categories
    int _height;
}

//@property (nonatomic, assign) int height;

- (void)setHeight:(int)height;
- (int)height;

@end
```

**所以分类中不能直接添加成员变量.**

## 五.间接实现让分类中看起来有成员变量的效果.

### 1.分类中添加属性的用法?

在分类中添加属性,那么我们如果希望同在类中添加属性的使用效果一样.如上面添加的两个属性,那么我们希望这么用:

```objc
TYPerson *person = [[TYPerson alloc] init];
person.age = 10;
person.height = 20;
NSLog(@"%d",person.age);
NSLog(@"%d",person.height);
```

- 如上,因为分类中没有成员变量,所以`set和get`方法都不能通过成员变量来赋值,那么上面的`person.height`就拿不到`20`这个值.

### 2.间接实现分类中看起来有成员变量的方法.

#### 2.1 第1种方法: 定义一个全局变量来存传进来的值. (Pass掉)

先看分类中的代码结构:

```objc
// .h 文件
#import "TYPerson.h"

@interface TYPerson (Test1)
@property (nonatomic, assign) int height;
//- (void)setHeight:(int)height;
//- (int)height;
@end

/***************/
// .m 文件
#import "TYPerson+Test1.h"
@implementation TYPerson (Test1)

- (void)setHeight:(int)height {
    
}

- (int)height {
    return 0;
}
@end
```

我们在`.m`文件中添加如下一个全局变量:`int heigth_test;`

```objc
#import "TYPerson+Test1.h"
int height_test;

@implementation TYPerson (Test1)

- (void)setHeight:(int)height {
    height_test = height;
}

- (int)height {
    return height_test;
}
@end
```
     
那么再执行如下方法:

```objc
TYPerson *person = [[TYPerson alloc] init];
person.age = 10;
person.height = 20;
 NSLog(@"age = %d\n height = %d",person.age, person.height);
```

得到打印结果:

```c
age = 10
height = 20
```

如上看起来貌似是实现了有成员变量的功能.但是其还有`问题.`

- 因为`int height_test`是个全局变量.那么当创建其他的 person 对象时,取出的 height 就都一样了.


```objc
person: age = 10 height = 40
perspn2: age = 30 height = 40
```

**所以第1种方法不太完美. pass 掉**

#### 2.2 第2种方法: 定义一个字典来通过 key 记录不同的值(pass 掉)

上面的方法当有多个不同的对象时,满足不了.那么针对不同对象对应的不同的值,我们想到通过 key-value 的方式来实现.一个 key 对应一个 value. 那么我们创建一个字典.

```objc
#import "TYPerson+Test1.h"

//int height_test;
NSMutableDictionary *dict_test;

@implementation TYPerson (Test1)

+ (void)load {
    dict_test = [NSMutableDictionary dictionary];
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

@end
```

打印结果:

```c
person:  age = 10 height = 20
perspn2: age = 30 height = 40
```

看起来是可以针对不同对象进行操作.但是这个方案还是存在一些问题的,如线程安全问题 .并且如果分类中新增一个属性的话,那么就要把上面的步骤都重新为新的属性写一遍.如增加一个`name`属性.那么要重新写遍如下方法,比较麻烦

```objc
NSMutableDictionary *name_dict;

+ (void)load {
    dict_test = [NSMutableDictionary dictionary];
    name_dict = [NSMutableDictionary dictionary];
}

- (void)setName:(NSString *)name {
    NSString *p = [[NSString alloc] initWithFormat:@"%p",self];
    name_dict[p] = name;
}

- (NSString *)name {
    NSString *p = [[NSString alloc] initWithFormat:@"%p",self];
    return name_dict[p];
}
```

#### 2.3 第3种方法:利用`runtime API`关联对象属性.

```objc
#import "TYPerson+Test2.h"
#import <objc/runtime.h>

const void * TYNameKey;

@implementation TYPerson (Test2)

- (void)setCountry:(NSString *)country {
    objc_setAssociatedObject(self, TYNameKey, country, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)country {
    return objc_getAssociatedObject(self, TYNameKey);
}

@end
```

但是上面写法仍旧有问题.

- `const void * TYNameKey` 的结果是0,相当于`NULL`.
- 那么如果再有一个属性,也是这么定义的话,会出问题.
- 如新增一个属性`no`.

```objc
#import "TYPerson+Test2.h"
#import <objc/runtime.h>

const void * TYNameKey;
const void * TYNoKey;

@implementation TYPerson (Test2)

- (void)setCountry:(NSString *)country {
    objc_setAssociatedObject(self, TYNameKey, country, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)country {
    return objc_getAssociatedObject(self, TYNameKey);
}

- (void)setNo:(int)no {
    objc_setAssociatedObject(self, TYNoKey, @(no), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (int)no {
    return [objc_getAssociatedObject(self, TYNoKey) intValue];
}

@end
```

执行方法:

```objc
TYPerson *person = [[TYPerson alloc] init];
person.country = @"China";
person.no = 1000;
NSLog(@"country = %@\n no = %d\n", person.country, person.no);
```

打印结果:

```c
country = 1000
no = 1000
```

因为上面的 key 就是 NULL, 两个 key 都是 NULL, 所以当后来传进去的 no 的值后,再取值的时候,根据 key 取,都一样的.

**改进办法,将每个 key 都赋一个独一无二的值**

```objc
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
 */
const void * TYNameKey = &TYNameKey;
const void * TYNoKey = &TYNoKey;

@implementation TYPerson (Test2)

- (void)setCountry:(NSString *)country {
    objc_setAssociatedObject(self, TYNameKey, country, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)country {
    return objc_getAssociatedObject(self, TYNameKey);
}

- (void)setNo:(int)no {
    objc_setAssociatedObject(self, TYNoKey, @(no), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (int)no {
    return [objc_getAssociatedObject(self, TYNoKey) intValue];
}
```

再看打印结果:

```c
country = China
no = 1000
```

#### 2.4 第4种方法:只传一个 char 类型的变量内存地址进去.

上面2.3的写法还有一些问题.如`const void* TYNameKey`.这种写法在外面我们是可以拿到它的.

```objc
extern const void * TYNameKey;
NSLog(@"%p",TYNameKey);
```

所以为了让这个 key 不暴露出去,我们要在前面加上一个 `static`.如下

```objc
static const void * TYNameKey = &TYNameKey;
```

因为 key 要求我们传一个地址值就可以了,所以我们也可以简化上面的写法,如`int p`.也可以,但是这里采用`char p`,一个字节,简化内存占用空间.而且也不需要给它赋值,直接传它的地址值进去`&TYNameKey`.

```objc
#import "TYPerson+Test2.h"
#import <objc/runtime.h>

static const char TYNameKey;
static const char TYNoKey;

/**
 * 简化写法, char 占1个字节,空间小
 * 而且不用给它赋值,我们只需要其内存地址而已
 */
static const char TYNameKey;
static const char TYNoKey;

@implementation TYPerson (Test2)

- (void)setCountry:(NSString *)country {
    // 传地址进来
    objc_setAssociatedObject(self, &TYNameKey, country, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)country {
    return objc_getAssociatedObject(self, &TYNameKey);
}

- (void)setNo:(int)no {
    objc_setAssociatedObject(self, &TYNoKey, @(no), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (int)no {
    return [objc_getAssociatedObject(self, &TYNoKey) intValue];
}
```

#### 2.5 第5种方法: 直接传字符串,可读性高

```objc
#import "TYPerson+Test2.h"
#import <objc/runtime.h>

/**
 * 直接传字符串,可读性高一些
 */
#define TYNameKey @"name"
#define TYNoKey @"no"

@implementation TYPerson (Test2)

- (void)setCountry:(NSString *)country {
    // TYNameKey 相当于 NSString *str = @"name"; 其实是相当于将@"name"的内存地址传进去
    objc_setAssociatedObject(self, TYNameKey, country, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)country {
    return objc_getAssociatedObject(self, TYNameKey);
}

- (void)setNo:(int)no {
    objc_setAssociatedObject(self, TYNoKey, @(no), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (int)no {
    return [objc_getAssociatedObject(self, TYNoKey) intValue];
}
```
    
#### 2.6 第6种方法: 传 SEL 地址

- 这么写有提示,而且 set 和 get 方法如果写的不同,会有警告

```objc
@implementation TYPerson (Test2)

- (void)setCountry:(NSString *)country {
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
```

