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
#include <setjmp.h>

static jmp_buf buf;

int main(int argc, const char *argv[])
{
	int ret = setjmp(buf);
	if (ret) 
		printf("returned from setjmp: %d\n", ret);
	else
	{
		printf("Going to call longjmp\n");
		longjmp(buf, 17);
	}

	return 0;
}


// CHECK: Going to call longjmp
// CHECK: returned from setjmp: 17
