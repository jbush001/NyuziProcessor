// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 

#ifndef __SSEG_H
#define __SSEG_H

//  aaa
//  f b
//  ggg
//  e c
//  ddd

const int kSegA = 1;
const int kSegB = 2;
const int kSegC = 4;
const int kSegD = 8;
const int kSegE = 16;
const int kSegF = 32;
const int kSegG = 64;

static char digits[] = {
	~(kSegA | kSegB | kSegC | kSegD | kSegE | kSegF), // 0
	~(kSegB | kSegC), // 1
	~(kSegA | kSegB | kSegD | kSegE | kSegG), // 2
	~(kSegA | kSegB | kSegC | kSegD | kSegG), // 3
	~(kSegB | kSegC | kSegF | kSegG), // 4
	~(kSegA | kSegC | kSegD | kSegF | kSegG), // 5
	~(kSegA | kSegF | kSegG | kSegE | kSegC | kSegG), // 6
	~(kSegA | kSegB | kSegC), // 7
	~(kSegA | kSegB | kSegC | kSegD | kSegE | kSegF | kSegG), // 8
	~(kSegA | kSegB | kSegC | kSegD | kSegF | kSegG), // 9
	~(kSegA | kSegF | kSegB | kSegG | kSegE | kSegC), // A
	~(kSegF | kSegG | kSegE | kSegC | kSegD), // b
	~(kSegA | kSegF | kSegE | kSegD), // C
	~(kSegB | kSegG | kSegE | kSegC | kSegD), // d
	~(kSegA | kSegF | kSegG | kSegE | kSegD), // E
	~(kSegA | kSegF | kSegG | kSegE) // F	
};

volatile unsigned int * const kLedRegBase = (volatile unsigned int*) 0xffff0008;

#endif

