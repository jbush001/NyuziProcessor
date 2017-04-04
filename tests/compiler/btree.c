/*
 * Copyright (C) 2010 Joseph Adams <joeyadams3.14159@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

// Downloaded from https://ccodearchive.net/info/btree.html

/*
Note:  The following should work but are not well-tested yet:

btree_walk...
btree_cmp_iters
btree_insert
btree_remove
btree_lookup
*/

#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include <stdlib.h>
#include <stdio.h>

/*
 * Maximum number of items per node.
 * The maximum number of branches is BTREE_ITEM_MAX + 1.
 */
#define BTREE_ITEM_MAX 20

struct btree_node {
	struct btree_node *parent;

	/* Number of items (rather than branches). */
	unsigned char count;

	/* 0 if node is a leaf, 1 if it has leaf children, etc. */
	unsigned char depth;

	/* node->parent->branch[node->k] == this */
	unsigned char k;

	const void *item[BTREE_ITEM_MAX];

	/*
	 * Allocated to BTREE_ITEM_MAX+1 items if this is
	 * an internal node, 0 items if it is a leaf.
	 */
	struct btree_node *branch[];
};

typedef struct btree_iterator_s {
	struct btree *btree;
	struct btree_node *node;
	unsigned int k;

	/*
	 * The relationship between item and (node, k) depends on what function
	 * set it.  It is mainly for convenience.
	 */
	void *item;
} btree_iterator[1];

/*
 * Instead of a compare function, this library accepts a binary search function
 * to know how to order the items.
 */
typedef unsigned int btree_search_proto(
	const void *key,
	const void * const *base,
	unsigned int count,
	int lr,
	int *found
);
typedef btree_search_proto *btree_search_t;

btree_search_proto btree_strcmp;

/*
 * Callback used by btree_delete() and btree_walk...().
 *
 * If it returns 0, it causes btree_walk...() to stop traversing and return 0.
 * Thus, in normal circumstances, this callback should return 1.
 *
 * Callback shall not insert/remove items from the btree being traversed,
 * nor shall anything modify it during a walk.
 */
typedef int (*btree_action_t)(void *item, void *ctx);

struct btree {
	struct btree_node *root;
	size_t count; /* Total number of items in B-tree */

	btree_search_t search;
	bool multi;

	/*
	 * These are set to NULL by default.
	 *
	 * When destroy is not NULL, it is called on each item in order when
	 * btree_delete() is called.
	 *
	 * When destroy is NULL, btree_delete runs faster because it does not have
	 * to visit each and every item.
	 */
	btree_action_t destroy;
	void *destroy_ctx;
};

struct btree *btree_new(btree_search_t search);
void btree_delete(struct btree *btree);

/* Inserts an item into the btree.  If an item already exists that is equal
 * to this one (as determined by the search function), behavior depends on the
 * btree->multi setting.
 *   If btree->multi is false (default), returns false, and no item
 *      is inserted (because it would be a duplicate).
 *   If btree->multi is true, returns true, putting the item after
 *      its duplicates.
 */
bool btree_insert(struct btree *btree, const void *item);

/* Removes an item from the btree.  If an item exists that is equal to the
 * key (as determined by the search function), it is removed.
 *
 * If btree->multi is set, all matching items are removed.
 *
 * Returns true if item was found and deleted, false if not found. */
bool btree_remove(struct btree *btree, const void *key);

/* Finds the requested item.
 * Returns the item pointer on success, NULL on failure.
 * Note that NULL is a valid item value.  If you need to put
 * NULLs in a btree, use btree_find instead. */
void *btree_lookup(struct btree *btree, const void *key);


/* lr must be 0 or 1, nothing else. */
int btree_begin_end_lr(const struct btree *btree, btree_iterator iter, int lr);
int btree_find_lr(const struct btree *btree, const void *key,
				btree_iterator iter, int lr);

int btree_walk_backward(const struct btree *btree,
				btree_action_t action, void *ctx);
int btree_walk_forward(const struct btree *btree,
				btree_action_t action, void *ctx);

#define btree_begin(btree, iter) btree_begin_end_lr(btree, iter, 0)
#define btree_end(btree, iter) btree_begin_end_lr(btree, iter, 1)

int btree_prev(btree_iterator iter);
int btree_next(btree_iterator iter);

#define btree_walk(btree, action, ctx) btree_walk_forward(btree, action, ctx)

