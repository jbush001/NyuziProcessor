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


#include <math.h>

//
// Standard library math functions
//

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

float sqrtf(float value)
{
	return (float) sqrt(value);
}

float floorf(float value)
{
	return (int) value;
}
