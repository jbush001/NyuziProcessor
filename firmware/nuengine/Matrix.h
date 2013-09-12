// 
// Copyright 2013 Jeff Bush
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

#ifndef __MATRIX_H
#define __MATRIX_H

#include "vectypes.h"
#include "utils.h"

class Matrix
{
public:
	Matrix()
	{
		memset(fValues, 0, sizeof(float) * 16);
		fValues[0] = 1.0f;
		fValues[5] = 1.0f;
		fValues[10] = 1.0f;
		fValues[15] = 1.0f;
	}
	
	Matrix(const float *values)
	{
		memcpy((void*) fValues, values, sizeof(float) * 16);
	}
	
	Matrix(const Matrix &rhs)
	{
		memcpy((void*) fValues, rhs.fValues, sizeof(float) * 16);
	}
	
	Matrix &operator=(const Matrix &rhs)
	{
		memcpy((void*) fValues, rhs.fValues, sizeof(float) * 16);
		return *this;
	}
	
	Matrix operator*(const Matrix &rhs) const
	{
		Matrix newMat;
	
		for (int col = 0; col < 4; col++)
		{
			for (int row = 0; row < 4; row++)
			{
				float sum = 0.0f;
				for (int i = 0; i < 4; i++)
					sum += fValues[row * 4 + i] * rhs.fValues[i * 4 + col];
				
				newMat.fValues[row * 4 + col] = sum;
			}
		}
		
		return newMat;
	}

	// Multiply 16 vec4s by this matrix.	
	void mulVec(vecf16 outVec[4], const vecf16 inVec[4])
	{
		for (int row = 0; row < 4; row++)
		{
			vecf16 sum = splatf(0.0f);
			for (int col = 0; col < 4; col++)
				sum += splatf(fValues[row * 4 + col]) * inVec[col];			
			
			outVec[row] = sum;
		}
	}

private:
	float fValues[16];	// row-major order
};

#endif
