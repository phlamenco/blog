---
title: "My First Post And A Guide To Build This Blog Site"
date: 2019-03-05T11:40:34+08:00
draft: false
tags: ["博客", "hugo", "github"]
categories: ["教程"]
---

Hello Hugo!

## 一 引

Hugo是最近看别的博客时发现的一个工具，粗略的看了下介绍，发现这个产品的设计思路非常清晰明确，新用户上手容易并且文档比较多。我尝试了下它的quickstart，3分钟内就实现了使用自己喜欢的一个主题的简单静态网页服务。

这种感觉太棒了！

## 二 搭建本站

那么本博客站点是怎么搭建的呢？这里主要是使用了两个功能：

* [hugo本地生成静态网页的能力](https://gohugo.io/getting-started/quick-start/)
* [github提供serving静态网页的能力](https://gohugo.io/hosting-and-deployment/hosting-on-github/)

另外对git的操作知识是必备的技能，特别是这里使用了[git submodule](https://www.vogella.com/tutorials/GitSubmodules/article.html)的相关知识

具备以上知识后，搭建本站就容易了，其主要步骤如下：

1. 在github上创建两个repo，一个用于保留hugo创立一个新站点时的配置文件以及内容文件，另一个用于保存hugo编译生成的静态网页以及相关文件
2. 参考上面的连接，在本地创建好一个新的站点，并编写需要发布的内容，调试以及编译
3. 分别把文件更新至两个repo

一分钟后访问https://\<YOURNAME\>.github.io即可看到你的发布内容。

## 三 主题和内容

hugo有很多漂亮的主题，我选取了这一款[hugo-theme-even](https://github.com/olOwOlo/hugo-theme-even), 在使用这个主题时注意要查看其安装文档，并对配置文件做下适配。

hugo提供渲染markdown和html的能力（好像也支持两种语法同时在同一个文件里使用），如果是简单的写作，我倾向于使用markdown，这里有一个简单的[语法介绍](https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet)。

## 四 后记

使用git submodule能很方便的同时管理自己编写的内容文件和网页静态文件，通过deploy脚本，更能一键发布用户的新增内容。但是当用户的工作环境为分布式的时候，情况稍微有点复杂。

在分布式的使用情景下，conflict不可避免，如何解决这些conflict需要更深入的git方面的知识，幸运的是网上相关解决方案也有很多，比如stackoverflow上的这个[问题的答案](https://stackoverflow.com/questions/24743769/git-resolve-conflict-using-ours-theirs-for-all-files)可以用来参考

希望本文能对大家有用，enjoy!
