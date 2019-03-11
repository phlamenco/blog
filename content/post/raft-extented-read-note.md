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

***[Q]什么是term?***

raft系统里，每个server都有自己的角色和状态，这种角色和状态的转移图如下：

{{< rawhtml >}}<img src="/post/img/server_state.png" alt="server_state" width="340"/>{{< /rawhtml >}}

server的角色和状态在一定条件下会发生变化，比如系统启动要选主，或者leader宕机等等，甚至raft算法自身让server的角色处于不停的变动之中。

raft为了描述这种带有时序属性的变动，设计了一种逻辑时钟的概念，如下图：

{{< rawhtml >}}<img src="/post/img/raft_term.png" alt="raft_term" width="340"/>{{< /rawhtml >}}

raft把时间分成term，由连续的整形来表示，term主要用来同步servers之间的时序，比如一个server接收到一个比自己当前term值要大的term时，自己需要更新term为更大的那个值，如果一个candidate或者leader发现了其他更大的term值，那么它不仅仅要更新term值，而且自身需要切换到称为follower的状态。反过来，如果server接收到一个带有比自己小的term的query，则应该拒绝该query。

所以每次选主时，都会产生一个最大的term出来。

***[Q]什么是log entry和log index?***

log entry是log里的一条记录，如下所示：

{{< rawhtml >}}<img src="/post/img/log_entry.png" alt="log_entry" width="340"/>{{< /rawhtml >}}

log index就是某条log entry的位置。

### 2.1 leader election

raft使用一种心跳的方式来出发选主的进行。每一个server都可能实现角色的变换，通过心跳，server之间能够知道当前集群的状态，比如是否已经有leader选出来，或者自己是否可以称为candidate来竞选leader，以及完成投票。

但是，如果只有心跳，有可能会导致总有两个candidate获得的票数一样多，从而集群无法确定leader。raft把心跳和随机选主超时机制（ randomized election timeouts）相结合，一定程度上解决了这个问题（reference 2有更直观上的认识）。为什么说一定程度？是因为raft的这种做法也不能完全避免前面说的那种情况的发生，不过确实降低了该情况发生的概率，同时在工程上这种方式实现简单，易于理解，兼顾了理论算法的设计和理解以及工程实现。

### 2.2 log replication

raft中，所有的log的变动都必须由leader来主导，这样设计也是为了让算法显得更容易理解。leader首先创建一个log entry，然后发送到各个其他server上，在大部分server成功复制了log后，leader便commit这个entry。commit的意思是把log entry应用于state machine计算出结果出来。这个过程是通过一个rpc接口来完成。log的commit是严格按照log index的顺序来的，如果某个index的log entry已经commit了，那么该leader上，在它之前的log entry也一定是commit过的。如果在log entry被commit之后有一部分server宕机了或者网络出现故障了，leader仍然会不停地发送rpc请求，要求这些server复制log。

+ 如果在复制log还没有commit之前，leader宕机了的话，在新的leader选举后这些已经复制的log有可能会被覆盖，在客户端看来这次query返回失败。这种覆盖操作也需要leader来主导进行，比如新的leader产生后，会不停地发送带了nextIndex字段的rpc给其他server，其他server检查自己当前的nextIndex是否和接收到的相符，如果相符，那表示状态是同步的，如果不相符则返回失败，leader便会继续发送nextIndex-1的字段，如此不断重复直到找到相同的nextIndex值，然后以该nextIndex为基准进行正常的log replicate操作，如此重新同步整个集群。
+ 如果在不同步的情况下，相差的log数据量太大，假如仍然使用上面的方式来同步log，可能会需要很长时间，这最终会影响到整体的性能。raft使用log compaction的方式来解决这个问题，同时log compaction也解决了log越来越多可能会导致的存储容量的问题。

### 2.3 log compaction

raft使用快照的方式来实现log compaction。raft考虑了两种使用快照的方式：

+ leader生成快照并分发给各个其他server
+ server各自独立生成快照，leader只对那些快照相差太多内容的server进行分发同步

raft选择第二种，因为第一种不仅实现起来比较困难而且比较浪费带宽资源。在第二种中，每个server把自己状态机当前的状态写入snapshot，另外还写入了一些元数据，比如last included index和last included term。last included index是该server当前最新commit的log entry的index值，last included term是last included index的term值，用于同步时序和log。leader使用一个新的rpc接口把快照同步到那些过慢或者新加入系统的server上，此时，这些server需要决定如何处理自己已有的log entry。如果从leader收到的快照比自己的新（比如通过last included index和last included term在和自己的current index和current term对比），那么废弃自己的所有log entry，完全使用新快照来替换。反过来，如果收到的快照更老（可能是重复发送的快照或者有错误发生导致），那么废弃掉新快照包含的log entry，保留比新快照更新的log entry。

log compaction违反了之前说过的 

> 所有的log的变动都必须由leader来主导

这一原则。但是这里这样做是可以的，因为在生成快照之前，一致性已经达成，它并不影响一致性，不会导致冲突，同时数据仍然是由leader传输到follower。

## reference
1. [raft-extended](http://nil.csail.mit.edu/6.824/2017/papers/raft-extended.pdf)
2. [raft animation](http://thesecretlivesofdata.com/raft/)