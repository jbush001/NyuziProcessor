
#ifndef __UTILS_H
#define __UTILS_H

extern "C" {
	void memcpy(void *dest, const void *src, unsigned int length);
	void memset(void *dest, int value, unsigned int length);
};

void udiv(unsigned int dividend, unsigned int divisor, unsigned int &outQuotient, 
	unsigned int &outRemainder);
	
#endif
