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

int kprintf(const char *format, ...);
void *memcpy(void *dest, const void *src, unsigned int length);
void panic(const char *fmt, ...);
void *memset(void *dest, int value, unsigned int length);

#define assert(cond) if (!(cond)) { panic("ASSERT FAILED: %s:%d: %s\n", __FILE__, __LINE__, \
		#cond); }

