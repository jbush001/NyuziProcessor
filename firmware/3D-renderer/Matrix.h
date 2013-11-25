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
#include "Debug.h"

class Matrix
{
public:
	Matrix()
	{
		memset(fValues, 0, sizeof(float) * 16);
		fValues[0][0] = 1.0f;
		fValues[1][1] = 1.0f;
		fValues[2][2] = 1.0f;
		fValues[3][3] = 1.0f;
	}
	
	Matrix(const float values[4][4])
	{
		for (int row = 0; row < 4; row++)
		{
			for (int col = 0; col < 4; col++)
				fValues[row][col] = values[row][col];
		}
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
					sum += fValues[row][i] * rhs.fValues[i][col];
				
				newMat.fValues[row][col] = sum;
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
				sum += splatf(fValues[row][col]) * inVec[col];			
			
			outVec[row] = sum;
		}
	}
	
	Matrix upper3x3() const
	{
		Matrix newMat = *this;
		newMat.fValues[0][3] = 0.0f;
		newMat.fValues[1][3] = 0.0f;
		newMat.fValues[2][3] = 0.0f;
		newMat.fValues[3][0] = 0.0f;
		newMat.fValues[3][1] = 0.0f;
		newMat.fValues[3][2] = 0.0f;
	
		return newMat;
	}
	
	Matrix inverse() const
	{
		float newVals[4][4];

		float s0 = fValues[0][0] * fValues[1][1] - fValues[1][0] * fValues[0][1];
		float s1 = fValues[0][0] * fValues[1][2] - fValues[1][0] * fValues[0][2];
		float s2 = fValues[0][0] * fValues[1][3] - fValues[1][0] * fValues[0][3];
		float s3 = fValues[0][1] * fValues[1][2] - fValues[1][1] * fValues[0][2];
		float s4 = fValues[0][1] * fValues[1][3] - fValues[1][1] * fValues[0][3];
		float s5 = fValues[0][2] * fValues[1][3] - fValues[1][2] * fValues[0][3];

		float c5 = fValues[2][2] * fValues[3][3] - fValues[3][2] * fValues[2][3];
		float c4 = fValues[2][1] * fValues[3][3] - fValues[3][1] * fValues[2][3];
		float c3 = fValues[2][1] * fValues[3][2] - fValues[3][1] * fValues[2][2];
		float c2 = fValues[2][0] * fValues[3][3] - fValues[3][0] * fValues[2][3];
		float c1 = fValues[2][0] * fValues[3][2] - fValues[3][0] * fValues[2][2];
		float c0 = fValues[2][0] * fValues[3][1] - fValues[3][0] * fValues[2][1];

		float invdet = 1.0f / (s0 * c5 - s1 * c4 + s2 * c3 + s3 * c2 - s4 * c1 + s5 * c0);
		
		newVals[0][0] = (fValues[1][1] * c5 - fValues[1][2] * c4 + fValues[1][3] * c3) * invdet;
		newVals[0][1] = (-fValues[0][1] * c5 + fValues[0][2] * c4 - fValues[0][3] * c3) * invdet;
		newVals[0][2] = (fValues[3][1] * s5 - fValues[3][2] * s4 + fValues[3][3] * s3) * invdet;
		newVals[0][3] = (-fValues[2][1] * s5 + fValues[2][2] * s4 - fValues[2][3] * s3) * invdet;

		newVals[1][0] = (-fValues[1][0] * c5 + fValues[1][2] * c2 - fValues[1][3] * c1) * invdet;
		newVals[1][1] = (fValues[0][0] * c5 - fValues[0][2] * c2 + fValues[0][3] * c1) * invdet;
		newVals[1][2] = (-fValues[3][0] * s5 + fValues[3][2] * s2 - fValues[3][3] * s1) * invdet;
		newVals[1][3] = (fValues[2][0] * s5 - fValues[2][2] * s2 + fValues[2][3] * s1) * invdet;

		newVals[2][0] = (fValues[1][0] * c4 - fValues[1][1] * c2 + fValues[1][3] * c0) * invdet;
		newVals[2][1] = (-fValues[0][0] * c4 + fValues[0][1] * c2 - fValues[0][3] * c0) * invdet;
		newVals[2][2] = (fValues[3][0] * s4 - fValues[3][1] * s2 + fValues[3][3] * s0) * invdet;
		newVals[2][3] = (-fValues[2][0] * s4 + fValues[2][1] * s2 - fValues[2][3] * s0) * invdet;

		newVals[3][0] = (-fValues[1][0] * c3 + fValues[1][1] * c1 - fValues[1][2] * c0) * invdet;
		newVals[3][1] = (fValues[0][0] * c3 - fValues[0][1] * c1 + fValues[0][2] * c0) * invdet;
		newVals[3][2] = (-fValues[3][0] * s3 + fValues[3][1] * s1 - fValues[3][2] * s0) * invdet;
		newVals[3][3] = (fValues[2][0] * s3 - fValues[2][1] * s1 + fValues[2][2] * s0) * invdet;

		return Matrix(newVals);
	}
	
	Matrix transpose() const
	{
		float newVals[4][4];
		for (int row = 0; row < 4; row++)
		{
			for (int col = 0; col < 4; col++)
				newVals[row][col] = fValues[col][row];
		}
		
		return Matrix(newVals);
	}

	void print() const
	{
		for (int row = 0; row < 4; row++)
		{
			for (int col = 0; col < 4; col++)
				Debug::debug << fValues[row][col] << " ";	

			Debug::debug << "\n";
		}
	}

private:
	float fValues[4][4];
};

#endif
