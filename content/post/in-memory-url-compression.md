---
title: "In Memory Url Compression"
date: 2019-03-15T17:13:10+08:00
draft: false
tags: ["compression", "AVL树"]
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

从这样一个AVL树获取一个URL也很容易，依次从ROOT节点遍历到叶子节点，把diffUrl拼接起来就获取了完整的URL。

## AVL树

AVL是一种平衡二叉树，读取性能很好，最坏时间复杂度为O(logN)，下面是其C语言的一种递归实现：

```
// C program to insert a node in AVL tree 
#include<stdio.h> 
#include<stdlib.h> 

// An AVL tree node 
struct Node 
{ 
	int key; 
	struct Node *left; 
	struct Node *right; 
	int height; 
}; 

// A utility function to get maximum of two integers 
int max(int a, int b); 

// A utility function to get the height of the tree 
int height(struct Node *N) 
{ 
	if (N == NULL) 
		return 0; 
	return N->height; 
} 

// A utility function to get maximum of two integers 
int max(int a, int b) 
{ 
	return (a > b)? a : b; 
} 

/* Helper function that allocates a new node with the given key and 
	NULL left and right pointers. */
struct Node* newNode(int key) 
{ 
	struct Node* node = (struct Node*) 
						malloc(sizeof(struct Node)); 
	node->key = key; 
	node->left = NULL; 
	node->right = NULL; 
	node->height = 1; // new node is initially added at leaf 
	return(node); 
} 

// A utility function to right rotate subtree rooted with y 
// See the diagram given above. 
struct Node *rightRotate(struct Node *y) 
{ 
	struct Node *x = y->left; 
	struct Node *T2 = x->right; 

	// Perform rotation 
	x->right = y; 
	y->left = T2; 

	// Update heights 
	y->height = max(height(y->left), height(y->right))+1; 
	x->height = max(height(x->left), height(x->right))+1; 

	// Return new root 
	return x; 
} 

// A utility function to left rotate subtree rooted with x 
// See the diagram given above. 
struct Node *leftRotate(struct Node *x) 
{ 
	struct Node *y = x->right; 
	struct Node *T2 = y->left; 

	// Perform rotation 
	y->left = x; 
	x->right = T2; 

	// Update heights 
	x->height = max(height(x->left), height(x->right))+1; 
	y->height = max(height(y->left), height(y->right))+1; 

	// Return new root 
	return y; 
} 

// Get Balance factor of node N 
int getBalance(struct Node *N) 
{ 
	if (N == NULL) 
		return 0; 
	return height(N->left) - height(N->right); 
} 

// Recursive function to insert a key in the subtree rooted 
// with node and returns the new root of the subtree. 
struct Node* insert(struct Node* node, int key) 
{ 
	/* 1. Perform the normal BST insertion */
	if (node == NULL) 
		return(newNode(key)); 

	if (key < node->key) 
		node->left = insert(node->left, key); 
	else if (key > node->key) 
		node->right = insert(node->right, key); 
	else // Equal keys are not allowed in BST 
		return node; 

	/* 2. Update height of this ancestor node */
	node->height = 1 + max(height(node->left), 
						height(node->right)); 

	/* 3. Get the balance factor of this ancestor 
		node to check whether this node became 
		unbalanced */
	int balance = getBalance(node); 

	// If this node becomes unbalanced, then 
	// there are 4 cases 

	// Left Left Case 
	if (balance > 1 && key < node->left->key) 
		return rightRotate(node); 

	// Right Right Case 
	if (balance < -1 && key > node->right->key) 
		return leftRotate(node); 

	// Left Right Case 
	if (balance > 1 && key > node->left->key) 
	{ 
		node->left = leftRotate(node->left); 
		return rightRotate(node); 
	} 

	// Right Left Case 
	if (balance < -1 && key < node->right->key) 
	{ 
		node->right = rightRotate(node->right); 
		return leftRotate(node); 
	} 

	/* return the (unchanged) node pointer */
	return node; 
} 

// A utility function to print preorder traversal 
// of the tree. 
// The function also prints height of every node 
void preOrder(struct Node *root) 
{ 
	if(root != NULL) 
	{ 
		printf("%d ", root->key); 
		preOrder(root->left); 
		preOrder(root->right); 
	} 
} 

/* Drier program to test above function*/
int main() 
{ 
struct Node *root = NULL; 

/* Constructing tree given in the above figure */
root = insert(root, 10); 
root = insert(root, 20); 
root = insert(root, 30); 
root = insert(root, 40); 
root = insert(root, 50); 
root = insert(root, 25); 

/* The constructed AVL Tree would be 
			30 
		/ \ 
		20 40 
		/ \	 \ 
	10 25 50 
*/

printf("Preorder traversal of the constructed AVL"
		" tree is \n"); 
preOrder(root); 

return 0; 
} 

```

## 实现

论文里使用了三个数组作为数据结构来完成压缩数据的构建。分别如下所示：

{{< rawhtml >}}<img src="/post/img/AVL_node_array.png" alt="AVL node array" width="340"/>{{< /rawhtml >}}

{{< rawhtml >}}<img src="/post/img/url_array.png" alt="compressed URL array" width="340"/>{{< /rawhtml >}}

{{< rawhtml >}}<img src="/post/img/ptr_array.png" alt="URL pointer array" width="110"/>{{< /rawhtml >}}

左上是AVL node的数组表示，该数组用于维护AVL数的结构；右上是压缩url的数组表示，该数组用于存储压缩的URL数据；左下是指针数组，用于访问右上的数组，如下图所示：

{{< rawhtml >}}<img src="/post/img/ptr_visit.png" alt="URL pointer visit" width="340"/>{{< /rawhtml >}}

结构比较清晰。

作者为什么要在这里使用三个数组来实现呢？一方面紧凑的内存结构设计能够减少不必要的内存开销（毕竟论文的目标是减少内存使用量），另一方面是希望编译器的优化能为数据的读取带来额外的好处(局部性原理，cache之类的优势)，最后AVL node的数组在完成URL的全量压缩后可以删除掉，进一步节省内存。

最后论文给出了他们的一个实现的性能测试结果：

{{< rawhtml >}}<img src="/post/img/url_access_pf.png" alt="access url performace" width="360"/>{{< /rawhtml >}}

## reference

1. [in memory url compression](https://pdfs.semanticscholar.org/9bf1/007a376705f312ba37e4ea75cc56196d0361.pdf)
2. [AVL树](https://www.geeksforgeeks.org/avl-tree-set-1-insertion/)
3. [AVL的c实现](https://github.com/willemt/array-avl-tree)