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

void __attribute__ ((noinline)) manual_switch(int value)
{
	static void *label_array[] = {
		&&label4,
		&&label2,
		&&label3,
		&&label1
	};
	
	goto *label_array[value];

label1:
	printf("label1");
	return;

label2:
	printf("label2");
	return;

label3:
	printf("label3");
	return;

label4:
	printf("label4");
}


int main()
{
	manual_switch(0);	// CHECK: label4
	manual_switch(1);	// CHECK: label2
	manual_switch(2);	// CHECK: label3
	manual_switch(3);	// CHECK: label1
}
