//
// Copyright 2016 Jeff Bush
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

#include <nyuzi.h>
#include <stdio.h>

//
// Pass an invalid user buffer to a syscall. Ensure this returns an error
// rather than crashing the kernel.
//

extern int __syscall(int n, int arg0, int arg1, int arg2, int arg3, int arg4);

int printstr(const char *str, int length)
{
    return __syscall(0, (int) str, length, 0, 0, 0);
}

int main()
{
    int retval;
    void *ptr;

    // The parameter to the first syscall is a null pointer, which will fail and
    // return an error. This should print a negative number.
    retval = printstr((char*) 0, 5);
    printf("printstr returned %d\n", retval);
    // CHECK: printstr returned -1

    // The name is invalid and will fail to copy. Ensure it returns 0.
    ptr = create_area(0, 0x1000, AREA_PLACE_SEARCH_UP, (char*) 1, AREA_WRITABLE);
    printf("create area returned %d\n", ptr);
    // CHECK: create area returned 0
}

// CHECK: init process has exited, shutting down
