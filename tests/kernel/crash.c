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

int main()
{
    // Access an invalid address (the lowest page in the address space is
    // unmapped to catch null pointer references). This should kill this
    // program.
    *((unsigned int*) 4) = 1;
}

// CHECK: user space thread 5 crashed
// CHECK: Page Fault @00000004 dcache store
// CHECK: init process has exited, shutting down
