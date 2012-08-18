// 
// Copyright 2011-2012 Jeff Bush
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

#include <stdio.h>

class LinearInterpolator 
{
public:
	LinearInterpolator(float x0, float y0, float c0, float x1, 
		float y1, float c1, float x2, float y2, float c2);
	float getValueAt(float x, float y);
	
private:
	float fGx;
	float fGy;
	float fC00;
};

class PerspectiveInterpolator
{
public:
	PerspectiveInterpolator(
		float x0, float y0, float z0, float c0,
		float x1, float y1, float z1, float c1,
		float x2, float y2, float z2, float c2);
	float getValueAt(float x, float y);

private:
	LinearInterpolator fCInterpolator;
	LinearInterpolator fZInterpolator;
};

LinearInterpolator::LinearInterpolator(float x0, float y0, float c0, float x1, 
	float y1, float c1, float x2, float y2, float c2)
{
	float a = x1 - x0;
	float b = y1 - y0;
	float c = x2 - x0;
	float d = y2 - y0;
	float e = c1 - c0;
	float f = c2 - c0;
	float detA = a * d - b * c;
	fGx = float(e * d - b * f) / detA;
	fGy = float(a * f - e * c) / detA;
	fC00 = c0 + -x0 * fGx + -y0 * fGy;	// Compute c at 0, 0
}

float LinearInterpolator::getValueAt(float x, float y)
{
	return fC00 + x * fGx + y * fGy;
}

PerspectiveInterpolator::PerspectiveInterpolator(
	float x0, float y0, float z0, float c0,
	float x1, float y1, float z1, float c1,
	float x2, float y2, float z2, float c2)
	:	fCInterpolator(x0, y0, c0 / z0, x1, y1, c1 / z1, x2, y2, c2 / z2),
		fZInterpolator(x0, y0, 1.0 / z0, x1, y1, 1.0 / z1, x2, y2, 1.0 / z2)
{
}

float PerspectiveInterpolator::getValueAt(float x, float y)
{
	return fCInterpolator.getValueAt(x, y) / fZInterpolator.getValueAt(x, y);
}

int main(int argc, const char *argv[])
{
	PerspectiveInterpolator pi(5, 2, 3, 7, 10, 10, 4, 15, 2, 6, 5, 25);
	printf("%g\n", pi.getValueAt(5, 2));
	printf("%g\n", pi.getValueAt(10, 10));
	printf("%g\n", pi.getValueAt(2, 6));
	printf("%g\n", pi.getValueAt(6, 6));
}
