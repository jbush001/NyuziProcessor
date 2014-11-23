#include <stdio.h>

typedef unsigned int fixed_t;

fixed_t multiplyFixed(fixed_t a, fixed_t b)
{
    return ((long long) a * (long long) b) >> 16;
}

int main(int argc, const char *argv[])
{
	printf("%08x\n", multiplyFixed(0xffffe350, 0x009fe0c6)); // CHECK: e0b4157f
}
