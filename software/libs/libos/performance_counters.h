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

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#define NUM_COUNTERS 4

enum performance_event
{
    PERF_L2_WRITEBACK,
    PERF_L2_MISS,
    PERF_L2_HIT,
    PERF_STORE_ROLLBACK,
    PERF_STORE,
    PERF_INSTRUCTION_RETIRED,
    PERF_INSTRUCTION_ISSUED,
    PERF_ICACHE_MISS,
    PERF_ICACHE_HIT,
    PERF_ITLB_MISS,
    PERF_DCACHE_MISS,
    PERF_DCACHE_HIT,
    PERF_DTLB_MISS,
    PERF_UNCOND_BRANCH,
    PERF_COND_BRANCH_TAKEN,
    PERF_COND_BRANCH_NOT_TAKEN
};

void set_perf_counter_event(int counter, enum performance_event event);
unsigned int read_perf_counter(int counter);

#ifdef __cplusplus
}
#endif

