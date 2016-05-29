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

#include "vm_translation_map.h"

#define MAX_CORES 32

struct thread
{
    unsigned int *kernel_stack;
    unsigned int *current_stack;
    struct vm_translation_map *map;
    void *stack_base;
    void (*start_function)(void *param);
    void *param;
    struct thread *queue_next;
};

struct thread_queue
{
    struct thread *head;
    struct thread *tail;
};

void boot_init_thread(struct vm_translation_map *map);

struct thread *current_thread(void);
struct thread *spawn_thread(struct vm_translation_map *map,
                            void (*start_function)(void *param),
                            void *param);
void enqueue_thread(struct thread_queue*, struct thread*);
struct thread *dequeue_thread(struct thread_queue*);
void reschedule(void);
void exec_program(const char *filename);