/*
 * If key was found, btree_find_first will return 1, iter->item will be the
 * first matching item, and iter will point to the beginning of the matching
 * items.
 *
 * If key was not found, btree_find_first will return 0, iter->item will be
 * undefined, and iter will point to where the key should go if inserted.
 */
#define btree_find_first(btree, key, iter) btree_find_lr(btree, key, iter, 0)

/*
 * If key was found, btree_find_last will return 1, iter->item will be the
 * last matching item, and iter will point to the end of the matching
 * items.
 *
 * If key was not found, btree_find_last will return 0, iter->item will be
 * undefined, and iter will point to where the key should go if inserted.
 */
#define btree_find_last(btree, key, iter) btree_find_lr(btree, key, iter, 1)

/* btree_find is an alias of btree_find_first. */
#define btree_find(btree, key, iter) btree_find_first(btree, key, iter)

/*
 * If iter points to an item, btree_deref returns 1 and sets iter->item to the
 * item it points to.
 *
 * Otherwise (if iter points to the end of the btree), btree_deref returns 0
 * and leaves iter untouched.
 */
int btree_deref(btree_iterator iter);

/*
 * Inserts the item before the one pointed to by iter.
 *
 * Insertion invalidates all iterators to the btree, including the one
 * passed to btree_insert_at.  Nevertheless, iter->item will be set to
 * the item inserted.
 */
void btree_insert_at(btree_iterator iter, const void *item);

/*
 * Removes the item pointed to by iter.  Returns 1 if iter pointed
 * to an item.  Returns 0 if iter pointed to the end, in which case
 * it leaves iter intact.
 *
 * Removal invalidates all iterators to the btree, including the one
 * passed to btree_remove_at.  Nevertheless, iter->item will be set to
 * the item removed.
 */
int btree_remove_at(btree_iterator iter);

/*
 * Compares positions of two iterators.
 *
 * Returns -1 if a is before b, 0 if a is at the same position as b,
 * and +1 if a is after b.
 */
int btree_cmp_iters(const btree_iterator iter_a, const btree_iterator iter_b);

#define btree_search_implement(name, type, setup, equals, lessthan) \
unsigned int name(const void *__key, \
		const void * const *__base, unsigned int __count, \
		int __lr, int *__found) \
{ \
	unsigned int __start = 0; \
	while (__count) { \
		unsigned int __middle = __count >> 1; \
		type a = (type)__key; \
		type b = (type)__base[__start + __middle]; \
		{ \
			setup; \
			if (equals) \
				goto __equals; \
			if (lessthan) \
				goto __lessthan; \
		} \
	__greaterthan: \
		__start += __middle + 1; \
		__count -= __middle + 1; \
		continue; \
	__equals: \
		*__found = 1; \
		if (__lr) \
			goto __greaterthan; \
		/* else, fall through to __lessthan */ \
	__lessthan: \
		__count = __middle; \
		continue; \
	} \
	return __start; \
}

#define MAX (BTREE_ITEM_MAX)
#define MIN (BTREE_ITEM_MAX >> 1)

static struct btree_node *node_alloc(int internal);
static void node_delete(struct btree_node *node, struct btree *btree);

static void branch_begin(btree_iterator iter);
static void branch_end(btree_iterator iter);
static void begin_end_lr(btree_iterator iter, struct btree_node *node, int lr);

/*
 * If iter->node has parent, returns 1 and ascends the iterator such that
 * iter->node->branch[iter->k] will be what iter->node was.
 *
 * If iter->node does not have a parent (is a root), returns 0 and leaves the
 * iterator untouched.
 */
#define ascend(iter) ((iter)->node->parent \
	? (iter)->k = (iter)->node->k, (iter)->node = (iter)->node->parent, 1 \
	: 0)

static void node_insert(const void *x, struct btree_node *xr,
				struct btree_node *p, unsigned int k);
static void node_split(const void **x, struct btree_node **xr,
				struct btree_node *p, unsigned int k);

static void node_remove_leaf_item(struct btree_node *node, unsigned int k);
void node_restore(struct btree_node *node, unsigned int k);

static int node_walk_backward(const struct btree_node *node,
				btree_action_t action, void *ctx);
static int node_walk_forward(const struct btree_node *node,
				btree_action_t action, void *ctx);


/************************* Public functions *************************/

