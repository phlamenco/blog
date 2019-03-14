---
title: "Kvstore with raft"
date: 2019-03-14T09:27:43+08:00
draft: false
tags: ["kvstore", "分布式"]
categories: ["idea"]
---

本文记录如何使用raft来构建一个分布式的kvstore。

一个简单而又典型的kvstore会提供了下面的接口

+ Get
+ Put
+ Delete

## 单机的简单实现

从最简单的开始，我们可以使用一个map来作为单机kvstore的底层存储结构来实现上面的接口，simple，但不是分布式的。

## 分布式的简单实现

结合raft算法和上面的使用map作为底层存储方式的kvstore可以来实现一个分布式的kvstore。将Get/Put/Delete指令和数据存放于log entry，raft保证commited的log entry已经按照顺序保存在集群上，利用state machine来执行这些指令来更新map里的数据，这样把数据物理上的存储操作和分布式一致性的保证分离开。这里针对map的操作是deterministic的，因此能够保证通过log entry的一致得到最终kv数据的一致。

这样就实现了一个简单的分布式kvstore，只要集群里超过一半的机器可用，则整个集群可用。

## 分片的分布式实现

上一步简单实现的系统其性能是有限的，包括存储容量（我们使用map来存储数据，内存决定了能够支持的数据量），服务吞吐量（由于所有client需要和leader通信，吞吐量有单台server以及raft背后的一致性算法决定）。为了解决这两个问题，可以采用分片的方式来解决。比如上一步实现的系统我们部署了W1,W2,W3,...,Wn，每个Wi（0<i≤n）都是一个上面实现的简单的kvstore集群。使得这些集群共同承担所有的client的流量，这样就实现了容量和吞吐上的线性可扩展。

为了支持流量的分散，需要一个Master来决定client的流量应该访问哪个Wi集群。这里Master对key做Hash并对n取余来决定流量分发。这样一个能线性扩容的分布式kvstore就完成了。但是在这样的系统中Master成为了单点，一旦Master宕机，整个kvstore就不可用了。这里可以再次使用raft来避免Master成为单点。

设计一种configuration，比如：

```
 取余的数值  集群
        0 -> w1
        1 -> w2
        2 -> w3
        3 -> w4
        4 -> w1
        5 -> w2
```

把这个configuration作为一个log entry commit到Master的raft集群，这样就能保证Master的分片路由能力具有分布式的容灾能力。现在一个kvstore请求的流程是client先根据key请求Master，Master返回某个W集群的ip，client获取ip后访问该W集群进行kv操作。

至此，一个高可用的，可线性扩展的分布式kvstore就已经实现了。但是在实际的使用中，因client流量的特点，经常会出现W集群负载不均衡的问题，当Master路由到W集群的流量出现不均衡时，负载高的W集群性能会下降，这样就会影响到系统整体的性能。这个时候kvstore必须支持新增或删减W集群的功能来调整负载改善情况。

## 可修改配置的分片分布式实现

最简单的方式是通过主备来实现配置的更新。不过这里尝试一下另外的实现方式。

为了实现可以修改配置的功能，集群需要感知配置是否发生变化，我们为configuration分配一个全局的编号confIndex，从1开始，配置发生变化则加1，使用这种方式来表示configuration的变更，当配置发生变更时，流量路由的映射关系也会发生变化，原来“取余数值”对应的“集群”可能换成了另外一个“集群”，那么原来集群的数据就要迁移到新集群上，老集群上被迁移的数据则可以删掉，为了完成这个过程，W集群需要有办法能够知道配置需要更新，另外W集群之间也需要实现通信的功能来完成数据迁移。

+ ***[Q]如何让W集群感知配置需要更新？***
    
    Master的leader定时往W集群发送带有confIndex的心跳包，W集群将confIndex作为一项log entry存入集群中，当更大的confIndex到来时，W集群往Master发送获取与自己相关的配置变动，比如配置变动如下：

    ```
    取余的数值  集群                    取余的数值  集群
            0 -> w1                            0 -> w1
            1 -> w2                            1 -> w2
            2 -> w3            ->              2 -> w3
            3 -> w4                            3 -> w4
            4 -> w1                            4 -> w4
            5 -> w2                            5 -> w2
    ```

    hash取余后的数据(H(4))访问流量路由由w1切换为了w4，w1集群通过Master获知自己需要删除H(4)的数据，而w4通过Master获知自己需要增加H(4)的数据，其他集群无变动，直接将新的confIndex commit到自己集群中并返回更新成功的消息给Master

+ ***[Q]W集群如何迁移数据***

    w4知道自己需要新增H(4)的数据且H(4)的数据存于w1，w4向w1发起rpc请求，传输数据。这个过程中，w1和w4对不需要迁移的数据仍然提供服务，对于需要迁移的数据拒绝服务。迁移完成后w1删除H(4)数据，w1和w4各自commit新的confIndex并返回成功消息。

+ ***[Q]Master如何知道迁移已经完成？***

    当Master接收到n个不同W返回的带有新的confIndex的成功更新完配置的消息后，Master可以确认迁移已经完成了。

+ ***[Q]Master如何避免在更新配置过程中宕机导致的问题***

    Master使用两阶段commit的方式，第一阶段，当新配置到来时，直接commit新的配置，并使用新的confIndex发送心跳, 等到知道数据迁移已经全部完成后，第二阶段完成新的confIndex的commit。

***本文讲述的实现过程均属于头脑风暴，有些corner case肯定还没有考虑到，谨慎参考。***

## reference
1. [raft-extended-read-note](/post/raft-extented-read-note/)