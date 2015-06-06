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

float mag2(const vecf16 &v1)
{
	return dot(v1, v1);
}

vecf16 mul(const matrix &m1, const vecf16 &v2)
{
	int i, j;
	vecf16 v_ret;
	vecf16 v_tmp = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
	for (i = 0; i < 16; i ++)
	{
		v_tmp = m1.rows[i] * v2;
		v_ret[i] = total(v_tmp);
	}
	return v_ret;
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
	matrix_t m_ret, m1, m1t;
	for (i = 0; i < 16; i++)
		for (j = 0; j < 16; j++)
			m1.rows[i][j] = std::rand() / 1000000000.0;
	m1t = transpose(m1);

	m_ret = mul(m1, m1t);		// C * C_t = symmetric positive definite matrix
	return m_ret;
}

vecf16 genAns()
{
	int i;
	vecf16 v_ret;
	for (i = 0; i < 16; i++)
		v_ret[i] = std::rand() / 1000000000.0;
	return v_ret;
}

#ifndef __NYUZI__
void repr(const vecf16 &v)
{
	int i;
	for (i = 0; i < 16; i++)
		std::cout << v[i] << " ";
	std::cout << std::endl;
}

void repr(const matrix_t &m)
{
	int i;
	for (i = 0; i < 16; i++)
		repr(m.rows[i]);
}
#endif /* !__NYUZI__ */
