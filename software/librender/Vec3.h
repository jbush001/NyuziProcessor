// 
// Copyright (C) 2011-2015 Jeff Bush
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

#ifndef __Vec3_H
#define __Vec3_H

#include <math.h>

namespace librender
{

class Vec3
{
public:
	Vec3()
	{
		fValues[0] = 0.0f;
		fValues[1] = 0.0f;
		fValues[2] = 0.0f;
	}
	
	Vec3(float a, float b, float c)
	{
		fValues[0] = a;
		fValues[1] = b;
		fValues[2] = c;
	}
	
	Vec3 operator+(const Vec3 &other) const
	{
		Vec3 newVal;
		for (int i = 0; i < 3; i++)
			newVal.fValues[i] = fValues[i] + other.fValues[i];

		return newVal;
	}

	Vec3 operator-(const Vec3 &other) const
	{
		Vec3 newVal;
		for (int i = 0; i < 3; i++)
			newVal.fValues[i] = fValues[i] - other.fValues[i];

		return newVal;
	}
	
	Vec3 operator*(float other) const
	{
		Vec3 newVal;
		for (int i = 0; i < 3; i++)
			newVal.fValues[i] = fValues[i] * other;

		return newVal;
	}

	Vec3 operator/(float other) const
	{
		Vec3 newVal;
		float denom = 1.0 / other;
		for (int i = 0; i < 3; i++)
			newVal.fValues[i] = fValues[i] * denom;

		return newVal;
	}

	float magnitude() const
	{
		float magSquared = 0.0;
		for (int i = 0; i < 3; i++)
			magSquared += fValues[i] * fValues[i];
		
		return sqrt(magSquared);
	}

	Vec3 normalized() const
	{
		return *this / magnitude();
	}
	
	float &operator[](int index)
	{
		return fValues[index];
	}

	float operator[](int index) const
	{
		return fValues[index];
	}
	
	Vec3 crossProduct(const Vec3 &other) const
	{
		Vec3 result;
		result.fValues[0] = fValues[1] * other.fValues[2] - fValues[2] * other.fValues[1];
		result.fValues[1] = fValues[2] * other.fValues[0] - fValues[0] * other.fValues[2];
		result.fValues[2] = fValues[0] * other.fValues[1] - fValues[1] * other.fValues[0];
		return result;
	}

	void print() const
	{
		printf("%f %f %f\n", fValues[0], fValues[1], fValues[2]);
	}

private:
	float fValues[3];
};

}

#endif