struct btree *btree_new(btree_search_t search)
{
	struct btree *btree = calloc(1, sizeof(struct btree));
	struct btree_node *node = node_alloc(0);
		node->parent = NULL;
		node->count = 0;
		node->depth = 0;
	btree->root = node;
	btree->search = search;
	btree->multi = false;
	return btree;
}

void btree_delete(struct btree *btree)
{
	node_delete(btree->root, btree);
	free(btree);
}

bool btree_insert(struct btree *btree, const void *item)
{
	btree_iterator iter;

	if (btree_find_last(btree, item, iter) && !btree->multi)
		return false;

	btree_insert_at(iter, item);
	return true;
}

bool btree_remove(struct btree *btree, const void *key)
{
	btree_iterator iter;
	bool success = false;
	bool multi = btree->multi;

	do {
		if (btree_find_first(btree, key, iter)) {
			btree_remove_at(iter);
			success = true;
		}
	} while (multi);

	return success;
}

void *btree_lookup(struct btree *btree, const void *key)
{
	btree_iterator iter;

	if (btree_find_first(btree, key, iter))
		return iter->item;

	return NULL;
}

int btree_begin_end_lr(const struct btree *btree, btree_iterator iter, int lr)
{
	struct btree_node *node;

	iter->btree = (struct btree *)btree;
	begin_end_lr(iter, btree->root, lr);

	/* Set iter->item if any items exist. */
	node = iter->node;
	if (node->count) {
		iter->item = (void*)node->item[iter->k - lr];
		return 1;
	}

	return 0;
}

int btree_deref(btree_iterator iter)
{
	if (iter->k >= iter->node->count) {
		struct btree_iterator_s tmp = *iter;
		do {
			if (!ascend(iter)) {
				*iter = tmp;
				return 0;
			}
		} while (iter->k >= iter->node->count);
	}

	iter->item = (void*)iter->node->item[iter->k];
	return 1;
}

int btree_prev(btree_iterator iter)
{
	if (iter->node->depth) {
		branch_end(iter);
	} else if (iter->k == 0) {
		struct btree_iterator_s tmp = *iter;
		do {
			if (!ascend(iter)) {
				*iter = tmp;
				return 0;
			}
		} while (iter->k == 0);
	}

	iter->item = (void*)iter->node->item[--iter->k];
	return 1;
}

int btree_next(btree_iterator iter)
{
	int ret = btree_deref(iter);
	if (ret) {
		iter->k++;
		if (iter->node->depth)
			branch_begin(iter);
	}
	return ret;
}

int btree_find_lr(const struct btree *btree, const void *key,
				btree_iterator iter, int lr)
{
	struct btree_node *node = btree->root;
	unsigned int k;
	unsigned int depth;
	int found = 0;

	iter->btree = (struct btree *)btree;
	iter->item = NULL;

	depth = node->depth;
	for (;;) {
		int f = 0;
		k = btree->search(key, node->item, node->count, lr, &f);

		if (f) {
			iter->item = (void*)node->item[k - lr];
			found = 1;
		}
		if (!depth--)
			break;

		node = node->branch[k];
	}

	iter->node = node;
	iter->k = k;

	return found;
}

int btree_walk_backward(const struct btree *btree,
				btree_action_t action, void *ctx)
{
	return node_walk_backward(btree->root, action, ctx);
}

int btree_walk_forward(const struct btree *btree,
				btree_action_t action, void *ctx)
{
	return node_walk_forward(btree->root, action, ctx);
}

void btree_insert_at(btree_iterator iter, const void *item)
{
	const void *x = item;
	struct btree_node *xr = NULL;
	struct btree_node *p;
	struct btree *btree = iter->btree;

	/* btree_insert_at always sets iter->item to item. */
	iter->item = (void*)item;

	/*
	 * If node is not a leaf, fall to the end of the left branch of item[k]
	 * so that it will be a leaf. This does not modify the iterator's logical
	 * position.
	 */
	if (iter->node->depth)
		branch_end(iter);

	/*
	 * First try inserting item into this node.
	 * If it's too big, split it, and repeat by
	 * trying to insert the median and right subtree into parent.
	 */
	if (iter->node->count < MAX) {
		node_insert(x, xr, iter->node, iter->k);
		goto finished;
	} else {
		for (;;) {
			node_split(&x, &xr, iter->node, iter->k);

			if (!ascend(iter))
				break;

			if (iter->node->count < MAX) {
				node_insert(x, xr, iter->node, iter->k);
				goto finished;
			}
		}

		/*
		 * If splitting came all the way up to the root, create a new root whose
		 * left branch is the current root, median is x, and right branch is the
		 * half split off from the root.
		 */
		assert(iter->node == btree->root);
		p = node_alloc(1);
		p->parent = NULL;
		p->count = 1;
		p->depth = btree->root->depth + 1;
		p->item[0] = x;
		p->branch[0] = btree->root;
			btree->root->parent = p;
			btree->root->k = 0;
		p->branch[1] = xr;
			xr->parent = p;
			xr->k = 1;
		btree->root = p;
	}

finished:
	btree->count++;
	iter->node = NULL;
}

