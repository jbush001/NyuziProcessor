// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
// 

#include <stdio.h>
#include <setjmp.h>

static jmp_buf buf;

int main(int argc, const char *argv[])
{
	int ret = setjmp(buf);
	if (ret) 
		printf("returned from setjmp: %d\n", ret);
	else
	{
		printf("Going to call longjmp\n");
		longjmp(buf, 17);
	}

	return 0;
}


// CHECK: Going to call longjmp
// CHECK: returned from setjmp: 17
