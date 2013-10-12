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

volatile int foo = 0x5a5a5a5a;
Output output;

int main()
{
	output << __sync_fetch_and_add(&foo, 1);	// CHECK: 0x5a5a5a5a
	output << __sync_add_and_fetch(&foo, 1);	// CHECK: 0x5a5a5a5c
	output << __sync_add_and_fetch(&foo, 1);	// CHECK: 0x5a5a5a5d
	output << __sync_fetch_and_add(&foo, 1);	// CHECK: 0x5a5a5a5d
	
	foo = 2;
	output << __sync_val_compare_and_swap(&foo, 2, 3);	// CHECK: 0x00000002
	output << __sync_val_compare_and_swap(&foo, 2, 4);  // CHECK: 0x00000003

	output << __sync_bool_compare_and_swap(&foo, 2, 10);  // CHECK: 0x00000000
	output << __sync_bool_compare_and_swap(&foo, 3, 10);  // CHECK: 0x00000001
	
	return 0;
}