int btree_remove_at(btree_iterator iter)
{
	struct btree *btree = iter->btree;
	struct btree_node *root;

	if (!btree_deref(iter))
		return 0;

	if (!iter->node->depth) {
		node_remove_leaf_item(iter->node, iter->k);
		if (iter->node->count >= MIN || !iter->node->parent)
			goto finished;
	} else {
		/*
		 * We can't remove an item from an internal node, so we'll replace it
		 * with its successor (which will always be in a leaf), then remove
		 * the original copy of the successor.
		 */

		/* Save pointer to condemned item. */
		const void **x = &iter->node->item[iter->k];

		/* Descend to successor. */
		iter->k++;
		branch_begin(iter);

		/* Replace condemned item with successor. */
		*x = iter->node->item[0];

		/* Remove successor. */
		node_remove_leaf_item(iter->node, 0);
	}

	/*
	 * Restore nodes that fall under their minimum count.  This may
	 * propagate all the way up to the root.
	 */
	for (;;) {
		if (iter->node->count >= MIN)
			goto finished;
		if (!ascend(iter))
			break;
		node_restore(iter->node, iter->k);
	}

	/*
	 * If combining came all the way up to the root, and it has no more
	 * dividers, delete it and make its only branch the root.
	 */
	root = iter->node;
	assert(root == btree->root);
	assert(root->depth > 0);
	if (root->count == 0) {
		btree->root = root->branch[0];
		btree->root->parent = NULL;
		free(root);
	}

finished:
	btree->count--;
	iter->node = NULL;
	return 1;
}

/*
 * ascends iterator a until it matches iterator b's depth.
 *
 * Returns -1 if they end up on the same k (meaning a < b).
 * Returns 0 otherwise.
 */
static int elevate(btree_iterator a, btree_iterator b)
{
	while (a->node->depth < b->node->depth)
		ascend(a);

	if (a->k == b->k)
		return -1;
	return 0;
}

int btree_cmp_iters(const btree_iterator iter_a, const btree_iterator iter_b)
{
	btree_iterator a = {*iter_a}, b = {*iter_b};
	int ad, bd;

	ad = btree_deref(a);
	bd = btree_deref(b);

	/* Check cases where one or both iterators are at the end. */
	if (!ad)
		return bd ? 1 : 0;
	if (!bd)
		return ad ? -1 : 0;

	/* Bring iterators to the same depth. */
	if (a->node->depth < b->node->depth) {
		if (elevate(a, b))
			return -1;
	} else if (a->node->depth > b->node->depth) {
		if (elevate(b, a))
			return 1;
	}

	/* Bring iterators to the same node. */
	while (a->node != b->node) {
		ascend(a);
		ascend(b);
	}

	/* Now we can compare by k directly. */
	if (a->k < b->k)
		return -1;
	if (a->k > b->k)
		return 1;

	return 0;
}

/********************* Built-in ordering functions *******************/

btree_search_implement
(
	btree_strcmp,
	char*,
	int c = strcmp(a, b),
	c == 0,
	c < 0
)


/************************* Private functions *************************/

static struct btree_node *node_alloc(int internal)
{
	struct btree_node *node;
	size_t isize = internal
		? sizeof(struct btree_node*) * (BTREE_ITEM_MAX+1)
		: 0;
	node = malloc(sizeof(struct btree_node) + isize);
	return node;
}

static void node_delete(struct btree_node *node, struct btree *btree)
{
	unsigned int i, count = node->count;

	if (!node->depth) {
		if (btree->destroy) {
			for (i=0; i<count; i++)
				btree->destroy((void*)node->item[i], btree->destroy_ctx);
		}
	} else {
		for (i=0; i<count; i++) {
			node_delete(node->branch[i], btree);
			if (btree->destroy)
				btree->destroy((void*)node->item[i], btree->destroy_ctx);
		}
		node_delete(node->branch[count], btree);
	}

	free(node);
}

