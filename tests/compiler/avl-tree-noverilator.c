/*

Copyright (c) 2005-2008, Simon Howard

Permission to use, copy, modify, and/or distribute this software 
for any purpose with or without fee is hereby granted, provided 
that the above copyright notice and this permission notice appear 
in all copies. 

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL 
WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE 
AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR 
CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM 
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, 
NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN      
CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE. 

 */


#include <assert.h>
#include <stdlib.h>
#include <stdio.h>

/**
 *
 * @brief Balanced binary tree
 *
 * The AVL tree structure is a balanced binary tree which stores 
 * a collection of nodes (see @ref AVLTreeNode).  Each node has
 * a key and a value associated with it.  The nodes are sorted
 * within the tree based on the order of their keys. Modifications
 * to the tree are constructed such that the tree remains 
 * balanced at all times (there are always roughly equal numbers
 * of nodes on either side of the tree).
 *
 * Balanced binary trees have several uses.  They can be used
 * as a mapping (searching for a value based on its key), or
 * as a set of keys which is always ordered.
 *
 * To create a new AVL tree, use @ref avl_tree_new.  To destroy
 * an AVL tree, use @ref avl_tree_free.
 *
 * To insert a new key-value pair into an AVL tree, use
 * @ref avl_tree_insert.  To remove an entry from an
 * AVL tree, use @ref avl_tree_remove or @ref avl_tree_remove_node.
 *
 * To search an AVL tree, use @ref avl_tree_lookup or 
 * @ref avl_tree_lookup_node.
 *
 * Tree nodes can be queried using the 
 * @ref avl_tree_node_child,
 * @ref avl_tree_node_parent,
 * @ref avl_tree_node_key and
 * @ref avl_tree_node_value functions.
 */

/**
 * An AVL tree balanced binary tree.
 *
 * @see avl_tree_new
 */

typedef struct _AVLTree AVLTree;

/**
 * A key for an @ref AVLTree.
 */

typedef void *AVLTreeKey;

/**
 * A value stored in an @ref AVLTree.
 */

typedef void *AVLTreeValue;

/**
 * A null @ref AVLTreeValue.
 */

#define AVL_TREE_NULL ((void *) 0)

/**
 * A node in an AVL tree.
 *
 * @see avl_tree_node_left_child
 * @see avl_tree_node_right_child
 * @see avl_tree_node_parent
 * @see avl_tree_node_key 
 * @see avl_tree_node_value
 */

typedef struct _AVLTreeNode AVLTreeNode;

/**
 * An @ref AVLTreeNode can have left and right children.
 */

typedef enum {
	AVL_TREE_NODE_LEFT = 0,
	AVL_TREE_NODE_RIGHT = 1
} AVLTreeNodeSide;

/**
 * Type of function used to compare keys in an AVL tree.
 *
 * @param value1           The first key.
 * @param value2           The second key.
 * @return                 A negative number if value1 should be sorted
 *                         before value2, a positive number if value2 should 
 *                         be sorted before value1, zero if the two keys
 *                         are equal.
 */

typedef int (*AVLTreeCompareFunc)(AVLTreeValue value1, AVLTreeValue value2);

int int_compare(void *vlocation1, void *vlocation2);


/**
 * Create a new AVL tree.
 *
 * @param compare_func    Function to use when comparing keys in the tree.
 * @return                A new AVL tree, or NULL if it was not possible 
 *                        to allocate the memory.
 */

AVLTree *avl_tree_new(AVLTreeCompareFunc compare_func);

/**
 * Destroy an AVL tree.
 * 
 * @param tree            The tree to destroy.
 */

void avl_tree_free(AVLTree *tree);

/**
 * Insert a new key-value pair into an AVL tree.
 *
 * @param tree            The tree.
 * @param key             The key to insert.
 * @param value           The value to insert.
 * @return                The newly created tree node containing the
 *                        key and value, or NULL if it was not possible
 *                        to allocate the new memory.
 */

