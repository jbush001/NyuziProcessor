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

const veci16_t kVecA = { 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4 };
const veci16_t kVecB = { 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4 };

void __attribute__ ((noinline)) printVector(veci16_t v)
{
	for (int lane = 0; lane < 16; lane++)
		printf("%d ", v[lane]);
}

int main()
{
	printVector(kVecA > kVecB);
  // CHECK: 0 0 0 0 
  // CHECK: -1 0 0 0 
  // CHECK: -1 -1 0 0 
  // CHECK: -1 -1 -1 0 

	printVector(kVecA >= kVecB);
  // CHECK: -1 0 0 0 
  // CHECK: -1 -1 0 0 
  // CHECK: -1 -1 -1 0 
  // CHECK: -1 -1 -1 -1 

	printVector(kVecA < kVecB);
  // CHECK: 0 -1 -1 -1 
  // CHECK: 0 0 -1 -1 
  // CHECK: 0 0 0 -1 
  // CHECK: 0 0 0 0 

	printVector(kVecA <= kVecB);
  // CHECK: -1 -1 -1 -1 
  // CHECK: 0 -1 -1 -1 
  // CHECK: 0 0 -1 -1 
  // CHECK: 0 0 0 -1 
}
