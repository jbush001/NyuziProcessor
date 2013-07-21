typedef int veci16 __attribute__((__vector_size__(16 * sizeof(int))));

veci16* const kFrameBufferAddress = (veci16*) 0x10000000;
const veci16 kXOffsets = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };

int main()
{
	int myStrandId = __builtin_vp_get_current_strand();
	for (int frameNum = 0; ; frameNum++)
	{
		veci16 *ptr = kFrameBufferAddress + myStrandId;
		for (int y = 0; y < 480; y++)
		{
			for (int x = 0; x < 640; x += 64)
			{
				veci16 xValues = kXOffsets + __builtin_vp_makevectori(x);
				*ptr = ((xValues + __builtin_vp_makevectori(y))
					^ xValues) + __builtin_vp_makevectori(frameNum);
				ptr += 4;
			}
		}
	}

	return 0;
}