AVLTreeNode *avl_tree_insert(AVLTree *tree, AVLTreeKey key, AVLTreeValue value);

/**
 * Remove a node from a tree.
 *
 * @param tree            The tree.
 * @param node            The node to remove
 */

void avl_tree_remove_node(AVLTree *tree, AVLTreeNode *node);

/**
 * Remove an entry from a tree, specifying the key of the node to
 * remove.
 *
 * @param tree            The tree.
 * @param key             The key of the node to remove.
 * @return                Zero (false) if no node with the specified key was
 *                        found in the tree, non-zero (true) if a node with
 *                        the specified key was removed.
 */

int avl_tree_remove(AVLTree *tree, AVLTreeKey key);

/**
 * Search an AVL tree for a node with a particular key.  This uses
 * the tree as a mapping.
 *
 * @param tree            The AVL tree to search.
 * @param key             The key to search for.
 * @return                The tree node containing the given key, or NULL
 *                        if no entry with the given key is found.
 */

AVLTreeNode *avl_tree_lookup_node(AVLTree *tree, AVLTreeKey key);

/**
 * Search an AVL tree for a value corresponding to a particular key.
 * This uses the tree as a mapping.  Note that this performs 
 * identically to @ref avl_tree_lookup_node, except that the value
 * at the node is returned rather than the node itself.
 *
 * @param tree            The AVL tree to search.
 * @param key             The key to search for.
 * @return                The value associated with the given key, or 
 *                        @ref AVL_TREE_NULL if no entry with the given key is 
 *                        found.
 */

AVLTreeValue avl_tree_lookup(AVLTree *tree, AVLTreeKey key);

/**
 * Find the root node of a tree.
 *
 * @param tree            The tree.
 * @return                The root node of the tree, or NULL if the tree is 
 *                        empty.
 */

AVLTreeNode *avl_tree_root_node(AVLTree *tree);

/**
 * Retrieve the key for a given tree node.
 *
 * @param node            The tree node.
 * @return                The key to the given node.
 */

AVLTreeKey avl_tree_node_key(AVLTreeNode *node);

/** 
 * Retrieve the value at a given tree node.
 *
 * @param node            The tree node.
 * @return                The value at the given node.
 */

AVLTreeValue avl_tree_node_value(AVLTreeNode *node);

/**
 * Find the child of a given tree node.
 *
 * @param node            The tree node.
 * @param side            Which child node to get (left or right)
 * @return                The child of the tree node, or NULL if the
 *                        node has no child on the given side.
 */

AVLTreeNode *avl_tree_node_child(AVLTreeNode *node, AVLTreeNodeSide side);

/**
 * Find the parent node of a given tree node.
 *
 * @param node            The tree node.
 * @return                The parent node of the tree node, or NULL if 
 *                        this is the root node.
 */

AVLTreeNode *avl_tree_node_parent(AVLTreeNode *node);

/**
 * Find the height of a subtree.
 *
 * @param node            The root node of the subtree.
 * @return                The height of the subtree.
 */

int avl_tree_subtree_height(AVLTreeNode *node);

/**
 * Convert the keys in an AVL tree into a C array.  This allows 
 * the tree to be used as an ordered set.
 *
 * @param tree            The tree.
 * @return                A newly allocated C array containing all the keys
 *                        in the tree, in order.  The length of the array
 *                        is equal to the number of entries in the tree
 *                        (see @ref avl_tree_num_entries).
 */

AVLTreeValue *avl_tree_to_array(AVLTree *tree);

/**
 * Retrieve the number of entries in the tree.
 *
 * @param tree            The tree.
 * @return                The number of key-value pairs stored in the tree.
 */

int avl_tree_num_entries(AVLTree *tree);


/* AVL Tree (balanced binary search tree) */

struct _AVLTreeNode {
	AVLTreeNode *children[2];
	AVLTreeNode *parent;
	AVLTreeKey key;
	AVLTreeValue value;
	int height;
};

struct _AVLTree {
	AVLTreeNode *root_node;
	AVLTreeCompareFunc compare_func;
	int num_nodes;
};

