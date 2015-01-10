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

void __attribute__ ((noinline)) printNeg(float f)
{
	printf("#%g", -f);
}

void __attribute__ ((noinline)) printFabs(float f)
{
	printf("#%g", fabs(f));
}

int main()
{
	printNeg(-17.0f);	// CHECK: #17.0
	printNeg(19.0f);	// CHECK: #-19.0
	printFabs(-23.0f);	// CHECK: #23.0
	printFabs(25.0f);	// CHECK: #25.0
}
