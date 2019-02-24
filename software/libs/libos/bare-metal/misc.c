//
// Copyright 2015 Jeff Bush
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

#include "nyuzi.h"
#include <time.h>
#include "registers.h"
#include "unistd.h"

#define CLOCKS_PER_US 50
#define MAX_THREADS 64
#define CR_CYCLE_COUNT 6
#define CR_SUSPEND_THREAD 20

int __errno_array[MAX_THREADS];

int *__errno_ptr(void)
{
    return &__errno_array[get_current_thread_id()];
}

int usleep(useconds_t delay)
{
    int expire = __builtin_nyuzi_read_control_reg(CR_CYCLE_COUNT) + delay * CLOCKS_PER_US;
    while (__builtin_nyuzi_read_control_reg(CR_CYCLE_COUNT) < expire)
        ;

    return 0;
}

void exit(int status)
{
    (void) status;

    __builtin_nyuzi_write_control_reg(CR_SUSPEND_THREAD, 0xffffffff);
    while (1)
        ;
}
