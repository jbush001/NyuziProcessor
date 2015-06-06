#include "conjugate.h"

#ifdef __NYUZI__
#include <stdlib.h>
#include <time.h>
#else /* !__NYUZI__ */
#include <iostream>
#include <cstdlib>
#include <ctime>
using std::cout;
using std::endl;
#endif /* __NYUZI__ */

#define MAX_ITERS 50
#define TOLERANCE 0.000001

int main(int argc, char *argv[])
{
	std::srand(std::time(0));		// Init random seed
	matrix_t A = genSpace();
	vecf16 x_ans = genAns();
	vecf16 b = mul(A, x_ans);

#ifndef __NYUZI__
	cout << "A = " << endl;
	repr(A);
	cout << "x_ans = " << endl;
	repr(x_ans);
	cout << "b = " << endl;
	repr(b);
#endif /* !__NYUZI__ */
	
	// x = solution, p = direction, r = residue
	vecf16 x[2], p[2], r[3], s;
	float alpha, beta;		// vector scalers
	
	x[0] = VEC_ZERO;		// Set initial guess to origin
	r[0] = b;
	
	int iter = 0;
	int cur_r = 0, cur_x, cur_p;
	int prev_r, prev2_r, prev_x, prev_p;

	while(mag2(r[cur_r]) > TOLERANCE && iter < MAX_ITERS)
	{
		iter++;
		// managing indices
		cur_r = iter % 3; cur_x = cur_p = iter % 2;
		prev_r =  (cur_r - 1 < 0) ? (cur_r - 1) + 3 : cur_r - 1;
		prev2_r = (cur_r - 2 < 0) ? (cur_r - 2) + 3 : cur_r - 2;
		prev_x = prev_p = (cur_p - 1 < 0) ? (cur_p - 1) + 2 : cur_p - 1;
		
		if (iter == 1) { p[1] = r[0]; }
		else
		{
			beta = dot(r[prev_r], r[prev_r]) / dot(r[prev2_r], r[prev2_r]);
			p[cur_p] = r[prev_r] + (p[prev_p] * beta);
		}

		s = mul(A, p[cur_p]);
		alpha = dot(r[prev_r], r[prev_r]) / dot(p[cur_p], s);
		x[cur_x] = x[prev_x] + (p[cur_p] * alpha);
		r[cur_r] = r[prev_r] - (s * alpha);
	}
	
#ifndef __NYUZI__
	cout << "iteration = " << iter << endl;
	cout << "x = " << endl;
	repr(x[cur_x]);
#endif /* !__NYUZI__ */

	return 0;
}
