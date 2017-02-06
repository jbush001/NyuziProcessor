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

#include <errno.h>
#include "syscall.h"

int get_current_thread_id(void)
{
    return __syscall(SYS_get_thread_id, 0, 0, 0, 0, 0);
}

unsigned int get_cycle_count(void)
{
    return __syscall(SYS_get_cycle_count, 0, 0, 0, 0, 0);
}

void *create_area(unsigned int address, unsigned int size, int placement,
                  const char *name, int flags)
{
    void *ptr = (void*) __syscall(SYS_create_area, address, size, placement, (int) name, flags);
    if (ptr == 0)
        errno = EINVAL;

    return ptr;
}

int exec(const char *path)
{
    int retval = __syscall(SYS_exec, (int) path, 0, 0, 0, 0);
    if (retval < 0)
    {
        errno = -retval;
        return -1;
    }

    return retval;
}
