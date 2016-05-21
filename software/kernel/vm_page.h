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

// XXX hack
#define MEMORY_SIZE 0x1000000
#define PAGE_STRUCTURES_SIZE (sizeof(struct vm_page) * (MEMORY_SIZE / PAGE_SIZE))

#define PAGE_SIZE 0x1000
#define PAGE_ALIGN(x) (x & ~(PAGE_SIZE - 1))

struct vm_page
{
    struct vm_page *next;
};

void vm_page_init(void);
unsigned int vm_allocate_page(void);
