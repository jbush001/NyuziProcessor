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
	10.0, 10.0, -10.0,   0.0, 0.0,
	-10.0, 10.0, -10.0,  1.0, 0.0,
	-10.0, -10.0, -10.0, 1.0, 1.0,
	10.0, -10.0, -10.0,  0.0, 1.0,

	// Right side
	10.0, -10.0, -10.0,  0.0, 0.0,
	10.0, -10.0, 10.0,   1.0, 0.0,
	10.0, 10.0, 10.0,    1.0, 1.0,
	10.0, 10.0, -10.0,   0.0, 1.0,

	// Left side
	-10.0, -10.0, -10.0, 0.0, 1.0,
	-10.0, 10.0, -10.0,  0.0, 0.0,
	-10.0, 10.0, 10.0,   1.0, 0.0,
	-10.0, -10.0, 10.0,  1.0, 1.0,

	// Back
	10.0, -10.0, 10.0,   0.0, 0.0,
	-10.0, -10.0, 10.0,  1.0, 0.0,
	-10.0, 10.0, 10.0,   1.0, 1.0,
	10.0, 10.0, 10.0,    0.0, 1.0,

	// Top
	-10.0, -10.0, -10.0, 0.0, 0.0,
	-10.0, -10.0, 10.0,  1.0, 0.0,
	10.0, -10.0, 10.0,   2.0, 1.0,
	10.0, -10.0, -10.0,  0.0, 1.0,

	// Bottom
	10.0, 10.0, -10.0,   0.0, 0.0,
	10.0, 10.0, 10.0,    1.0, 0.0,
	-10.0, 10.0, 10.0,   1.0, 1.0,
	-10.0, 10.0, -10.0,  0.0, 1.0
};

const int kNumRoomIndices = 36;
const int kRoomIndices[] = {
	0, 1, 2, 
	2, 3, 0,
	4, 5, 6,
	6, 7, 4,
	8, 9, 10,
	10, 11, 8,
	12, 13, 14,
	14, 15, 12,
	16, 17, 18,
	18, 19, 16,
	20, 21, 22,
	22, 23, 20
};
