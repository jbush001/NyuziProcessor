#include <stdio.h>
#include <string.h>

#define GUARD_SIZE 64
#define GUARD_FILL 0x66
#define UNINIT_FILL 0x55
#define DEST_FILL 0xcc


unsigned char guard1[GUARD_SIZE] __attribute__ ((aligned (64)));
unsigned char dest[256] __attribute__ ((aligned (64)));
unsigned char guard2[GUARD_SIZE] __attribute__ ((aligned (64)));

int __attribute__ ((noinline)) memset_trial(int offset, int length)
{
	memset(dest, UNINIT_FILL, sizeof(dest));
	memset(dest + offset, DEST_FILL, length);

	for (int i = 0; i < sizeof(dest); i++)
	{
		if (i >= offset && i < offset + length)
		{
			if (dest[i] != DEST_FILL)
			{
				printf("mismatch @%d (%d,%d) %02x\n", i, offset, length,
					dest[i]);
				return 0;
			}
		}
		else if (dest[i] != UNINIT_FILL)
		{
			printf("clobber @%d (%d,%d) %02x\n", i, offset, length, dest[i]);
			return 0;
		}
	}

	for (int i = 0; i < GUARD_SIZE; i++)
	{
		if (guard1[i] != GUARD_FILL || guard2[i] != GUARD_FILL)
		{
			printf("guard is clobbered\n");
			return 1;
		}
	}

	return 1;
}

const int kOffsets[] = {
	0, 1, 2, 3, 4, 5, 6, 7, 8, 
	62, 63, 64, 65, 66
};

const int kLengths[] = {
	1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17,
	31, 32, 33, 63, 64, 65, 127, 128, 129, 192
};

int main()
{
	for (auto offset : kOffsets)
	{
		for (auto length : kLengths)
		{
			if (!memset_trial(offset, length))
				goto done;
		}
	}
	
	printf("PASS\n");	// CHECK: PASS

done:
	return 0;
}