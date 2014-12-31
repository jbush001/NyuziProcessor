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


const int kNumRoomVertices = 24;
const float kRoomVertices[] = {
	// Front face
	10.0, 2.0, -10.0,   0.0, 0.0,
	-10.0, 2.0, -10.0,  5.0, 0.0,
	-10.0, -2.0, -10.0, 5.0, 1.0,
	10.0, -2.0, -10.0,  0.0, 1.0,

	// Right side
	10.0, -2.0, -10.0,  0.0, 0.0,
	10.0, -2.0, 10.0,   5.0, 0.0,
	10.0, 2.0, 10.0,    5.0, 1.0,
	10.0, 2.0, -10.0,   0.0, 1.0,

	// Left side
	-10.0, -2.0, -10.0, 0.0, 1.0,
	-10.0, 2.0, -10.0,  0.0, 0.0,
	-10.0, 2.0, 10.0,   5.0, 0.0,
	-10.0, -2.0, 10.0,  5.0, 1.0,

	// Back
	10.0, -2.0, 10.0,   0.0, 0.0,
	-10.0, -2.0, 10.0,  5.0, 0.0,
	-10.0, 2.0, 10.0,   5.0, 1.0,
	10.0, 2.0, 10.0,    0.0, 1.0,

	// Top
	-10.0, -2.0, -10.0, 0.0, 0.0,
	-10.0, -2.0, 10.0,  5.0, 0.0,
	10.0, -2.0, 10.0,   5.0, 5.0,
	10.0, -2.0, -10.0,  0.0, 5.0,

	// Bottom
	10.0, 2.0, -10.0,   0.0, 0.0,
	10.0, 2.0, 10.0,    5.0, 0.0,
	-10.0, 2.0, 10.0,   5.0, 5.0,
	-10.0, 2.0, -10.0,  0.0, 5.0
};

const int kNumRoomIndices = 36;

// The order of indices is specifically chosen to hit all
// clip cases.
const int kRoomIndices[] = {
	0, 1, 2, 		// clip mask 6
	2, 3, 0,		// clip mask 1
	4, 5, 6,		// clip mask 0 (completely visible)
	6, 7, 4,		// clip mask 0
	8, 9, 10,		// clip mask 7 (completely hidden)
	10, 11, 8,		// clip mask 7
	12, 13, 14,		// clip mask 6
	14, 15, 12,		// clip mask 1
	17, 18, 16,		// clip mask 5
	19, 16,	18,		// clip mask 2
	20, 21, 22,		// clip mask 4
	22, 23, 20		// clip mask 3
};
