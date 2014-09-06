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

#ifndef __MATRIX_2X2
#define __MATRIX_2X2

class Matrix2x2
{
public:
	Matrix2x2()
		: 	a(1.0), b(0.0), c(0.0), d(1.0)
	{}
	
	Matrix2x2(float _a, float _b, float _c, float _d)
		:	a(_a), b(_b), c(_c), d(_d)
	{}

	Matrix2x2 operator*(const Matrix2x2 &rhs) const
	{
		return Matrix2x2(
			(a * rhs.a + b * rhs.c), (a * rhs.b + b * rhs.d),
			(c * rhs.a + d * rhs.c), (c * rhs.b + d * rhs.d));
	}

	float a, b;
	float c, d;
};

#endif
