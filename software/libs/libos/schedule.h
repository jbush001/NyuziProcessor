//
// Copyright 2011-2015 Jeff Bush
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

typedef void (*parallel_func_t)(void *context, int index);

#ifdef __cplusplus
extern "C" {
#endif

// parallel_spawn should only be called from the main thread. It waits for
// all jobs to complete before returning.
void parallel_execute(parallel_func_t func, void *context, int num_elements);

// main should call this function for all threads other than 0.
void worker_thread(void) __attribute__ ((noreturn));

void start_all_threads(void);

#ifdef __cplusplus
}
#endif

