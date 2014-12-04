#ifndef __STDIO_INTERNAL_H
#define __STDIO_INTERNAL_H

struct __file
{
	char *write_buf;
    int write_offset;
	int write_buf_len;
};

#endif

	