#include <stdio.h>
#include <string.h>

#define GUARD_SIZE 64
#define GUARD_FILL 0xa5
#define DEST_FILL 0xcc

unsigned char guard1[GUARD_SIZE] __attribute__ ((aligned (64)));
unsigned char source[256] __attribute__ ((aligned (64)));
unsigned char guard2[GUARD_SIZE] __attribute__ ((aligned (64)));
unsigned char dest[256] __attribute__ ((aligned (64)));
unsigned char guard3[GUARD_SIZE] __attribute__ ((aligned (64)));

int __attribute__ ((noinline)) memcpy_trial(int destOffset, int sourceOffset, int length)
{
	memset(dest, DEST_FILL, sizeof(dest));
	memcpy(dest + destOffset, source + sourceOffset, length);
	for (int i = 0; i < sizeof(dest); i++)
	{
		if (i >= destOffset && i < destOffset + length)
		{
			if (dest[i] != source[i - destOffset + sourceOffset])
			{
				printf("mismatch @%d (%d,%d,%d) %02x %02x\n", i, destOffset, sourceOffset, length,
					dest[i], source[i - destOffset + sourceOffset]);
				return 0;
			}
		}
		else if (dest[i] != DEST_FILL)
		{
			printf("clobber @%d (%d,%d,%d) %02x\n", i, destOffset, sourceOffset, length,
				dest[i]);
			return 0;
		}
	}

	for (int i = 0; i < GUARD_SIZE; i++)
	{
		if (guard1[i] != GUARD_FILL || guard2[i] != GUARD_FILL || guard3[i] != GUARD_FILL)
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
	for (int i = 0; i < sizeof(source); i++)
		source[i] = i ^ 0x67;
	
	memset(guard1, GUARD_FILL, GUARD_SIZE);
	memset(guard2, GUARD_FILL, GUARD_SIZE);
	memset(guard3, GUARD_FILL, GUARD_SIZE);

	for (auto sourceOffset : kOffsets)
	{
		for (auto destOffset : kOffsets)
		{
			for (auto length : kLengths)
			{
				if (!memcpy_trial(destOffset, sourceOffset, length))
					goto done;
			}
		}
	}
	
	printf("PASS\n");	// CHECK: PASS

done:
	return 0;
}