AVLTree *avl_tree_new(AVLTreeCompareFunc compare_func)
{
	AVLTree *new_tree;

	new_tree = (AVLTree *) malloc(sizeof(AVLTree));

	if (new_tree == NULL) {
		return NULL; 
	}
	
	new_tree->root_node = NULL;
	new_tree->compare_func = compare_func;
	new_tree->num_nodes = 0;

	return new_tree;
}

static void avl_tree_free_subtree(AVLTree *tree, AVLTreeNode *node)
{
	if (node == NULL) {
		return;
	}

	avl_tree_free_subtree(tree, node->children[AVL_TREE_NODE_LEFT]);
	avl_tree_free_subtree(tree, node->children[AVL_TREE_NODE_RIGHT]);

	free(node);
}

void avl_tree_free(AVLTree *tree)
{
	/* Destroy all nodes */
	
	avl_tree_free_subtree(tree, tree->root_node);

	/* Free back the main tree data structure */

	free(tree);
}

int avl_tree_subtree_height(AVLTreeNode *node)
{
	if (node == NULL) {
		return 0;
	} else {
		return node->height;
	}
}

/* Update the "height" variable of a node, from the heights of its
 * children.  This does not update the height variable of any parent
 * nodes. */

static void avl_tree_update_height(AVLTreeNode *node)
{
	AVLTreeNode *left_subtree;
	AVLTreeNode *right_subtree;
	int left_height, right_height;

	left_subtree = node->children[AVL_TREE_NODE_LEFT];
	right_subtree = node->children[AVL_TREE_NODE_RIGHT];
	left_height = avl_tree_subtree_height(left_subtree);
	right_height = avl_tree_subtree_height(right_subtree);

	if (left_height > right_height) {
		node->height = left_height + 1;
	} else {
		node->height = right_height + 1;
	}
}

/* Find what side a node is relative to its parent */

static AVLTreeNodeSide avl_tree_node_parent_side(AVLTreeNode *node)
{
	if (node->parent->children[AVL_TREE_NODE_LEFT] == node) {
		return AVL_TREE_NODE_LEFT;
	} else {
		return AVL_TREE_NODE_RIGHT;
	}
}

/* Replace node1 with node2 at its parent. */

static void avl_tree_node_replace(AVLTree *tree, AVLTreeNode *node1,
                                  AVLTreeNode *node2)
{
	int side;

	/* Set the node's parent pointer. */

	if (node2 != NULL) {
		node2->parent = node1->parent;
	}

	/* The root node? */

	if (node1->parent == NULL) {
		tree->root_node = node2;
	} else {
		side = avl_tree_node_parent_side(node1);
		node1->parent->children[side] = node2;

		avl_tree_update_height(node1->parent);
	}
}

/* Rotate a section of the tree.  'node' is the node at the top
 * of the section to be rotated.  'direction' is the direction in
 * which to rotate the tree: left or right, as shown in the following
 * diagram:
 *
 * Left rotation:              Right rotation:
 *
 *      B                             D
 *     / \                           / \
 *    A   D                         B   E
 *       / \                       / \
 *      C   E                     A   C
 
 * is rotated to:              is rotated to:
 *
 *        D                           B
 *       / \                         / \
 *      B   E                       A   D
 *     / \                             / \
 *    A   C                           C   E
 */

static AVLTreeNode *avl_tree_rotate(AVLTree *tree, AVLTreeNode *node,
                                    AVLTreeNodeSide direction)
{
	AVLTreeNode *new_root;

	/* The child of this node will take its place:
	   for a left rotation, it is the right child, and vice versa. */

	new_root = node->children[1-direction];
	
	/* Make new_root the root, update parent pointers. */
	
	avl_tree_node_replace(tree, node, new_root);

	/* Rearrange pointers */

	node->children[1-direction] = new_root->children[direction];
	new_root->children[direction] = node;

	/* Update parent references */

	node->parent = new_root;

	if (node->children[1-direction] != NULL) {
		node->children[1-direction]->parent = node;
	}

	/* Update heights of the affected nodes */

	avl_tree_update_height(new_root);
	avl_tree_update_height(node);

	return new_root;
}