/* Set iter to beginning of branch pointed to by iter. */
static void branch_begin(btree_iterator iter)
{
	struct btree_node *node = iter->node->branch[iter->k];
	unsigned int depth = node->depth;
	while (depth--)
		node = node->branch[0];
	iter->node = node;
	iter->k = 0;
}

/* Set iter to end of branch pointed to by iter. */
static void branch_end(btree_iterator iter)
{
	struct btree_node *node = iter->node->branch[iter->k];
	unsigned int depth = node->depth;
	while (depth--)
		node = node->branch[node->count];
	iter->node = node;
	iter->k = node->count;
}

/* Traverse to the beginning or end of node, depending on lr. */
static void begin_end_lr(btree_iterator iter, struct btree_node *node, int lr)
{
	iter->node = node;
	iter->k = lr ? node->count : 0;
	if (node->depth)
		(lr ? branch_end : branch_begin)(iter);
}

/*
 * Inserts item x and right branch xr into node p at position k.
 *
 * Assumes p exists and has enough room.
 * Ignores xr if p is a leaf.
 */
static void node_insert(const void *x, struct btree_node *xr,
				struct btree_node *p, unsigned int k)
{
	unsigned int i;

	for (i = p->count; i-- > k;)
		p->item[i+1] = p->item[i];
	p->item[k] = x;

	if (p->depth) {
		k++;
		for (i = p->count+1; i-- > k;) {
			p->branch[i+1] = p->branch[i];
			p->branch[i+1]->k = i+1;
		}
		p->branch[k] = xr;
		xr->parent = p;
		xr->k = k;
	}

	p->count++;
}

/*
 * Inserts item *x and subtree *xr into node p at position k, splitting it into
 * nodes p and *xr with median item *x.
 *
 * Assumes p->count == MAX.
 * Ignores original *xr if p is a leaf, but always sets it.
 */
static void node_split(const void **x, struct btree_node **xr,
				struct btree_node *p, unsigned int k)
{
	unsigned int i, split;
	struct btree_node *l = p, *r;

	/*
	 * If k <= MIN, item will be inserted into left subtree, so give l
	 * fewer items initially.
	 * Otherwise, item will be inserted into right subtree, so give r
	 * fewer items initially.
	 */
	if (k <= MIN)
		split = MIN;
	else
		split = MIN + 1;

	/*
	 * If l->depth is 0, allocate a leaf node.
	 * Otherwise, allocate an internal node.
	 */
	r = node_alloc(l->depth);

	/* l and r will be siblings, so they will have the same parent and depth. */
	r->parent = l->parent;
	r->depth = l->depth;

	/*
	 * Initialize items/branches of right side.
	 * Do not initialize r's leftmost branch yet because we don't know
	 * whether it will be l's current rightmost branch or if *xr will
	 * take its place.
	 */
	for (i = split; i < MAX; i++)
		r->item[i-split] = l->item[i];
	if (r->depth) {
		for (i = split+1; i <= MAX; i++) {
			r->branch[i-split] = l->branch[i];
			r->branch[i-split]->parent = r;
			r->branch[i-split]->k = i-split;
		}
	}

	/* Update counts. */
	l->count = split;
	r->count = MAX - split;

	/*
	 * The nodes are now split, but the key isn't inserted yet.
	 *
	 * Insert key into left or right half,
	 * depending on which side it fell on.
	 */
	if (k <= MIN)
		node_insert(*x, *xr, l, k);
	else
		node_insert(*x, *xr, r, k - split);

	/*
	 * Give l's rightmost branch to r because l's rightmost item
	 * is going up to become the median.
	 */
	if (r->depth) {
		r->branch[0] = l->branch[l->count];
		r->branch[0]->parent = r;
		r->branch[0]->k = 0;
	}

	/*
	 * Take up l's rightmost item to make it the median.
	 * That item's right branch is now r.
	 */
	*x = l->item[--l->count];
	*xr = r;
}

/*
 * Removes item k from node p, shifting successor items back and
 * decrementing the count.
 *
 * Assumes node p has the item k and is a leaf.
 */
static void node_remove_leaf_item(struct btree_node *node, unsigned int k)
{
	unsigned int i;
	for (i = k+1; i < node->count; i++)
		node->item[i-1] = node->item[i];
	node->count--;
}

