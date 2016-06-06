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

#include "list.h"
#include "spinlock.h"

//
// Reader/writer lock
//

struct rwlock
{
    spinlock_t spinlock;
    volatile int write_locked;
    volatile int active_read_count;
    struct list_node reader_wait_list;
    struct list_node writer_wait_list;
};

void init_rwlock(struct rwlock*);
void rwlock_lock_read(struct rwlock*);
void rwlock_unlock_read(struct rwlock*);
void rwlock_lock_write(struct rwlock*);
void rwlock_unlock_write(struct rwlock*);

