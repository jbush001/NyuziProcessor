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

#ifndef CONJUGATE_H
#define CONJUGATE_H

#ifdef __NYUZI__
#include <stdio.h>
#include <stdlib.h>
#else /* !__NYUZI__ */
#include <cstdio>
#include <cstdlib>
#endif

/*** definition ***/
typedef float vecf16 __attribute__ ((vector_size(16 * sizeof(float))));
typedef struct matrix {
    vecf16 rows[16];
} matrix_t;
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
