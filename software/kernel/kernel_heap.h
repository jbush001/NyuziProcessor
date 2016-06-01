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

//
// This manages kernel data structure allocations. It is a simple first-fit
// allocator that is not optimized to reduce fragmentation or reduce runtime.
// As such, it should be used for long lived structures or as a low level
// allocator for optimized higher level slab allocator. size is not rounded at
// all, but should be a page multiple.
//

void boot_init_heap(const char *base_address);
void *kmalloc(unsigned int size);
void kfree(void *ptr, unsigned int size);
