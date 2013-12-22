// 
// Copyright 2011-2013 Jeff Bush
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

#include "LinearInterpolator.h"
#include "Debug.h"

using namespace render;

LinearInterpolator::LinearInterpolator()
{
}

void LinearInterpolator::init(float x0, float y0, float c0, float x1, 
	float y1, float c1, float x2, float y2, float c2)
{
	float a = x1 - x0;
	float b = y1 - y0;
	float c = x2 - x0;
	float d = y2 - y0;
	float e = c1 - c0;
	float f = c2 - c0;

	// Determine partial derivatives using Cramer's rule
	float detA = a * d - b * c;
	fGx = (e * d - b * f) / detA;
	fGy = (a * f - e * c) / detA;
	fC00 = c0 + -x0 * fGx + -y0 * fGy;	// Compute c at 0, 0
}

