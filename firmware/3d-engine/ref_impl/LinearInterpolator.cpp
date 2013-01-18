#include <stdio.h>
#include "LinearInterpolator.h"

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

	// Determine gradients using Cramer's rule
	float detA = a * d - b * c;
	fGx = float(e * d - b * f) / detA;
	fGy = float(a * f - e * c) / detA;
	fC00 = c0 + -x0 * fGx + -y0 * fGy;	// Compute c at 0, 0
}

vec16<float> LinearInterpolator::getValueAt(vec16<float> x, vec16<float> y) const
{
	return x * fGx + y * fGy + fC00;
}
