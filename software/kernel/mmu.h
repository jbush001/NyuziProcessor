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

#pragma once

#define PAGE_SIZE 0x1000
#define PAGE_ALIGN(x) (x & ~(PAGE_SIZE - 1))

#define PAGE_PRESENT 1
#define PAGE_WRITABLE 2
#define PAGE_EXECUTABLE 4
#define PAGE_SUPERVISOR 8
#define PAGE_GLOBAL 16

void map_page(unsigned int va, unsigned int pa);
unsigned int allocate_page(void);
