/* Copyright 2015 Pipat Methavanitpong
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * 	Unless required by applicable law or agreed to in writing, software
 * 	distributed under the License is distributed on an "AS IS" BASIS,
 * 	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * 	See the License for the specific language governing permissions and
 * 	limitations under the License.
 */

#include <stdlib.h>
#include <stdio.h>

// Regression for https://github.com/jbush001/NyuziToolchain/issues/26
// This program caused a crash in genSpace() triggered by the use of
// a large stack frame.

typedef float vecf16 __attribute__ ((vector_size(16 * sizeof(float))));
typedef struct matrix { vecf16 rows[16]; } matrix_t;

matrix_t transpose(const matrix &m1)
{
	int i, j;
	matrix_t m_ret;
	for (i = 0; i < 16; i++)
		for (j = 0; j < 16; j++)
			m_ret.rows[i][j] = m1.rows[j][i];
	return m_ret;
}

float total(const vecf16 &v1)
{
	int i;
	float sum = 0;
	for (i = 0; i < 16; i++)
		sum += v1[i];
	return sum;
}

matrix_t mul(const matrix &m1, const matrix &m2)
{
	int row, col;
	vecf16 v_tmp;
	matrix_t m_ret;
	matrix_t m2_t = transpose(m2);
	for (row = 0; row < 16; row++)
	{
		for (col = 0; col < 16; col++)
		{
			v_tmp = m1.rows[row] * m2_t.rows[col];
			m_ret.rows[row][col] = total(v_tmp);
		}
	}
	return m_ret;
}

matrix_t genSpace()
{
	int i, j;
	matrix_t m_ret, m1, m1t;
	for (i = 0; i < 16; i++)
		for (j = 0; j < 16; j++)
			m1.rows[i][j] = rand() / 1000000000.0;
	m1t = transpose(m1);

	m_ret = mul(m1, m1t);		// C * C_t = symmetric positive definite matrix
	return m_ret;
}

int main(int argc, char *argv[])
{
	matrix_t A = genSpace();

	printf("RESULT: %d ", (int) A.rows[0][0]); // CHECK: RESULT: 17
}


