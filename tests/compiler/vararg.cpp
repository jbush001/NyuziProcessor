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


#include <stdio.h>
#include <stdarg.h>

void __attribute__ ((noinline)) varArgFunc(int foo, ...)
{
	__builtin_va_list ap;
	__builtin_va_start(ap, foo);
	printf("foo = 0x%08x\n", foo);
	printf("0. 0x%08x\n", __builtin_va_arg(ap, int));
	printf("1. 0x%08x\n", __builtin_va_arg(ap, unsigned int));
	printf("2. 0x%08x\n", __builtin_va_arg(ap, short));
	printf("3. 0x%08x\n", __builtin_va_arg(ap, unsigned short));
	printf("4. 0x%08x\n", __builtin_va_arg(ap, char));
	printf("5. 0x%08x\n", __builtin_va_arg(ap, unsigned char));
	printf("6. %s\n", __builtin_va_arg(ap, const char*));
	__builtin_va_end(ap);
}

int main()
{
	varArgFunc(0x3659487d, 0x4f5b256, 0xacb0f292, 0x1f4d9c8d, 0xd5fc06d3, 
		0xb201c748, 0xb3f71cc2, "test string");

	// CHECK: foo = 0x3659487d
	// CHECK: 0. 0x04f5b256
	// CHECK: 1. 0xacb0f292
	// CHECK: 2. 0xffff9c8d
	// CHECK: 3. 0x000006d3
	// CHECK: 4. 0x00000048
	// CHECK: 5. 0x000000c2
	// CHECK: 6. test string
}
 