/* Balance a particular tree node.
 *
 * Returns the root node of the new subtree which is replacing the
 * old one. */

static AVLTreeNode *avl_tree_node_balance(AVLTree *tree, AVLTreeNode *node)
{
	AVLTreeNode *left_subtree;
	AVLTreeNode *right_subtree;
	AVLTreeNode *child;
	int diff;

	left_subtree = node->children[AVL_TREE_NODE_LEFT];
	right_subtree = node->children[AVL_TREE_NODE_RIGHT];

	/* Check the heights of the child trees.  If there is an unbalance
	 * (difference between left and right > 2), then rotate nodes
	 * around to fix it */

	diff = avl_tree_subtree_height(right_subtree)
	     - avl_tree_subtree_height(left_subtree);

	if (diff >= 2) {
		
		/* Biased toward the right side too much. */

		child = right_subtree;

		if (avl_tree_subtree_height(child->children[AVL_TREE_NODE_RIGHT])
		  < avl_tree_subtree_height(child->children[AVL_TREE_NODE_LEFT])) {

			/* If the right child is biased toward the left
			 * side, it must be rotated right first (double
			 * rotation) */

			avl_tree_rotate(tree, right_subtree,
			                AVL_TREE_NODE_RIGHT);
		}

		/* Perform a left rotation.  After this, the right child will
		 * take the place of this node.  Update the node pointer. */

		node = avl_tree_rotate(tree, node, AVL_TREE_NODE_LEFT);

	} else if (diff <= -2) {

		/* Biased toward the left side too much. */

		child = node->children[AVL_TREE_NODE_LEFT];

		if (avl_tree_subtree_height(child->children[AVL_TREE_NODE_LEFT])
		  < avl_tree_subtree_height(child->children[AVL_TREE_NODE_RIGHT])) {

			/* If the left child is biased toward the right
			 * side, it must be rotated right left (double
			 * rotation) */

			avl_tree_rotate(tree, left_subtree,
			                AVL_TREE_NODE_LEFT);
		}

		/* Perform a right rotation.  After this, the left child will
		 * take the place of this node.  Update the node pointer. */

		node = avl_tree_rotate(tree, node, AVL_TREE_NODE_RIGHT);
	}

	/* Update the height of this node */

	avl_tree_update_height(node);

	return node;
}

/* Walk up the tree from the given node, performing any needed rotations */

static void avl_tree_balance_to_root(AVLTree *tree, AVLTreeNode *node)
{
	AVLTreeNode *rover;

	rover = node;

	while (rover != NULL) {

		/* Balance this node if necessary */

		rover = avl_tree_node_balance(tree, rover);

		/* Go to this node's parent */

		rover = rover->parent;
	}
}

AVLTreeNode *avl_tree_insert(AVLTree *tree, AVLTreeKey key, AVLTreeValue value)
{
	AVLTreeNode **rover;
	AVLTreeNode *new_node;
	AVLTreeNode *previous_node;

	/* Walk down the tree until we reach a NULL pointer */

	rover = &tree->root_node;
	previous_node = NULL;

	while (*rover != NULL) {
		previous_node = *rover;
		if (tree->compare_func(key, (*rover)->key) < 0) {
			rover = &((*rover)->children[AVL_TREE_NODE_LEFT]);
		} else {
			rover = &((*rover)->children[AVL_TREE_NODE_RIGHT]);
		}
	}

	/* Create a new node.  Use the last node visited as the parent link. */

	new_node = (AVLTreeNode *) malloc(sizeof(AVLTreeNode));

	if (new_node == NULL) {
		return NULL;
	}
	
	new_node->children[AVL_TREE_NODE_LEFT] = NULL;
	new_node->children[AVL_TREE_NODE_RIGHT] = NULL;
	new_node->parent = previous_node;
	new_node->key = key;
	new_node->value = value;
	new_node->height = 1;

	/* Insert at the NULL pointer that was reached */

	*rover = new_node;

	/* Rebalance the tree, starting from the previous node. */

	avl_tree_balance_to_root(tree, previous_node);

	/* Keep track of the number of entries */

	++tree->num_nodes;

	return new_node;
}

