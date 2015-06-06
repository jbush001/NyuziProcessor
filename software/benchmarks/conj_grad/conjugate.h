#ifndef CONJUGATE_H
#define CONJUGATE_H

#ifdef __NYUZI__
#include <stdlib.h>		// for rand()
#else /* !__NYUZI__ */
#include <iostream>		// for cout
#include <cstdlib>		// for rand()
using std::cout;
using std::rand;
#endif

/*** definition ***/
typedef float vecf16 __attribute__ ((vector_size(16 * sizeof(float))));
typedef struct matrix { vecf16 rows[16]; } matrix_t;
vecf16 VEC_ZERO = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
/***  arithmetic  ***/
float total(const vecf16 &v1);
float dot(const vecf16 &v1, const vecf16 &v2);
float mag2(const vecf16 &v1);
vecf16 mul(const matrix &m1, const vecf16 &v2);
matrix_t mul(const matrix &m1, const matrix &m2);
matrix_t transpose(const matrix &m1);
/***  utility  ***/
matrix_t genSpace();
#ifndef __NYUZI__
void repr(const vecf16 &v);
void repr(const matrix_t &m);
#endif

#include "conjugate.cpp"

#endif /* CONJUGATE_H */
