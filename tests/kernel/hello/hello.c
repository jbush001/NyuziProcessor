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

void printstr(const char *str)
{
    __syscall(0, (int) str, 0, 0, 0, 0);
}

int getthid()
{
    return __syscall(2, 0, 0, 0, 0, 0);
}

int spawn_thread(void (*func)(void*), void *param)
{
    return __syscall(1, (int) func, (int) param, 0, 0, 0);
}

int global_count;

void thread_start()
{
    int th = getthid();
    char c[2];
    c[0] = th + 'A';
    c[1] = '\0';
    for (;;)
        printstr(c);
}

int main()
{
    int i;

    for (global_count = 0; global_count < 20; global_count++)
    {
        printstr("Hello ");
        printstr("World\n");
    }

    // Now spawn some other threads
    for (i = 0; i < 10; i++)
        spawn_thread(thread_start, 0);
}
