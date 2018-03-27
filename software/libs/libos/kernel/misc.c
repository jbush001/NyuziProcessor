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

#include <time.h>
#include "nyuzi.h"
#include "unistd.h"

#define MAX_THREADS 64

int __errno_array[MAX_THREADS];

int *__errno_ptr(void)
{
    return &__errno_array[get_current_thread_id()];
}

int usleep(useconds_t delay)
{
    (void) delay;

    return -1;
}

void exit(int status)
{
    thread_exit();
}


