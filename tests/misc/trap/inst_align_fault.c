//
// Copyright 2015 Jeff Bush
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

//
// Test that unaligned instruction properly raises a fault
//

typedef void (*func_ptr_t)();

void faultHandler(void)
{
    printf("FAULT %d\n", __builtin_nyuzi_read_control_reg(3));
    exit(0);
}

void dummyFunc(void)
{
    printf("FAIL: called dummy_func\n");
}

int main(int argc, const char *argv[])
{
    func_ptr_t func_ptr;

    __builtin_nyuzi_write_control_reg(1, faultHandler);

    func_ptr = (func_ptr_t) (((unsigned int) &dummyFunc) + 1);
    (*func_ptr)();
    // CHECK: FAULT 4

    printf("should_not_be_here\n"); // CHECKN: should_not_be_here

    return 1;
}

