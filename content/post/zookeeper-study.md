---
title: "Zookeeper Study"
date: 2019-03-11T21:24:28+08:00
draft: false
tags: ["分布式"]
categories: ["教程"]
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
    + session允许client在server发生故障的时候转移到其他zookeeper服务器上。client在请求里带上了term值和最新完成的操作的index值，当故障发生时，新的zookeeper服务器提供服务之前需要先追赶故障前client能感知的状态（我的理解是类似raft里的log entry的同步）
    + session会超时，client必须发送心跳给server保持session持续更新，如果zookeeper服务接收不到心跳包，则认为client宕机。
    + client may keep doing its thing (e.g., network partition) but cannot perform other zookeeper ops in that session。（这里不是很理解，有可能是指发生网络分裂时，zookeeper使用只读模式，client仍可以读取数据，但是不能进行其他的操作？）

* operations on znodes

    + create(path, data, flags)
    + delete(path, version), if znode.version = version, then delete
    + exists(path, watch)
    + getData(path, watch)
    + setData(path, data, version), if znode.version = version, then update
    + getChildren(path, watch)
    + sync()

    上面的所有操作都是异步的，且针对同一个client的操作，其顺序都是先进先出（FIFO）的。sync会一直等待直到前面的操作完成传播（propagated）。

* Ordering guarantees

    + 所有的写操作都是有序的

        如果zookeeper完成了一个写的操作，其他client的后面的写操作都能知晓该写操作。如果两个client同时进行写操作，zookeeper会以某种total order完成操作

    + 针对同一个client的操作，其顺序都是先进先出

        * 同一个客户端的读操作可以观察到在此之前它的写操作的结果
        * 一个客户的读操作可以观察到部分之前的写操作，读操作可能返回延迟的老数据
        * 如果一个读操作可以观察到写操作，后续的读操作都能观察到该写操作

* Example usage 1: slow lock

```
  acquire lock:
   retry:
     r = create("app/lock", "", empheral)
     if r:
       return
     else:
       getData("app/lock", watch=True)

    watch_event:
       goto retry
      
  release lock: (voluntarily or session timeout)
    delete("app/lock")
```

* Example usage 2: "ticket" locks

```
  acquire lock:
     n = create("app/lock/request-", "", empheral|sequential)
   retry:
     requests = getChildren(l, false)
     if n is lowest znode in requests:
       return
     p = "request-%d" % n - 1
     if exists(p, watch = True)
       goto retry

    watch_event:
       goto retry
```
## reference

1. [zookeeper lecture](http://nil.csail.mit.edu/6.824/2017/notes/l-zookeeper.txt)
2. [total order](https://en.wikipedia.org/wiki/Total_order)
