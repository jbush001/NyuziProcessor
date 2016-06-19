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
#include "registers.h"
#include "unistd.h"

#define CLOCKS_PER_US 50

int usleep(useconds_t delay)
{
    int expire = __builtin_nyuzi_read_control_reg(6) + delay * CLOCKS_PER_US;
    while (__builtin_nyuzi_read_control_reg(6) < expire)
        ;

    return 0;
}

void exit(int status)
{
    (void) status;

    REGISTERS[REG_THREAD_HALT] = 0xffffffff;
    while (1)
        ;
}
