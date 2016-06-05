//
// Copyright 2016 Jeff Bush
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#pragma once

struct list_node
{
    struct list_node *prev;
    struct list_node *next;
};

static inline int list_is_empty(struct list_node *node)
{
    return node->next == node;
}

static inline struct list_node *list_init(struct list_node *list)
{
    list->next = list;
    list->prev = list;

    return list;
}

static inline struct list_node *__list_add_head(struct list_node *list,
        struct list_node *node)
{
    node->prev = list;
    node->next = list->next;
    node->prev->next = node;
    node->next->prev = node;

    return node;
}

static inline struct list_node *__list_add_tail(struct list_node *list,
        struct list_node *node)
{
    node->prev = list->prev;
    node->next = list;
    node->prev->next = node;
    node->next->prev = node;

    return node;
}

static inline struct list_node *__list_remove_node(struct list_node *node)
{
    node->prev->next = node->next;
    node->next->prev = node->prev;
    node->next = 0;
    node->prev = 0;

    return node;
}

static inline struct list_node *__list_remove_head(struct list_node *list)
{
    struct list_node *node;
    if (list_is_empty(list))
        return 0;

    node = list->next;
    node->prev->next = node->next;
    node->next->prev = node->prev;

    return node;
}

static inline struct list_node *__list_remove_tail(struct list_node *list)
{
    struct list_node *node;
    if (list_is_empty(list))
        return 0;

    node = list->prev;
    node->prev->next = node->next;
    node->next->prev = node->prev;

    return node;
}

static inline struct list_node *__list_peek_head(struct list_node *list)
{
    if (list_is_empty(list))
        return 0;
    else
        return list->next;
}

static inline struct list_node *__list_peek_tail(struct list_node *list)
{
    if (list_is_empty(list))
        return 0;
    else
        return list->prev;
}

static inline struct list_node *__list_add_after(struct list_node *prev,
        struct list_node *node)
{
    node->prev = prev;
    node->next = prev->next;
    node->prev->next = node;
    node->next->prev = node;

    return node;
}

static inline struct list_node *__list_add_before(struct list_node *next,
        struct list_node *node)
{
    node->prev = next->prev;
    node->next = next;
    node->prev->next = node;
    node->next->prev = node;

    return node;
}

static inline struct list_node *__list_next(struct list_node *list,
        struct list_node *node)
{
    if (node->next == list)
        return 0;
    else
        return node->next;
}

static inline struct list_node *__list_prev(struct list_node *list,
        struct list_node *node)
{
    if (node->prev == list)
        return 0;
    else
        return node->prev;
}


#define list_add_head(list,node) \
    __list_add_head(list, (struct list_node*)(node))
#define list_add_tail(list,node) \
    __list_add_tail(list, (struct list_node*)(node))
#define list_remove_node(node) \
    __list_remove_node((struct list_node*) (node))

// XXX note: when this finishes, node will not be null.
#define list_for_each(list, node, type) \
    for (node = (type*)(list)->next; node != (type*)(list); \
        node = (type*)((struct list_node*)(node))->next)

#define list_remove_head(list, type) ((type*) __list_remove_head(list))
#define list_remove_tail(list, type) ((type*) __list_remove_head(list))

#define member_to_struct(ptr, member, type) \
    ((type*)(((char*) ptr) - __builtin_offsetof(type, member)))

#define multilist_remove_head(list, type, member) ({ \
    struct list_node *node = (struct list_node*) __list_remove_head(list); \
    type *__elem; \
    if (node) \
        __elem = member_to_struct(__elem, member, type); \
    else \
        __elem = 0; \
    __elem; });

#define multilist_remove_tail(list, type, member) ({ \
    struct list_node *node = (struct list_node*) __list_remove_tail(list); \
    type *__elem; \
    if (node) \
        __elem = member_to_struct(__elem, member, type); \
    else \
        __elem = 0; \
    __elem; });

#define multilist_for_each(head, node, member, type) \
    for (node = member_to_struct((head)->next, member, type); \
        &(node)->member != (head); \
        node = member_to_struct((node)->member.next, member, type))

#define list_next(list, node, type) \
    ((type*)__list_next(list, (struct list_node*) node))
#define list_prev(list, node, type) \
    ((type*)__list_prev(list, (struct list_node*) node))
#define list_peek_head(list, type) ((type*) __list_peek_head(list))
#define list_peek_tail(list, type) ((type*) __list_peek_tail(list))

#define list_add_after(prev, node) __list_add_after((struct list_node*) (prev), \
    (struct list_node*)(node))
#define list_add_before(next, node) __list_add_before((struct list_node*) (next), \
    (struct list_node*)(node))

