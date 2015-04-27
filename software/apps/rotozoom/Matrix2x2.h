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
