---
title: "multiply_algorithm"
date: 2019-04-15T09:36:04+08:00
draft: false
tags: ["algorithm"]
---

乘法是学习数学计算的基础，从小我们就从课本上学到了一种通用的乘法算法。但是那种乘法的复杂度太高。

下图是传统乘法和Karatsuba’s method乘法的例子：

{{< rawhtml >}}<img src="/post/img/KratsubaMethod.jpg" alt="AVL tree example" width="340"/>{{< /rawhtml >}}

例子中的算法的时间复杂度就从n^2减少到了2n。

# Reference
1. [Integer multiplication in time O(n log n)](https://hal.archives-ouvertes.fr/hal-02070778/document)
