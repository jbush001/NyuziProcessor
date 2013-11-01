
#define NUM_STRANDS 4

typedef int veci16 __attribute__((__vector_size__(16 * sizeof(int))));

const int kTransferSize = 0x100000;
void * const region1Base = (void*) 0x200000;
veci16 sum;

int main()
{
	veci16 *src = (veci16*) region1Base + __builtin_vp_get_current_strand();
		
	for (int i = 0; i < kTransferSize / (64 * 4); i++)
	{
		sum += *src;
		src += NUM_STRANDS;
	}
}


