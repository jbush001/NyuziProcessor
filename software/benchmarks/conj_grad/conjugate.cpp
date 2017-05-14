/* Copyright 2015 Pipat Methavanitpong
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

/***  arithmetic  ***/

float total(const vecf16 &v1)
{
    int i;
    float sum = 0;
    for (i = 0; i < 16; i++)
        sum += v1[i];
    return sum;
}

float dot(const vecf16 &v1, const vecf16 &v2)
{
    vecf16 v_mul = v1 * v2;
    return total(v_mul);
}

// magnitude^2
float mag2(const vecf16 &v1)
{
    return dot(v1, v1);
}

vecf16 mul(const matrix &m1, const vecf16 &v2)
{
    int i;
    vecf16 v_ret;
    vecf16 v_tmp = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    for (i = 0; i < 16; i ++)
    {
        v_tmp = m1.rows[i] * v2;
        v_ret[i] = total(v_tmp);
    }
    return v_ret;
}

// XXX: use mul() inside genSpace() causes crashing
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

matrix_t transpose(const matrix &m1)
{
    int i, j;
    matrix_t m_ret;
    for (i = 0; i < 16; i++)
        for (j = 0; j < 16; j++)
            m_ret.rows[i][j] = m1.rows[j][i];
    return m_ret;
}

/***  utility  ***/

matrix_t genSpace()
{
    int i, j;
    vecf16 tmp;
    matrix_t m_ret, m1;
    for (i = 0; i < 16; i++)
        for (j = 0; j < 16; j++)
            m1.rows[i][j] = rand() / 1000000000.0; // the const makes the rand() low enough

    // C * transpose(C)
    for (i = 0; i < 16; i++)
    {
        for (j = 0; j < 16; j++)
        {
            tmp = m1.rows[i] * m1.rows[j];
            m_ret.rows[i][j] = total(tmp);
        }
    }

    return m_ret;
}

vecf16 genAns()
{
    int i;
    vecf16 v_ret;
    for (i = 0; i < 16; i++)
        v_ret[i] = rand() / 1000000000.0; // the const makes the rand() low enough
    return v_ret;
}

void repr(const vecf16 &v)
{
    int i;
    for (i = 0; i < 16; i++)
        printf("%.4f ", v[i]);
    printf("\n");
}

void repr(const matrix_t &m)
{
    int i;
    for (i = 0; i < 16; i++)
        repr(m.rows[i]);
}