/* Find the nearest node to the given node, to replace it. 
 * The node returned is unlinked from the tree.
 * Returns NULL if the node has no children. */

static AVLTreeNode *avl_tree_node_get_replacement(AVLTree *tree,
                                                  AVLTreeNode *node)
{
	AVLTreeNode *left_subtree;
	AVLTreeNode *right_subtree;
	AVLTreeNode *result;
	AVLTreeNode *child;
	int left_height, right_height;
	int side;

	left_subtree = node->children[AVL_TREE_NODE_LEFT];
	right_subtree = node->children[AVL_TREE_NODE_RIGHT];

	/* No children? */

	if (left_subtree == NULL && right_subtree == NULL) {
		return NULL;
	}

	/* Pick a node from whichever subtree is taller.  This helps to
	 * keep the tree balanced. */

	left_height = avl_tree_subtree_height(left_subtree);
	right_height = avl_tree_subtree_height(right_subtree);

	if (left_height < right_height) {
		side = AVL_TREE_NODE_RIGHT;
	} else {
		side = AVL_TREE_NODE_LEFT;
	}
	
	/* Search down the tree, back towards the center. */

	result = node->children[side];

	while (result->children[1-side] != NULL) {
		result = result->children[1-side];
	}

	/* Unlink the result node, and hook in its remaining child
	 * (if it has one) to replace it. */
 
	child = result->children[side];
	avl_tree_node_replace(tree, result, child);

	/* Update the subtree height for the result node's old parent. */

	avl_tree_update_height(result->parent);

	return result;
}

/* Remove a node from a tree */

void avl_tree_remove_node(AVLTree *tree, AVLTreeNode *node)
{
	AVLTreeNode *swap_node;
	AVLTreeNode *balance_startpoint;
	int i;

	/* The node to be removed must be swapped with an "adjacent"
	 * node, ie. one which has the closest key to this one. Find
	 * a node to swap with. */

	swap_node = avl_tree_node_get_replacement(tree, node);

	if (swap_node == NULL) {

		/* This is a leaf node and has no children, therefore
		 * it can be immediately removed. */

		/* Unlink this node from its parent. */

		avl_tree_node_replace(tree, node, NULL);

		/* Start rebalancing from the parent of the original node */

		balance_startpoint = node->parent;

	} else {
		/* We will start rebalancing from the old parent of the
		 * swap node.  Sometimes, the old parent is the node we
		 * are removing, in which case we must start rebalancing
		 * from the swap node. */

		if (swap_node->parent == node) {
			balance_startpoint = swap_node;
		} else {
			balance_startpoint = swap_node->parent;
		}

		/* Copy references in the node into the swap node */

		for (i=0; i<2; ++i) {
			swap_node->children[i] = node->children[i];

			if (swap_node->children[i] != NULL) {
				swap_node->children[i]->parent = swap_node;
			}
		}

		swap_node->height = node->height;

		/* Link the parent's reference to this node */

		avl_tree_node_replace(tree, node, swap_node);
	}

	/* Destroy the node */

	free(node);

	/* Keep track of the number of nodes */

	--tree->num_nodes;

	/* Rebalance the tree */

	avl_tree_balance_to_root(tree, balance_startpoint);
}

/* Remove a node by key */

int avl_tree_remove(AVLTree *tree, AVLTreeKey key)
{
	AVLTreeNode *node;

	/* Find the node to remove */

	node = avl_tree_lookup_node(tree, key);

	if (node == NULL) {
		/* Not found in tree */
		
		return 0;
	}

	/* Remove the node */

	avl_tree_remove_node(tree, node);

	return 1;
}

