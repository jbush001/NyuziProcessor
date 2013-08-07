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

volatile int foo = 'a';

int main()
{
	*((unsigned int*) 0xFFFF0004) = __sync_fetch_and_add(&foo, 1);	// CHECK: a
	*((unsigned int*) 0xFFFF0004) = __sync_add_and_fetch(&foo, 1);	// CHECK: c
	*((unsigned int*) 0xFFFF0004) = __sync_add_and_fetch(&foo, 1);	// CHECK: d
	*((unsigned int*) 0xFFFF0004) = __sync_fetch_and_add(&foo, 1);	// CHECK: d

	return 0;
}
