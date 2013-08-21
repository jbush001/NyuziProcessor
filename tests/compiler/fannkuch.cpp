/*
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.

    * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

    * Neither the name of "The Computer Language Benchmarks Game" nor the
    name of "The Computer Language Shootout Benchmarks" nor the names of
    its contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
*/

/*
 * The Computer Language Shootout
 * http://shootout.alioth.debian.org/
 * Contributed by Heiner Marxen
 *
 * "fannkuch"	for C gcc
 *
 * $Id: fannkuch.1.gcc.code,v 1.15 2009-04-28 15:39:31 igouy-guest Exp $
 */
#include "output.h"

Output out;

#define Int	int
#define Aint	int

unsigned int allocNext = 0x10000;

extern "C" void memset(void *output, int value, unsigned int len);


void *calloc(unsigned int size, int count)
{
	int totalSize = size * count;

	void *ptr = (void*) allocNext;
	allocNext += totalSize;
	memset(ptr, 0, totalSize);
	
	return ptr;
}

void memset(void *output, int value, unsigned int len)
{
	unsigned int i;

	for (i = 0; i < len; i++)
		((char *)output)[i] = (char)value;
}



static int
fannkuch( int n )
{
    Aint*	perm;
    Aint*	perm1;
    Aint*	count;
    int	flips;
    int	flipsMax;
    Int		r;
    Int		i;
    Int		k;
    Int		didpr;
    const Int	n1	= n - 1;

    if( n < 1 ) return 0;

    perm  = (Aint*) calloc(n, sizeof(*perm ));
    perm1 = (Aint*) calloc(n, sizeof(*perm1));
    count = (Aint*) calloc(n, sizeof(*count));

    for( i=0 ; i<n ; ++i ) perm1[i] = i;	/* initial (trivial) permu */

    r = n; didpr = 0; flipsMax = 0;
    for(;;) {
	if( didpr < 30 ) {
	    for( i=0 ; i<n ; ++i ) 
	    {
	    	out << (char) ('0' + (1+perm1[i]));
	    }
	    
	    out << "\n";
	    ++didpr;
	}
	for( ; r!=1 ; --r ) {
	    count[r-1] = r;
	}

#define XCH(x,y)	{ Aint t_mp; t_mp=(x); (x)=(y); (y)=t_mp; }

	if( ! (perm1[0]==0 || perm1[n1]==n1) ) {
	    flips = 0;
	    for( i=1 ; i<n ; ++i ) {	/* perm = perm1 */
		perm[i] = perm1[i];
	    }
	    k = perm1[0];		/* cache perm[0] in k */
	    do {			/* k!=0 ==> k>0 */
		Int	j;
		for( i=1, j=k-1 ; i<j ; ++i, --j ) {
		    XCH(perm[i], perm[j])
		}
		++flips;
		/*
		 * Now exchange k (caching perm[0]) and perm[k]... with care!
		 * XCH(k, perm[k]) does NOT work!
		 */
		j=perm[k]; perm[k]=k ; k=j;
	    }while( k );
	    if( flipsMax < flips ) {
		flipsMax = flips;
	    }
	}

	for(;;) {
	    if( r == n ) {
		return flipsMax;
	    }
	    /* rotate down perm[0..r] by one */
	    {
		Int	perm0 = perm1[0];
		i = 0;
		while( i < r ) {
		    k = i+1;
		    perm1[i] = perm1[k];
		    i = k;
		}
		perm1[r] = perm0;
	    }
	    if( (count[r] -= 1) > 0 ) {
		break;
	    }
	    ++r;
	}
    }
}

int
main( int argc, char* argv[] )
{
	int n = 8;

    out << fannkuch(n) << "\n";
    return 0;
}

// CHECK: 12345678
// CHECK: 21345678
// CHECK: 23145678
// CHECK: 32145678
// CHECK: 31245678
// CHECK: 13245678
// CHECK: 23415678
// CHECK: 32415678
// CHECK: 34215678
// CHECK: 43215678
// CHECK: 42315678
// CHECK: 24315678
// CHECK: 34125678
// CHECK: 43125678
// CHECK: 41325678
// CHECK: 14325678
// CHECK: 13425678
// CHECK: 31425678
// CHECK: 41235678
// CHECK: 14235678
// CHECK: 12435678
// CHECK: 21435678
// CHECK: 24135678
// CHECK: 42135678
// CHECK: 23451678
// CHECK: 32451678
// CHECK: 34251678
// CHECK: 43251678
// CHECK: 42351678
// CHECK: 24351678
// CHECK: 0x00000016

