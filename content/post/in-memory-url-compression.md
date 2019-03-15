---
title: "In Memory Url Compression"
date: 2019-03-15T17:13:10+08:00
draft: true
tags: ["compression"]
categories: ["paper"]
---

今天看到一篇论文，发明了一种基于url特点的in-memory的压缩方式，取得了50%的压缩效率同时实现了高效率的读取方法。

## 压缩原理

举一个例子，比如如下urls：

```

1. http://www.sun.com/
2. http://www.sgi.com/
3. http://www.sun.com/news/
4. http://www.sun.com/news/archive/

```

可以看到urls至少具有http://这一共同的部分，如果要减少总的存储量，这部分是肯定需要想办法压缩掉的，另外可以看到一部分url是由另外一部分url衍生而来（在原来的基础上新增目录之类），这里也可以看成是这两部分url具有共同的部分，也是可以压缩掉。

该论文根据url的这个特点，设计了一套基于AVL树的压缩方法。

论文设计AVL树的节点结构如下：

{{< rawhtml >}}<img src="/post/img/AVL_NODE.png" alt="AVL node structure" width="340"/>{{< /rawhtml >}}

+ RefId指向他的父节点
+ CommonPrefix是它和root到其父节点路径上所有url的共同url部分的长度
+ diffUrl是除了CommonPrefix之外的url的其它不同部分
+ Lchild和Rchild分别指向自己的左右子节点

对应上面例子中的urls，可以构建如下的AVL树：

{{< rawhtml >}}<img src="/post/img/AVL_tree.png" alt="AVL tree example" width="340"/>{{< /rawhtml >}}

每一个Url指定一个refId，从0开始逐渐递增。

构建的AVL数的root节点的RefId不一定会是0，不过diffUrl一定是全部的Url。新节点插入时使用diffUrl做字符串比较，以此找到最大的CommonPrefix的节点。新node的插入导致的AVL树的调整使得root节点发生转变时，root节点和替换它的子节点的内容会发生变化。

从这样一个AVL数获取一个URL也很容易，一次从ROOT节点遍历到叶子节点，把diffUrl拼接起来就获取了完整的URL。

## 实现

## reference

1. [AVL树](https://baike.baidu.com/item/AVL%E6%A0%91/10986648?fr=aladdin)
2. [AVL的c实现](https://github.com/willemt/array-avl-tree)