static void move_left(struct btree_node *node, unsigned int k);
static void move_right(struct btree_node *node, unsigned int k);
static void combine(struct btree_node *node, unsigned int k);

/*
 * Fixes node->branch[k]'s problem of having one less than MIN items.
 * May or may not cause node to fall below MIN items, depending on whether
 * two branches are combined or not.
 */
void node_restore(struct btree_node *node, unsigned int k)
{
	if (k == 0) {
		if (node->branch[1]->count > MIN)
			move_left(node, 0);
		else
			combine(node, 0);
	} else if (k == node->count) {
		if (node->branch[k-1]->count > MIN)
			move_right(node, k-1);
		else
			combine(node, k-1);
	} else if (node->branch[k-1]->count > MIN) {
		move_right(node, k-1);
	} else if (node->branch[k+1]->count > MIN) {
		move_left(node, k);
	} else {
		combine(node, k-1);
	}
}

static void move_left(struct btree_node *node, unsigned int k)
{
	struct btree_node *l = node->branch[k], *r = node->branch[k+1], *mv;
	unsigned int i;

	l->item[l->count] = node->item[k];
	node->item[k] = r->item[0];
	for (i = 1; i < r->count; i++)
		r->item[i-1] = r->item[i];

	if (r->depth) {
		mv = r->branch[0];
		l->branch[l->count+1] = mv;
		mv->parent = l;
		mv->k = l->count+1;

		for (i = 1; i <= r->count; i++) {
			r->branch[i-1] = r->branch[i];
			r->branch[i-1]->k = i-1;
		}
	}

	l->count++;
	r->count--;
}

static void move_right(struct btree_node *node, unsigned int k)
{
	struct btree_node *l = node->branch[k], *r = node->branch[k+1];
	unsigned int i;

	for (i = r->count; i--;)
		r->item[i+1] = r->item[i];
	r->item[0] = node->item[k];
	node->item[k] = l->item[l->count-1];

	if (r->depth) {
		for (i = r->count+1; i--;) {
			r->branch[i+1] = r->branch[i];
			r->branch[i+1]->k = i+1;
		}
		r->branch[0] = l->branch[l->count];
		r->branch[0]->parent = r;
		r->branch[0]->k = 0;
	}

	l->count--;
	r->count++;
}

/* Combine node->branch[k] and node->branch[k+1]. */
static void combine(struct btree_node *node, unsigned int k)
{
	struct btree_node *l = node->branch[k], *r = node->branch[k+1], *mv;
	const void **o = &l->item[l->count];
	unsigned int i;

	//append node->item[k] followed by right node's items to left node
	*o++ = node->item[k];
	for (i=0; i<r->count; i++)
		*o++ = r->item[i];

	//if applicable, append right node's branches to left node
	if (r->depth) {
		for (i=0; i<=r->count; i++) {
			mv = r->branch[i];
			l->branch[l->count + i + 1] = mv;
			mv->parent = l;
			mv->k = l->count + i + 1;
		}
	}

	//remove k and its right branch from parent node
	for (i = k+1; i < node->count; i++) {
		node->item[i-1] = node->item[i];
		node->branch[i] = node->branch[i+1];
		node->branch[i]->k = i;
	}

	//don't forget to update the left and parent node's counts and to free the right node
	l->count += r->count + 1;
	node->count--;
	free(r);
}

static int node_walk_backward(const struct btree_node *node,
				btree_action_t action, void *ctx)
{
	unsigned int i, count = node->count;

	if (!node->depth) {
		for (i=count; i--;)
			if (!action((void*)node->item[i], ctx))
				return 0;
	} else {
		if (!node_walk_backward(node->branch[count], action, ctx))
			return 0;
		for (i=count; i--;) {
			if (!action((void*)node->item[i], ctx))
				return 0;
			if (!node_walk_backward(node->branch[i], action, ctx))
				return 0;
		}
	}

	return 1;
}

static int node_walk_forward(const struct btree_node *node,
				btree_action_t action, void *ctx)
{
	unsigned int i, count = node->count;

	if (!node->depth) {
		for (i=0; i<count; i++)
			if (!action((void*)node->item[i], ctx))
				return 0;
	} else {
		for (i=0; i<count; i++) {
			if (!node_walk_forward(node->branch[i], action, ctx))
				return 0;
			if (!action((void*)node->item[i], ctx))
				return 0;
		}
		if (!node_walk_forward(node->branch[count], action, ctx))
			return 0;
	}

	return 1;
}

