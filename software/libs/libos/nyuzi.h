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

#define AREA_PLACE_EXACT 0
#define AREA_PLACE_SEARCH_DOWN 1
#define AREA_PLACE_SEARCH_UP 2

#define AREA_WIRED 1
#define AREA_WRITABLE 2
#define AREA_EXECUTABLE 4

int get_current_thread_id(void);
unsigned int get_cycle_count(void);
void *create_area(unsigned int address, unsigned int size, int placement,
                  const char *name, int flags);
int exec(const char *path);

#ifdef __cplusplus
}
#endif
