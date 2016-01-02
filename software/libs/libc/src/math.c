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
//   x - x**3/3! + x**5/5! - x**7/7! ...
//

static const int kNumTerms = 6;

static const double kDenominators[] = {
    -0.166666666666667f,  // 1 / 3!
    0.008333333333333f,   // 1 / 5!
    -0.000198412698413f,  // 1 / 7!
    0.000002755731922f,	  // 1 / 9!
    -2.50521084e-8f,      // 1 / 11!
    1.6059044e-10f        // 1 / 13!
};

double sin(double angle)
{
    // The approximation begins to diverge past 0-pi/2. To prevent
    // discontinuities, mirror or flip this function for the remaining
    // parts of the function.
    angle = fmod(angle, M_PI * 2);
    int resultSign;
    if (angle < 0)
        resultSign = -1;
    else
        resultSign = 1;

    angle = fabs(angle);
    if (angle > M_PI * 3 / 2)
    {
        angle = M_PI * 2 - angle;
        resultSign = -resultSign;
    }
    else if (angle > M_PI)
    {
        angle -= M_PI;
        resultSign = -resultSign;
    }
    else if (angle > M_PI / 2)
        angle = M_PI - angle;

    double angleSquared = angle * angle;
    double numerator = angle;
    double result = angle;

    for (int i = 0; i < kNumTerms; i++)
    {
        numerator *= angleSquared;
        result += numerator * kDenominators[i];
    }

    return result * resultSign;
}

double cos(double angle)
{
    return sin(angle + M_PI * 0.5f);
}

float sinf(float angle)
{
    return sin(angle);
}

float cosf(float angle)
{
    return cos(angle);
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

float ceilf(float value)
{
    float floorval = floorf(value);
    if (value > floorval)
        return floorval + 1.0;

    return floorval;
}

