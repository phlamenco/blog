---
title: "Zookeeper Study"
date: 2019-03-11T21:24:28+08:00
draft: true
---

本文用于翻译MIT分布式教学的zookeeper-case-study lec。

zookeeper由雅虎研发并转正给了apache基金会，被广泛应用与各种场景。如果一个应用需要容错的mater，那么就应该尝试使用一下zookeeper来实现。

值得一提的是zookeeper性能非常高。

按照raft论文里的实现，如果是3个节点的raft集群，那么一个query带来的操作有：

+ leader新增log entry(写磁盘)
+ leader并行发送appendEntry请求给followers
    * 每个follower新增log entry(写磁盘)
    * 每个follower返回response

这些操作包括了两次写磁盘，一次来回的网络传输。

* 如果是机械磁盘：2*10ms -> 50 msg/sec
* 如果是ssd：2*2ms + 1ms -> 200 msg/sec

而zookeeper可以达到21000 msg/sec，且支持异步调用和pipelining(根据raft的开源实现etcd的性能比对结果来看，etcd的性能在各方能都匹配上zookeeper，由此可见etcd的实现必定和论文不太一样，且优化做得很好)。

## zookeeper API overview

* replicated state machine

    一些server实现了该服务，按照全局有序的方式进行操作，如果一致性不重要，操作会有些不同。

* replicated objects称为znodes

    znodes使用路径名来组织层级关系结构，它包含应用的一些元数据：

    + 配置信息：应用涉及到哪些机器，以及哪台机器是主机器
    + 时间戳
    + 版本号

* znodes的类型有

    + 一般型
    + 临时的
    + 有序的：名字 + 序列号。如果n是新的znode，p是其父znode，那么n的序列号不会小于其他p下的有序znode

* session

    + client注册进zookeeper
    + 

## reference

1. [zookeeper lecture](http://nil.csail.mit.edu/6.824/2017/notes/l-zookeeper.txt)
