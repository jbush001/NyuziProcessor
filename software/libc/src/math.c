// 
// Copyright (C) 2014 Jeff Bush
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

#include <math.h>

//
// Standard library math functions
//

int abs(int value)
{
	if (value < 0)
		return -value;
	
	return value;
}

double fmod(double val1, double val2)
{
	int whole = val1 / val2;
	return val1 - (whole * val2);
}

//
// Use taylor series to approximate sine
//   x**3/3! + x**5/5! - x**7/7! ...
//

const int kNumTerms = 7;

const double denominators[] = { 
	0.166666666666667f, 	// 1 / 3!
	0.008333333333333f,		// 1 / 5!
	0.000198412698413f,		// 1 / 7!
	0.000002755731922f,		// 1 / 9!
	2.50521084e-8f,			// 1 / 11!
	1.6059044e-10f,			// 1 / 13!
	7.6471637e-13f			// 1 / 15!
};

double sin(double angle)
{
	// More accurate if the angle is smaller. Constrain to 0-M_PI*2
	angle = fmod(angle, M_PI * 2.0f);

	double angleSquared = angle * angle;
	double numerator = angle;
	double result = angle;
	
	for (int i = 0; i < kNumTerms; i++)
	{
		numerator *= angleSquared;		
		double term = numerator * denominators[i];
		if (i & 1)
			result += term;
		else
			result -= term;
	}
	
	return result;
}

double cos(double angle)
{
	return sin(angle + M_PI * 0.5f);
}

double sqrt(double value)
{
	double guess = value;
	for (int iteration = 0; iteration < 10; iteration++)
		guess = ((value / guess) + guess) / 2.0f;

	return guess;
}
