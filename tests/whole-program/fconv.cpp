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

#include <stdint.h>
#include <stdio.h>

// Test floating point conversions, unsigned and signed, vector and scalar

// Using globals should ensure the values can't be optimized into
// constants below
float a = 123.0;
int b = 79;
unsigned int c = 24;

// XXX should have a large integer too, but my printf is too primitive to handle these
vecu16_t d = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
veci16_t e = { 1, -1, 0x7fffffff, -0x7fffffff, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15, 16 };
vecf16_t f = { 1, -1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };

int main()
{
	vecf16_t g = __builtin_convertvector(d, vecf16_t);
	vecf16_t h = __builtin_convertvector(e, vecf16_t);
	veci16_t i = __builtin_convertvector(f, veci16_t);
	vecu16_t j = __builtin_convertvector(f, vecu16_t);

	// Float to int
	printf("0x%08x\n", (int) a);			// CHECK: 0x0000007b
	printf("0x%08x\n", (unsigned int) a);	// CHECK: 0x0000007b
	printf("0x%08x\n", i[0]);		// CHECK: 0x00000001
	printf("0x%08x\n", i[1]);		// CHECK: 0xffffffff
	printf("0x%08x\n", j[0]);		// CHECK: 0x00000001
	printf("0x%08x\n", j[1]);		// CHECK: 0xffffffff

  	// Int to float
	printf("%g\n", (float) b);	// CHECK: 79.0
	printf("%g\n", (float) c);  // CHECK: 24.0
	printf("%g\n", g[0]);  // CHECK: 1.0
	printf("%g\n", g[1]);  // CHECK: 2.0
	printf("%g\n", h[0]);  // CHECK: 1.0
	printf("%g\n", h[1]);  // CHECK: -1.0
}
