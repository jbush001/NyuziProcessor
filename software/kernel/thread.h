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

#include "vm.h"

#define MAX_CORES 32

struct thread
{
    struct vm_translation_map *map;
    void *stack_base;
    void *current_stack;
    void (*start_function)(void *param);
    void *param;
};

void boot_init_thread(struct thread *th);
void switch_to_thread(struct thread *th);
struct thread *current_thread(void);