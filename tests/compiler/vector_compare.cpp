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

#include <libc.h>

const veci16 kVecA = { 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4 };
const veci16 kVecB = { 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4 };

void printVector(veci16 v)
{
	for (int lane = 0; lane < 16; lane++)
		printf("%d ", v[lane]);
}

int main()
{
	printVector(kVecA > kVecB);
  // CHECK: 0 0 0 0 
  // CHECK: -1 0 0 0 
  // CHECK: -1 -1 0 0 
  // CHECK: -1 -1 -1 0 

	printVector(kVecA >= kVecB);
  // CHECK: -1 0 0 0 
  // CHECK: -1 -1 0 0 
  // CHECK: -1 -1 -1 0 
  // CHECK: -1 -1 -1 -1 

	printVector(kVecA < kVecB);
  // CHECK: 0 -1 -1 -1 
  // CHECK: 0 0 -1 -1 
  // CHECK: 0 0 0 -1 
  // CHECK: 0 0 0 0 

	printVector(kVecA <= kVecB);
  // CHECK: -1 -1 -1 -1 
  // CHECK: 0 -1 -1 -1 
  // CHECK: 0 0 -1 -1 
  // CHECK: 0 0 0 -1 
}