AVLTreeNode *avl_tree_lookup_node(AVLTree *tree, AVLTreeKey key)
{
	AVLTreeNode *node;
	int diff;
	
	/* Search down the tree and attempt to find the node which 
	 * has the specified key */

	node = tree->root_node;

	while (node != NULL) {
		
		diff = tree->compare_func(key, node->key);

		if (diff == 0) {

			/* Keys are equal: return this node */
			
			return node;
			
		} else if (diff < 0) {
			node = node->children[AVL_TREE_NODE_LEFT];
		} else {
			node = node->children[AVL_TREE_NODE_RIGHT];
		}
	}

	/* Not found */

	return NULL;
}

AVLTreeValue avl_tree_lookup(AVLTree *tree, AVLTreeKey key)
{
	AVLTreeNode *node;

	/* Find the node */

	node = avl_tree_lookup_node(tree, key);

	if (node == NULL) {
		return AVL_TREE_NULL;
	} else {
		return node->value;
	}
}

AVLTreeNode *avl_tree_root_node(AVLTree *tree)
{
	return tree->root_node;
}

AVLTreeKey avl_tree_node_key(AVLTreeNode *node)
{
	return node->key;
}

AVLTreeValue avl_tree_node_value(AVLTreeNode *node)
{
	return node->value;
}

AVLTreeNode *avl_tree_node_child(AVLTreeNode *node, AVLTreeNodeSide side)
{
	if (side == AVL_TREE_NODE_LEFT || side == AVL_TREE_NODE_RIGHT) {
		return node->children[side];
	} else {
		return NULL;
	}
}

AVLTreeNode *avl_tree_node_parent(AVLTreeNode *node)
{
	return node->parent;
}

int avl_tree_num_entries(AVLTree *tree)
{
	return tree->num_nodes;
}

static void avl_tree_to_array_add_subtree(AVLTreeNode *subtree, 
                                         AVLTreeValue *array, 
                                         int *index)
{
	if (subtree == NULL) {
		return;
	}
		
	/* Add left subtree first */

	avl_tree_to_array_add_subtree(subtree->children[AVL_TREE_NODE_LEFT],
	                              array, index);
	
	/* Add this node */
	
	array[*index] = subtree->key;
	++*index;

	/* Finally add right subtree */

	avl_tree_to_array_add_subtree(subtree->children[AVL_TREE_NODE_RIGHT],
	                              array, index);
}

AVLTreeValue *avl_tree_to_array(AVLTree *tree)
{
	AVLTreeValue *array;
	int index;

	/* Allocate the array */
	
	array = malloc(sizeof(AVLTreeValue) * tree->num_nodes);

	if (array == NULL) {
		return NULL;
	}
	
	index = 0;

	/* Add all keys */
	
	avl_tree_to_array_add_subtree(tree->root_node, array, &index);

	return array;
}

#define NUM_TEST_VALUES 128

int test_array[NUM_TEST_VALUES];

int find_subtree_height(AVLTreeNode *node)
{
	AVLTreeNode *left_subtree;
	AVLTreeNode *right_subtree;
	int left_height, right_height;

	if (node == NULL) {
		return 0;
	}

	left_subtree = avl_tree_node_child(node, AVL_TREE_NODE_LEFT);
	right_subtree = avl_tree_node_child(node, AVL_TREE_NODE_RIGHT);
	left_height = find_subtree_height(left_subtree);
	right_height = find_subtree_height(right_subtree);

	if (left_height > right_height) {
		return left_height + 1;
	} else {
		return right_height + 1;
	}
}

/* Validates a subtree, returning its height */

int counter;

