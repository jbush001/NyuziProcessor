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

//
// Simple fibonacci sum
//

int fib(int n)
{
	if (n < 2)
		return n;
	else 
		return fib(n - 1) + fib(n - 2);
}

int main()
{
	for (int i = 0; i < 10; i++)
		printf("0x%08x\n", fib(i));	
		
	// CHECK: 0x00000000
	// CHECK: 0x00000001
	// CHECK: 0x00000001
	// CHECK: 0x00000002
	// CHECK: 0x00000003
	// CHECK: 0x00000005
	// CHECK: 0x00000008
	// CHECK: 0x0000000d
	// CHECK: 0x00000015
	
	return 0;
}
