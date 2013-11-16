#include "output.h"

typedef int veci16 __attribute__((__vector_size__(16 * sizeof(int))));

Output output;

int main()
{
	veci16 kValues = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
	for (int mask = 0xffff; mask; mask >>= 1)
		kValues = __builtin_vp_blendi(mask, kValues + __builtin_vp_makevectori(1), kValues);

	output << kValues;

	// CHECK: 0x00000001
	// CHECK: 0x00000002
	// CHECK: 0x00000003
	// CHECK: 0x00000004
	// CHECK: 0x00000005
	// CHECK: 0x00000006
	// CHECK: 0x00000007
	// CHECK: 0x00000008
	// CHECK: 0x00000009
	// CHECK: 0x0000000a
	// CHECK: 0x0000000b
	// CHECK: 0x0000000c
	// CHECK: 0x0000000d
	// CHECK: 0x0000000e
	// CHECK: 0x0000000f
	// CHECK: 0x00000010
}