int validate_subtree(AVLTreeNode *node)
{
	AVLTreeNode *left_node, *right_node;
	int left_height, right_height;
	int *key;

	if (node == NULL) {
		return 0;
	}

	left_node = avl_tree_node_child(node, AVL_TREE_NODE_LEFT);
	right_node = avl_tree_node_child(node, AVL_TREE_NODE_RIGHT);

	/* Check the parent references of the children */

	if (left_node != NULL) {
		assert(avl_tree_node_parent(left_node) == node);
	}
	if (right_node != NULL) {
		assert(avl_tree_node_parent(right_node) == node);
	}

	/* Recursively validate the left and right subtrees,
	 * obtaining the height at the same time. */

	left_height = validate_subtree(left_node);

	/* Check that the keys are in the correct order */

	key = (int *) avl_tree_node_key(node);

	assert(*key > counter);
	counter = *key;
	
	right_height = validate_subtree(right_node);

	/* Check that the returned height value matches the 
	 * result of avl_tree_subtree_height(). */

	assert(avl_tree_subtree_height(left_node) == left_height);
	assert(avl_tree_subtree_height(right_node) == right_height);

	/* Check this node is balanced */

	assert(left_height - right_height < 2 && right_height - left_height < 2);

	/* Calculate the height of this node */

	if (left_height > right_height) {
		return left_height + 1;
	} else {
		return right_height + 1;
	}
}

void validate_tree(AVLTree *tree)
{
	AVLTreeNode *root_node;
	int height;

	root_node = avl_tree_root_node(tree);

	if (root_node != NULL) {
		height = find_subtree_height(root_node);
		assert(avl_tree_subtree_height(root_node) == height);
	}

	counter = -1;
	validate_subtree(root_node);
}

AVLTree *create_tree(void)
{
	AVLTree *tree;
	int i;

	/* Create a tree and fill with nodes */

	tree = avl_tree_new((AVLTreeCompareFunc) int_compare);

	for (i=0; i<NUM_TEST_VALUES; ++i) {
		test_array[i] = i;
		avl_tree_insert(tree, &test_array[i], &test_array[i]);
	}
	
	return tree;
}

void test_avl_tree_insert_lookup(void)
{
	AVLTree *tree;
	AVLTreeNode *node;
	int i;
	int *value;

	/* Create a tree containing some values. Validate the 
	 * tree is consistent at all stages. */

	tree = avl_tree_new((AVLTreeCompareFunc) int_compare);

	for (i=0; i<NUM_TEST_VALUES; ++i) {
		test_array[i] = i;
		avl_tree_insert(tree, &test_array[i], &test_array[i]);

		assert(avl_tree_num_entries(tree) == i + 1);
		validate_tree(tree);
	}

	assert(avl_tree_root_node(tree) != NULL);

	/* Check that all values can be read back again */

	for (i=0; i<NUM_TEST_VALUES; ++i) {
		node = avl_tree_lookup_node(tree, &i);
		assert(node != NULL);
		value = avl_tree_node_key(node);
		assert(*value == i);
		value = avl_tree_node_value(node);
		assert(*value == i);
	}

	/* Check that invalid nodes are not found */

	i = -1;
	assert(avl_tree_lookup_node(tree, &i) == NULL);
	i = NUM_TEST_VALUES + 100;
	assert(avl_tree_lookup_node(tree, &i) == NULL);

	avl_tree_free(tree);
}

void test_avl_tree_child(void)
{
	AVLTree *tree;
	AVLTreeNode *root;
	AVLTreeNode *left;
	AVLTreeNode *right;
	int values[] = { 1, 2, 3 };
	int *p;
	int i;

	/* Create a tree containing some values. Validate the 
	 * tree is consistent at all stages. */

	tree = avl_tree_new((AVLTreeCompareFunc) int_compare);

	for (i=0; i<3; ++i) {
		avl_tree_insert(tree, &values[i], &values[i]);
	}

	/* Check the tree */

	root = avl_tree_root_node(tree);
	p = avl_tree_node_value(root);
	assert(*p == 2);

	left = avl_tree_node_child(root, AVL_TREE_NODE_LEFT);
	p = avl_tree_node_value(left);
	assert(*p == 1);

	right = avl_tree_node_child(root, AVL_TREE_NODE_RIGHT);
	p = avl_tree_node_value(right);
	assert(*p == 3);

	/* Check invalid values */

	assert(avl_tree_node_child(root, -1) == NULL);
	assert(avl_tree_node_child(root, 10000) == NULL);
	assert(avl_tree_node_child(root, 2) == NULL);
	assert(avl_tree_node_child(root, -100000) == NULL);

	avl_tree_free(tree);
}

