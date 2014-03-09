// 
// Copyright 2014 Jeff Bush
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

Output output;

void varArgFunc(int numParams, ...)
{
	__builtin_va_list ap;
	__builtin_va_start(ap, numParams);

	for (int i = 0; i < numParams; i++)
		output << __builtin_va_arg(ap, int);
	
	__builtin_va_end(ap);
}

int main()
{
	varArgFunc(4, 0xaaaaaaaa, 0xbbbbbbbb, 0xcccccccc, 0xdddddddd);

	// CHECK: 0xaaaaaaaa
	// CHECK: 0xbbbbbbbb
	// CHECK: 0xcccccccc
	// CHECK: 0xdddddddd
}
 