struct test_item {
	int key;
	int value;
};

static btree_search_implement(
	order_by_key,
	struct test_item *,
	,
	a->key == b->key,
	a->key < b->key
)

static int insert_test_item(struct btree *btree, int key, int value)
{
	struct test_item key_item = {key, -101};
	struct test_item *item;
	btree_iterator iter;

	if (btree_find_first(btree, &key_item, iter)) {
		/* Don't insert new item, but do update its value. */
		item = iter->item;
		item->value = value;
		return 0;
	}

	item = malloc(sizeof(*item));
	item->key = key;
	item->value = value;

	btree_insert_at(iter, item);

	return 1;
}

static int lookup_test_item(const struct btree *btree, int key)
{
	struct test_item key_item = {key, -102};
	struct test_item *item;
	btree_iterator iter;

	if (!btree_find_first(btree, &key_item, iter))
		return -100;

	item = iter->item;
	return item->value;
}

static int destroy_test_item(void *item, void *ctx) {
	(void) ctx;
	free(item);
	return 1;
}

struct test_insert_entry {
	int key;
	int value;
	int expected_return;
};

struct test_traverse_entry {
	int key;
	int value;
};

static void print_indent(unsigned int indent) {
	while (indent--)
		fputs("\t", stdout);
}

static void btree_node_trace(struct btree_node *node, unsigned int indent)
{
	unsigned int i;
	for (i=0; i<node->count; i++) {
		if (node->depth)
			btree_node_trace(node->branch[i], indent+1);
		print_indent(indent);
		puts(node->item[i]);
	}
	if (node->depth)
		btree_node_trace(node->branch[node->count], indent+1);
}

static void btree_trace(struct btree *btree)
{
	btree_node_trace(btree->root, 0);
}

#define fail(cond) { printf("TEST FAILED: %s:%d: %s\n", __FILE__, __LINE__, \
		cond); abort(); }

#define ok1(cond) if (!(cond)) { fail(#cond); }

static void test_insert(struct btree *btree)
{
	struct test_insert_entry ent[] = {
		{3, 1, 1}, {4, 1, 1}, {5, 9, 1}, {2, 6, 1}, {5, 3, 0}, {5, 8, 0},
		{9, 7, 1}, {9, 3, 0}, {2, 3, 0}, {8, 4, 1}, {6, 2, 1}, {6, 4, 0},
		{3, 3, 0}, {8, 3, 0}, {2, 7, 0}, {9, 5, 0}, {0, 2, 1}, {8, 8, 0},
		{4, 1, 0}, {9, 7, 0}, {1, 6, 1}, {9, 3, 0}, {9, 9, 0}, {3, 7, 0},
		{5, 1, 0}, {0, 5, 0}, {8, 2, 0}, {0, 9, 0}, {7, 4, 1}, {9, 4, 0},
		{4, 5, 0}, {9, 2, 0}
	};
	size_t i, count = sizeof(ent) / sizeof(*ent);

	for (i = 0; i < count; i++) {
		int ret = insert_test_item(btree, ent[i].key, ent[i].value);
		ok1(ret == ent[i].expected_return);
	}
}

static void test_find_traverse(struct btree *btree)
{
	struct test_traverse_entry ent[] = {
		{0, 9}, {1, 6}, {2, 7}, {3, 7}, {4, 5},
		{5, 1}, {6, 4}, {7, 4}, {8, 2}, {9, 2}
	};
	size_t i, count = sizeof(ent) / sizeof(*ent);
	btree_iterator iter;

	i = 0;
	for (btree_begin(btree, iter); btree_next(iter);) {
		struct test_item *item = iter->item;

		if (i >= count) {
			fail("Too many items in btree according to forward traversal");
			break;
		}

		ok1(lookup_test_item(btree, item->key) == item->value);
		ok1(item->key == ent[i].key && item->value == ent[i].value);

		i++;
	}

	if (i != count)
		fail("Not enough items in btree according to forward traversal");

	i = count;
	for (btree_end(btree, iter); btree_prev(iter);) {
		struct test_item *item = iter->item;

		if (!i--) {
			fail("Too many items in btree according to backward traversal");
			break;
		}

		ok1(lookup_test_item(btree, item->key) == item->value);
		ok1(item->key == ent[i].key && item->value == ent[i].value);
	}

	if (i != 0)
		fail("Not enough items in btree according to backward traversal");
}

