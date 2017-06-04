/* Copyright 2015 Pipat Methavanitpong
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "conjugate.h"

#ifdef __NYUZI__
#include <stdio.h>
#include <stdlib.h>
#ifndef SEED            // defined in a compiler option
#define SEED    9999    // if not, set your random seed here
#endif
#else /* !__NYUZI__ */
#include <cstdio>
#include <cstdlib>
#include <ctime>
using std::srand;
using std::time;
#endif /* __NYUZI__ */

#define MAX_ITERS 50
#define TOLERANCE 0.000001

int main(int argc, char *argv[])
{
    printf("Welcome to Conjugate Gradient Benchmark\n");
#ifdef __NYUZI__
    srand(SEED);
#else
    srand(time(0));        // Init random seed
#endif
    matrix_t A = genSpace();
    vecf16 x_ans = genAns();
    vecf16 b = mul(A, x_ans);

    // show generated prob and sol
    printf("A = \n");
    repr(A);
    printf("x_ans = \n");
    repr(x_ans);
    printf("b = \n");
    repr(b);

    vecf16 x[2], p[2], r[3], s;        // x = solution, p = direction, r = residue
    float alpha, beta;                // vector scalers
    x[0] = VEC_ZERO;                // Set initial guess to origin
    r[0] = b;
    int iter = 0;
    int cur_r = 0, cur_x, cur_p;
    int prev_r, prev2_r, prev_x, prev_p;

    // start calculation
    while(mag2(r[cur_r]) > TOLERANCE && iter < MAX_ITERS)
    {
        iter++;
        // manage vector array indices
        cur_r = iter % 3;
        cur_x = cur_p = iter % 2;
        prev_r =  (cur_r - 1 < 0) ? (cur_r - 1) + 3 : cur_r - 1;
        prev2_r = (cur_r - 2 < 0) ? (cur_r - 2) + 3 : cur_r - 2;
        prev_x = prev_p = (cur_p - 1 < 0) ? (cur_p - 1) + 2 : cur_p - 1;

        if (iter == 1) {
            p[1] = r[0];
        }
#ifdef __NYUZI__
        else
        {
            beta = dot(r[prev_r], r[prev_r]) / dot(r[prev2_r], r[prev2_r]);
            p[cur_p] = r[prev_r] + (p[prev_p] * vecf16_t(beta));
        }

        s = mul(A, p[cur_p]);
        alpha = dot(r[prev_r], r[prev_r]) / dot(p[cur_p], s);
        x[cur_x] = x[prev_x] + (p[cur_p] * vecf16_t(alpha));
        r[cur_r] = r[prev_r] - (s * vecf16_t(alpha));
#else /* !__NYUZI__ */
        else
        {
            beta = dot(r[prev_r], r[prev_r]) / dot(r[prev2_r], r[prev2_r]);
            p[cur_p] = r[prev_r] + (p[prev_p] * beta);
        }

        s = mul(A, p[cur_p]);
        alpha = dot(r[prev_r], r[prev_r]) / dot(p[cur_p], s);
        x[cur_x] = x[prev_x] + (p[cur_p] * alpha);
        r[cur_r] = r[prev_r] - (s * alpha);
#endif /* __NYUZI__ */
    }

    // show result
    printf("iteration = %d\n", iter);
    printf("x = \n");
    repr(x[cur_x]);

    return 0;
}
