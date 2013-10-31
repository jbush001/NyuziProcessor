
typedef int veci16 __attribute__((__vector_size__(16 * sizeof(int))));

const int kTransferSize = 0x100000;
void * const region1Base = (void*) 0x200000;
void * const region2Base = (void*) 0x300000;

int main()
{
	veci16 *dest = (veci16*) region1Base + __builtin_vp_get_current_strand();
	veci16 *src = (veci16*) region2Base + __builtin_vp_get_current_strand();
	veci16 values = __builtin_vp_makevectori(0xdeadbeef);
	
	for (int i = 0; i < kTransferSize / (64 * 4); i++)
		*dest++ = *src++;
}