static btree_search_proto order_by_string;

static btree_search_implement(
	order_by_string, //function name
	const char*, //key type
	int c = strcmp(a, b), //setup
	c == 0, // a == b predicate
	c < 0 // a < b predicate
)

//used in the test case to sort the test strings
static int compare_by_string(const void *ap, const void *bp)
{
	const char * const *a = ap;
	const char * const *b = bp;
	return strcmp(*a, *b);
}

static void test_traverse(struct btree *btree, const char *sorted[], size_t count)
{
	btree_iterator iter, iter2;
	size_t i;

	i = 0;
	for (btree_begin(btree, iter); btree_next(iter);) {
		if (i >= count) {
			fail("Too many items in btree according to forward traversal");
			break;
		}

		ok1(iter->item == sorted[i]);

		btree_find_first(btree, sorted[i], iter2);
		ok1(iter2->item == sorted[i]);

		i++;
	}

	if (i != count)
		fail("Not enough items in btree according to forward traversal");

	i = count;
	for (btree_end(btree, iter); btree_prev(iter);) {
		if (!i--) {
			fail("Too many items in btree according to backward traversal");
			break;
		}

		ok1(iter->item == sorted[i]);

		btree_find_first(btree, sorted[i], iter2);
		ok1(iter2->item == sorted[i]);
	}

	if (i != 0)
		fail("Not enough items in btree according to backward traversal");
}

static void test_search_implement(void)
{
	struct btree *btree = btree_new(order_by_string);
	size_t i;

	const char *unsorted[] = {
		"md4",
		"isaac",
		"noerr",
		"talloc_link",
		"asearch",
		"tap",
		"crcsync",
		"wwviaudio",
		"array_size",
		"alignof",
		"str",
		"read_write_all",
		"grab_file",
		"out",
		"daemonize",
		"array",
		"crc",
		"str_talloc",
		"build_assert",
		"talloc",
		"alloc",
		"endian",
		"btree",
		"typesafe_cb",
		"check_type",
		"list",
		"ciniparser",
		"ilog",
		"ccan_tokenizer",
		"tdb",
		"block_pool",
		"sparse_bsearch",
		"container_of",
		"stringmap",
		"hash",
		"short_types",
		"ogg_to_pcm",
		"antithread",
	};
	size_t count = sizeof(unsorted) / sizeof(*unsorted);
	const char *sorted[count];

	memcpy(sorted, unsorted, sizeof(sorted));
	qsort(sorted, count, sizeof(*sorted), compare_by_string);

	for (i=0; i<count; i++) {
		btree_iterator iter;

		if (btree_find_first(btree, unsorted[i], iter))
			fail("btree_insert thinks the test array has duplicates, but it doesn't")
		else
			btree_insert_at(iter, unsorted[i]);
	}
	btree_trace(btree);

	test_traverse(btree, sorted, count);

	btree_delete(btree);
}

int main(void)
{
	struct btree *btree;

	btree = btree_new(order_by_key);
	btree->destroy = destroy_test_item;
	test_insert(btree);
	test_find_traverse(btree);
	btree_delete(btree);

	test_search_implement();

    // CHECK:     alignof
    // CHECK:     alloc
    // CHECK:     antithread
    // CHECK:     array
    // CHECK:     array_size
    // CHECK:     asearch
    // CHECK:     block_pool
    // CHECK:     btree
    // CHECK:     build_assert
    // CHECK:     ccan_tokenizer
    // CHECK:     check_type
    // CHECK:     ciniparser
    // CHECK:     container_of
    // CHECK:     crc
    // CHECK:     crcsync
    // CHECK:     daemonize
    // CHECK:     endian
    // CHECK:     grab_file
    // CHECK:     hash
    // CHECK:     ilog
    // CHECK: isaac
    // CHECK:     list
    // CHECK:     md4
    // CHECK:     noerr
    // CHECK:     ogg_to_pcm
    // CHECK:     out
    // CHECK:     read_write_all
    // CHECK:     short_types
    // CHECK:     sparse_bsearch
    // CHECK:     str
    // CHECK:     str_talloc
    // CHECK:     stringmap
    // CHECK:     talloc
    // CHECK:     talloc_link
    // CHECK:     tap
    // CHECK:     tdb
    // CHECK:     typesafe_cb
    // CHECK:     wwviaudio

    printf("PASS\n"); // CHECK: PASS


    return 0;
}
