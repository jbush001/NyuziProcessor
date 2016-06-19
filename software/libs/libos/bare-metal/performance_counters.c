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

#include "performance_counters.h"
#include "registers.h"

void set_perf_counter_event(int counter, enum performance_event event)
{
    if (counter >= 0 && counter < NUM_COUNTERS)
        REGISTERS[REG_PERF0_SEL + counter] = event;
}

unsigned int read_perf_counter(int counter)
{
    if (counter >= 0 && counter < NUM_COUNTERS)
        return REGISTERS[REG_PERF0_VAL + counter];
    else
        return 0;
}

