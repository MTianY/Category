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



