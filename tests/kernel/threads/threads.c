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

//
// Spawn a bunch of user space threads. This exercises:
// - Returning value from a syscall (getthid)
// - Syscalls from multiple threads simultaneously.
// - Spawning a new user space thread.
// - Interrupts and preemptive task switching
//

extern int __syscall(int n, int arg0, int arg1, int arg2, int arg3, int arg4);

void printstr(const char *str, int length)
{
    __syscall(0, (int) str, length, 0, 0, 0);
}

int getthid()
{
    return __syscall(2, 0, 0, 0, 0, 0);
}

int spawn_thread(const char *name, void (*func)(void*), void *param)
{
    return __syscall(1, (int) name, (int) func, (int) param, 0, 0);
}

void thread_start()
{
    int th = getthid();
    char c = th + 'A';
    for (;;)
        printstr(&c, 1);
}

int main()
{
    int i;

    for (i = 0; i < 10; i++)
        spawn_thread("spinner thread", thread_start, 0);
}
