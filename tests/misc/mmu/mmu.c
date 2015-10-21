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

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define COPY_SIZE 0x10000

extern void tlb_miss_handler();

// This address is normally out of range, but the MMU maps it to 0x100000.
char *tmp = (char*) 0x80100000;

int main(int argc, const char *argv[])
{
	// Set up miss handler
	__builtin_nyuzi_write_control_reg(7, tlb_miss_handler);
	__builtin_nyuzi_write_control_reg(4, (1 << 2));	// Turn on MMU in flags
	strcpy(tmp, "Test String");
	asm("dflush %0" : : "s" (tmp));
	return 0;
}
