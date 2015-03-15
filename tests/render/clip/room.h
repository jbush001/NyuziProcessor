// 
// Copyright 2011-2015 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 


#pragma once

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
