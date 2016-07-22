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

#define ALLOC_SIZE 0x40000

extern int __syscall(int n, int arg0, int arg1, int arg2, int arg3, int arg4);

void exec(const char *path)
{
    __syscall(3, (int) path, 0, 0, 0, 0);
}

void printstr(const char *str, int length)
{
    __syscall(0, (int) str, length, 0, 0, 0);
}

int main()
{
    int i;
    unsigned int rand_seed;
    unsigned int chksum1;
    unsigned int chksum2;
    unsigned char *area_base;

    exec("program2.elf");

    rand_seed = 1;
    chksum1 = 2166136261;  // FNV-1 hash
    chksum2 = 2166136261;
    area_base = (unsigned char*) __syscall(6, 0, ALLOC_SIZE, 2, (int) "alloc_area", 2);
    for (i = 0; i < ALLOC_SIZE; i++)
    {
        rand_seed = rand_seed * 1103515245 + 12345; // Note different generator than process 2
        area_base[i] = rand_seed & 0xff;
        chksum1 = (chksum1 ^ (rand_seed & 0xff)) * 16777619;
    }

    for (i = 0; i < ALLOC_SIZE; i++)
        chksum2 = (chksum2 ^ area_base[i]) * 16777619;

    if (chksum1 == chksum2)
        printstr("A", 1);
    else
        printstr("X", 1);
}
