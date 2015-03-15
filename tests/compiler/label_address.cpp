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

void __attribute__ ((noinline)) manual_switch(int value)
{
	static void *label_array[] = {
		&&label4,
		&&label2,
		&&label3,
		&&label1
	};
	
	goto *label_array[value];

label1:
	printf("label1");
	return;

label2:
	printf("label2");
	return;

label3:
	printf("label3");
	return;

label4:
	printf("label4");
}


int main()
{
	manual_switch(0);	// CHECK: label4
	manual_switch(1);	// CHECK: label2
	manual_switch(2);	// CHECK: label3
	manual_switch(3);	// CHECK: label1
}
