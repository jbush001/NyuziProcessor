//
// Copyright 2015-2016 Jeff Bush
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

extern unsigned int _end;

#define KERNEL_BASE 0xc0000000
#define KERNEL_END PAGE_ALIGN(((unsigned int) &_end) + 0xfff)
#define PHYS_MEM_ALIAS 0xc1000000
#define KERNEL_HEAP_BASE 0xd0000000
#define KERNEL_HEAP_SIZE 0x01000000
#define INITIAL_KERNEL_STACKS 0xfffe0000
#define KERNEL_STACK_SIZE 0x4000
#define DEVICE_REG_BASE 0xffff0000
