---
title: "Raft Extented Read Note"
date: 2019-03-08T16:01:02+08:00
draft: true
tags: ["raft", "paper", "read-note"]
categories: ["paper"]
---

本文用于记录阅读（raft-extented paper）时的一些想法和笔记。

## 1. 分布式系统一致性

在谈分布式一致性算法的时候，通常是在Replicated state machines这种语境下进行。

***[Q]什么是Replicated state machines?***

Replicated state machines用于解决分布式系统的容灾问题。其架构如下：

{{< rawhtml >}}<img src="/post/img/replicated_state_machine.png" alt="replicated state machine" width="340"/>{{< /rawhtml >}}

每一个server都包含log，这个log称为replicated log。分布式算法就是要解决replicated log一致性的问题。

对于一个实际的一致性算法，它具有以下特点：

1. 保证安全（under all non-Byzantine conditions）

    这里的Byzantine conditions大概是指拜占庭将军问题（区块链作为一个global分布式系统，也要解决类似的问题）。那么non-Byzantine conditions就可以理解为非拜占庭将军问题的其它问题（ including network delays, partitions, and packet loss, duplication, and reordering，都是实际工程系统，包括非分布式系统，里经常会遇到的问题）。

2. 只要系统内绝大部分server或者，可以相互并且和客户端通信，那么系统应该完全可用

    所以宕机小部分server对分布式系统的可用性没有影响（理论上，实际上延迟和吞吐肯定是有影响的），Thus, a typical cluster of five servers can tolerate the failure of any two servers. Servers are assumed to fail by stopping; they may later recover from state on stable storage and rejoin the cluster

3. 一致性的保证不建立在时钟的基础上

4. 对于一个命令，只要系统内大部分server同意了就完成了，这样反应慢的server不影响系统整体性能

## 2. raft一致性算法

raft把一致性的问题划分成三个子问题：

* Leader election，raft算法的操作基本都依靠leader，因此解决选主这个问题非常重要
* Log replication，如何设计复制log，并保证log一致，从而解决replicated log的一致性
* Safety 如何设计算法保证raft系统里能确定的结论，这些结论包括：
    + 选主安全
        
        at most one leader can be elected in a given term
    + Leader 对log只做增的操作
    
        a leader never overwrites or deletes entries in its log; it only appends new entries
    + Log一致
    
        if two logs contain an entry with the same index and term, then the logs are identical in all entries up through the given index
    + Leader完整性（主要是指log的内容）
        
        if a log entry is committed in a given term, then that entry will be present in the logs of the leaders for all higher-numbered terms
    + 状态机安全
    
        if a server has applied a log entry at a given index to its state machine, no other server will ever apply a different log entry for the same index
    
    这些结论为raft一致性算法的正确性证明提供了基础。因此raft设计了算法来获取这些结论。

***[Q]什么是term，index和log entry?***

raft系统里，每个server都有自己的角色和状态，这种角色和状态的转移图如下：

{{< rawhtml >}}<img src="/post/img/server_state.png" alt="server_state" width="340"/>{{< /rawhtml >}}

server的角色和状态在一定条件下会发生变化，比如系统启动要选主，或者leader宕机等等，甚至raft算法自身让server的角色处于不停的变动之中。

raft为了描述这种带有时序属性的变动，设计了一种逻辑时钟的概念。

## reference
1. [raft-extended](http://nil.csail.mit.edu/6.824/2017/papers/raft-extended.pdf)
2. [raft animation](http://thesecretlivesofdata.com/raft/)