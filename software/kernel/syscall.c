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

int handle_syscall(int arg0, int arg1, int arg2, int arg3, int arg4,
    int arg5)
{
        switch (arg0)
        {
            case 0: // Print something
                // !!! Needs to do copy from user. Unsafe.
                kprintf("%s", arg1);
                return 0;

            case 1:
                spawn_user_thread(current_thread()->space, arg1, arg2);
                return 0;

            case 2: // Get thread ID
                return current_thread()->id;

            default:
                panic("Unknown syscall %d\n", arg0);
        }

    return -1;
}