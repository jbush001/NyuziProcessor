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
#define STRIDE 256
#define FNV_OFFSET_BASIS 2166136261
#define FNV_PRIME 16777619
#define RNG_MULTIPLIER 1664525
#define RNG_INCREMENT 1013904223

//
// This test ensures multiple threads can run in different address spaces
// and have their pages mapped properly. It writes a pseudorandom pattern
// across a chunk of memory, computing a checksum as it goes. It then reads
// it back to ensure the checksum matches. The random pattern is seeded by
// the thread ID so each one will have a different pattern. If it is successful,
// it prints '+', otherwise it prints '-'.
//

extern int __syscall(int n, int arg0, int arg1, int arg2, int arg3, int arg4);

void printstr(const char *str, int length)
{
    __syscall(0, (int) str, length, 0, 0, 0);
}

int getthid(void)
{
    return __syscall(2, 0, 0, 0, 0, 0);
}

int main()
{
    // Causes each process to generate a different sequence
    unsigned int rand_seed = getthid();
    unsigned int chksum1 = FNV_OFFSET_BASIS;    // FNV-1 hash
    unsigned int chksum2 = FNV_OFFSET_BASIS;
    unsigned char *area_base = (unsigned char*) __syscall(6, 0, ALLOC_SIZE, 2, (int) "alloc_area", 2);
    int i;

    for (i = 0; i < ALLOC_SIZE; i += STRIDE)
    {
        rand_seed = rand_seed * RNG_MULTIPLIER + RNG_INCREMENT;
        area_base[i] = rand_seed & 0xff;
        chksum1 = (chksum1 ^ (rand_seed & 0xff)) * FNV_PRIME;
    }

    for (i = 0; i < ALLOC_SIZE; i += STRIDE)
        chksum2 = (chksum2 ^ area_base[i]) * FNV_PRIME;

    if (chksum1 == chksum2)
        printstr("+", 1);
    else
        printstr("-", 1);
}
