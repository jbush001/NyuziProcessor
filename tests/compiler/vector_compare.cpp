// 
// Copyright 2013 Jeff Bush
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

#include "output.h"

typedef int veci16 __attribute__((__vector_size__(16 * sizeof(int))));

Output output;

const veci16 kVecA = { 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4 };
const veci16 kVecB = { 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4 };

int main()
{
	output << (kVecA > kVecB);
  // CHECK: 0x00000000 0x00000000 0x00000000 0x00000000 
  // CHECK: 0xffffffff 0x00000000 0x00000000 0x00000000 
  // CHECK: 0xffffffff 0xffffffff 0x00000000 0x00000000 
  // CHECK: 0xffffffff 0xffffffff 0xffffffff 0x00000000 

	output << (kVecA >= kVecB);
  // CHECK: 0xffffffff 0x00000000 0x00000000 0x00000000 
  // CHECK: 0xffffffff 0xffffffff 0x00000000 0x00000000 
  // CHECK: 0xffffffff 0xffffffff 0xffffffff 0x00000000 
  // CHECK: 0xffffffff 0xffffffff 0xffffffff 0xffffffff 

	output << (kVecA < kVecB);
  // CHECK: 0x00000000 0xffffffff 0xffffffff 0xffffffff 
  // CHECK: 0x00000000 0x00000000 0xffffffff 0xffffffff 
  // CHECK: 0x00000000 0x00000000 0x00000000 0xffffffff 
  // CHECK: 0x00000000 0x00000000 0x00000000 0x00000000 

	output << (kVecA <= kVecB);
  // CHECK: 0xffffffff 0xffffffff 0xffffffff 0xffffffff 
  // CHECK: 0x00000000 0xffffffff 0xffffffff 0xffffffff 
  // CHECK: 0x00000000 0x00000000 0xffffffff 0xffffffff 
  // CHECK: 0x00000000 0x00000000 0x00000000 0xffffffff 
}
