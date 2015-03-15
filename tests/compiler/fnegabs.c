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

void __attribute__ ((noinline)) printNeg(float f)
{
	printf("#%g", -f);
}

void __attribute__ ((noinline)) printFabs(float f)
{
	printf("#%g", fabs(f));
}

int main()
{
	printNeg(-17.0f);	// CHECK: #17.0
	printNeg(19.0f);	// CHECK: #-19.0
	printFabs(-23.0f);	// CHECK: #23.0
	printFabs(25.0f);	// CHECK: #25.0
}
