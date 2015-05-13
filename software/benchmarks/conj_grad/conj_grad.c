// Conjugate Gradient
// Ported from http://sepwww.stanford.edu/theses/sep44/44_14.pdf
// Minimize res[m] = y[m] - aaa[m][n] * x[n]


#if USE_PRINTF == 1
#include <stdio.h>
#else
#define printf(...) do{ }while(0)
#endif

#define M 5
#define N 4

double dot(int dim, double* v0, double *v1) {
	int i;
	double ret = 0.0;
	for (i = 0; i < dim; i++)
		ret += v0[i] * v1[i];
	return ret;
}

int main(int argc, char* argv[]) {
	int i, j, n, m, iter, niter;
	double sds, gdg, gds, determ, gdr, sdr, alfa, beta;

// HARD CODE	
	double x[N], y[M], res[M], aaa[M][N];
	double g[N], s[N], gg[M], ss[M];		// space vectors
	n = N; m = M;
	
	niter = 4;
	y[0] = 3.00; y[1] = 3.00; y[2] = 5.00; y[3] = 7.00; y[4] = 9.00;
	aaa[0][0] = 1.00; aaa[0][1] = 1.00; aaa[0][2] = 1.00; aaa[0][3] = 0.00;
	aaa[1][0] = 1.00; aaa[1][1] = 2.00; aaa[1][2] = 0.00; aaa[1][3] = 0.00;
	aaa[2][0] = 1.00; aaa[2][1] = 3.00; aaa[2][2] = 1.00; aaa[2][3] = 0.00;
	aaa[3][0] = 1.00; aaa[3][1] = 4.00; aaa[3][2] = 0.00; aaa[3][3] = 1.00;
	aaa[4][0] = 1.00; aaa[4][1] = 5.00; aaa[4][2] = 1.00; aaa[4][3] = 1.00;
////////////
 	for (i = 0; i < m; i++) {
 		x[i] = 0;			// clear solution
 	}
	for (i = 0; i < m; i++) {
		res[i] = y[i];
	}
	for (iter = 0; iter <= niter; iter++) {
		for (j = 0; j < n; j++) {
			g[j] = 0;		// g = transpose(A) * r = grad
			for (i = 0; i < m; i++) { 
				g[j] = g[j] + aaa[i][j] * res[i];
			}
		}
		for (i = 0; i < m; i++) {
			gg[i] = 0;
			for (j = 0; j < n; j++) {
				gg[i] = gg[i] + aaa[i][j] * g[j];
			}
		}
		if (iter == 0) {	// one step of steepest descent
			alfa = dot(m, gg, res) / dot(m, gg, gg);
			beta = 0;
		}
		else {				// search plane by solving 2-by-2
			gdg = dot(m, gg, gg);		// G . (R - G alfa - S beta)
			sds = dot(m, ss, ss);		// G . (R - G alfa - S beta)
			gds = dot(m, gg, ss);
			// determ = gdg * sds - gds * gds + 1 ^ (-30); 
			determ = gdg * sds - gds * gds; 
			gdr = dot(m, gg, res);
			sdr = dot(m, ss, res);
			alfa = (sds * gdr - gds * sdr) / determ;
			beta = ((-gds) * gdr + gdg * sdr) / determ;
		}
		for (i = 0; i < n; i++) {		// s = model step
			s[i] = alfa * g[i] + beta * s[i];
		}
		for (i = 0; i < m; i++) {		// ss = conjugate
			ss[i] = alfa * gg[i] + beta * ss[i];
		}
		printf("x\t");
		for (i = 0; i < n; i++) { 		// update solution
			x[i] = x[i] + s[i];
			printf("%lf ", x[i]);
		}
		printf("\n");
		printf("res\t");
		for (i = 0; i < m; i++) {		// update residual
			res[i] = res[i] - ss[i];
			printf ("%lf ", res[i]);
		}
		printf("\n");
	}
	
	printf ("Number of interations: %d\n", iter);
	printf ("Approximated solution is \n");
	for (i = 0; i < n; i++)
		printf("\t%lf\n", x[i]);
	return 0;
}