void test_avl_tree_free(void)
{
	AVLTree *tree;
	
	/* Try freeing an empty tree */

	tree = avl_tree_new((AVLTreeCompareFunc) int_compare);
	avl_tree_free(tree);

	/* Create a big tree and free it */

	tree = create_tree();
	avl_tree_free(tree);
}

void test_avl_tree_lookup(void)
{
	AVLTree *tree;
	int i;
	int *value;

	/* Create a tree and look up all values */

	tree = create_tree();

	for (i=0; i<NUM_TEST_VALUES; ++i) {
		value = avl_tree_lookup(tree, &i);

		assert(value != NULL);
		assert(*value == i);
	}

	/* Test invalid values */

	i = -1;
	assert(avl_tree_lookup(tree, &i) == NULL);
	i = NUM_TEST_VALUES + 1;
	assert(avl_tree_lookup(tree, &i) == NULL);
	i = 8724897;
	assert(avl_tree_lookup(tree, &i) == NULL);

	avl_tree_free(tree);
}

void test_avl_tree_remove(void)
{
	AVLTree *tree;
	int i;
	int x, y, z;
	int value;
	int expected_entries;

	tree = create_tree();

	/* Try removing invalid entries */

	i = NUM_TEST_VALUES + 100;
	assert(avl_tree_remove(tree, &i) == 0);
	i = -1;
	assert(avl_tree_remove(tree, &i) == 0);

	/* Delete the nodes from the tree */

	expected_entries = NUM_TEST_VALUES;

	/* This looping arrangement causes nodes to be removed in a 
	 * randomish fashion from all over the tree. */

	for (x=0; x<4; ++x) {
		for (y=0; y<4; ++y) {
			for (z=0; z<8; ++z) {
				value = z * 16 + (3 - y) * 4 + x;
				assert(avl_tree_remove(tree, &value) != 0);
				validate_tree(tree);
				expected_entries -= 1;
				assert(avl_tree_num_entries(tree)
				       == expected_entries);
			}
		}
	}

	/* All entries removed, should be empty now */

	assert(avl_tree_root_node(tree) == NULL);

	avl_tree_free(tree);
}

void test_avl_tree_to_array(void)
{
	AVLTree *tree;
	int entries[] = { 89, 23, 42, 4, 16, 15, 8, 99, 50, 30 };
	int sorted[]  = { 4, 8, 15, 16, 23, 30, 42, 50, 89, 99 };
	int num_entries = sizeof(entries) / sizeof(int);
	int i;
	int **array;

	/* Add all entries to the tree */
	
	tree = avl_tree_new((AVLTreeCompareFunc) int_compare);

	for (i=0; i<num_entries; ++i) {
		avl_tree_insert(tree, &entries[i], NULL);
	}
	
	assert(avl_tree_num_entries(tree) == num_entries);

	/* Convert to an array and check the contents */

	array = (int **) avl_tree_to_array(tree);

	for (i=0; i<num_entries; ++i) {
		assert(*array[i] == sorted[i]);
	}

	free(array);
}

	
int int_compare(void *vlocation1, void *vlocation2)
{
	int *location1;
	int *location2;

	location1 = (int *) vlocation1;
	location2 = (int *) vlocation2;

	if (*location1 < *location2) {
		return -1;
	} else if (*location1 > *location2) {
		return 1;
	} else {
		return 0;
	}
}
	
int main(int argc, char *argv[])
{
	test_avl_tree_free();
	test_avl_tree_child();
	test_avl_tree_insert_lookup();
	test_avl_tree_lookup();
	test_avl_tree_remove();
	test_avl_tree_to_array();

	printf("PASS\n");	// CHECK: PASS
	return 0;
}
