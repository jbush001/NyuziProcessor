/*
Copyright (C) 1996-1997 Id Software, Inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

*/

#include <stdio.h>

void simple_crypt(char *buf, int len)
{
	while (len--)
		*buf++ ^= 0xff;
}

char prespawn_name[] = 
	{ 'p'^0xff, 'r'^0xff, 'e'^0xff, 's'^0xff, 'p'^0xff, 'a'^0xff, 'w'^0xff, 'n'^0xff,
		' '^0xff, '%'^0xff, 'i'^0xff, ' '^0xff, '0'^0xff, ' '^0xff, '%'^0xff, 'i'^0xff, 0 };

int main()
{
	simple_crypt(prespawn_name,  sizeof(prespawn_name)  - 1);
	for (int i = 0; i < sizeof(prespawn_name); i++)
		printf("%02x ", prespawn_name[i]);
	
	printf("\n"); 
	// CHECK: 70 72 65 73 70 61 77 6e 20 25 69 20 30 20 25 69 00
	return 0;
}
