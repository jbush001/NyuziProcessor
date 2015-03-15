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
#include <stdint.h>

void printVector(veci16_t v)
{
	for (int lane = 0; lane < 16; lane++)
		printf("0x%08x ", v[lane]);
}

int main()
{
	veci16_t value = __builtin_nyuzi_makevectori(0);
	for (int mask = 0xffff; mask; mask >>= 1)
		value = __builtin_nyuzi_vector_mixi(mask, value + __builtin_nyuzi_makevectori(1), value);

	printVector(value);

	// CHECK: 0x00000001
	// CHECK: 0x00000002
	// CHECK: 0x00000003
	// CHECK: 0x00000004
	// CHECK: 0x00000005
	// CHECK: 0x00000006
	// CHECK: 0x00000007
	// CHECK: 0x00000008
	// CHECK: 0x00000009
	// CHECK: 0x0000000a
	// CHECK: 0x0000000b
	// CHECK: 0x0000000c
	// CHECK: 0x0000000d
	// CHECK: 0x0000000e
	// CHECK: 0x0000000f
	// CHECK: 0x00000010
}
