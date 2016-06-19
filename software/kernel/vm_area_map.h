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

#include "fs.h"
#include "list.h"

// An area is a set of contiguous virtual memory addresses that share some
// characteristics like permissions or data source The area map tracks all areas
// in an address space.

#define AREA_WIRED 1
#define AREA_WRITABLE 2
#define AREA_EXECUTABLE 4

enum placement
{
    PLACE_EXACT,
    PLACE_SEARCH_DOWN,
    PLACE_SEARCH_UP
};

struct vm_area
{
    struct list_node list_entry;
    unsigned int low_address;
    unsigned int high_address;
    struct vm_cache *cache;
    unsigned int cache_offset;
    unsigned int cache_length;
    unsigned int flags;
    char name[32];
};

struct vm_area_map
{
    unsigned int low_address;
    unsigned int high_address;
    struct list_node area_list;
};

void init_area_map(struct vm_area_map *map, unsigned int low_address,
                   unsigned int high_address);
struct vm_area *create_vm_area(struct vm_area_map*, unsigned int address,
                               unsigned int size, enum placement place,
                               const char *name, unsigned int flags);
void destroy_vm_area(struct vm_area *area);
const struct vm_area *lookup_area(const struct vm_area_map*,
                                  unsigned int address);
void dump_area_map(const struct vm_area_map*);
struct vm_area *first_area(struct vm_area_map*);
