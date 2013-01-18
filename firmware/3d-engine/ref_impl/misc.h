#ifndef __MISC_H
#define __MISC_H


// Count leading zeroes
inline int clz(unsigned int value)
{
	int index;
	
	for (index = 31; index >= 0; index--)
	{
		if (value & (1 << index))
			return index;
	}
	
	return -1;
}

#endif
