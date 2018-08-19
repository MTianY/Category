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

