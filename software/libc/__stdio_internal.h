#ifndef __STDIO_INTERNAL_H
#define __STDIO_INTERNAL_H

#include "libc.h"

struct __file
{
	char *write_buf;
	int write_buf_len;
};

#endif

	