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

extern int __syscall(int n, int arg0, int arg1, int arg2, int arg3, int arg4);

unsigned int strlen(const char *str)
{
    unsigned int len = 0;
    while (*str++)
        len++;

    return len;
}

void printstr(const char *str)
{
    __syscall(0, (int) str, strlen(str), 0, 0, 0);
}

void __attribute__((noreturn)) exit(int code)
{
    __syscall(4, code, 0, 0, 0, 0);
    for (;;);
}

int main()
{
    printstr("Goodbye World\n");
    exit(1);
}
