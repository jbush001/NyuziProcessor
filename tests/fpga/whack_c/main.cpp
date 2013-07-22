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
			for (int x = myStrandId * 16; x < 640; x += 64)
			{
				veci16 xv = kXOffsets + __builtin_vp_makevectori(x);
				veci16 yv = __builtin_vp_makevectori(y);
				veci16 fv = __builtin_vp_makevectori(frameNum);

				*ptr = (xv+fv)+xv+(xv^(yv+fv))+fv;
				ptr += 4;
			}
		}
	}

	return 0;
}
