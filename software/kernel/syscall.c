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

#include "thread.h"
#include "libc.h"
#include "registers.h"
#include "vga.h"

#define NUM_PERF_COUNTERS 4

extern int user_copy(void *dest, const void *src, int count);
extern int user_strlcpy(char *dest, const char *src, int count);

int handle_syscall(int arg0, int arg1, int arg2, int arg3, int arg4,
                   int arg5)
{
    char tmp[64];

    (void) arg4;
    (void) arg5;

    switch (arg0)
    {
        case 0: // int write_serial(const char *data, int length);
            if ((unsigned int) arg2 >= sizeof(tmp) - 2)
            {
                kprintf("size out of range\n");
                return -1;
            }

            if (user_copy(tmp, (void*) arg1, arg2) < 0)
            {
                kprintf("user copy failed\n");
                return -1;
            }

            tmp[arg2] = '\0';
            kprintf("%s", tmp);
            return 0;

        case 1: // int spawn_user_thread(const char *name, function, void *arg);
            spawn_user_thread((const char*) arg1, current_thread()->proc, arg2,
                              (void*) arg3);
            return 0;

        case 2: // int get_thread_id();
            return current_thread()->id;

        case 3: // int exec(const char *path);
        {
            // XXX unsafe user copy. Need copy_from_user
            struct process *proc = exec_program((const char*) arg1);
            if (proc)
                return proc->id;
            else
                return -1;
        }

        case 4: // void thread_exit(int code)
            thread_exit(arg1);  // This will not return

        case 5: // void *init_vga(int mode);
            return (int) init_vga(arg1);

        case 6: // void *create_area(unsigned int address, unsigned int size, int placement,
                //                   const char *name, int flags);
        {
            if (user_strlcpy(tmp, (const char*) arg4, sizeof(tmp)) < 0)
                return 0;

            struct vm_area *area = create_area(current_thread()->proc->space,
                (unsigned int) arg1, // Address
                (unsigned int) arg2, // size
                arg3, // Placement
                tmp,
                arg5, // flags,
                0, 0);

            if (area == 0)
                return 0;

            return area->low_address;
        }

        case 7: // void set_perf_counter_event(int counter, enum performance_event event)
            if (arg1 >= 0 && arg1 < NUM_PERF_COUNTERS)
                REGISTERS[REG_PERF0_SEL + arg1] = arg2;

            return 0;

        case 8: // unsigned int read_perf_counter(int counter)
            if (arg1 >= 0 && arg1 < NUM_PERF_COUNTERS)
                return REGISTERS[REG_PERF0_VAL + arg1];
            else
                return 0;

        default:
            panic("Unknown syscall %d\n", arg0);
    }
}
