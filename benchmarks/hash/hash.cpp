// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 

#include <stdint.h>

//
// This benchmark attempts to roughly simulate the workload of Bitcoin hashing, 
// although I didn't bother to make it correct and many details are missing.  
// It runs parallelized double SHA-256 hashes over a sequence of values.
//

// SHA-256 RFC 4634 (ish)
inline vecu16_t CH(vecu16_t x, vecu16_t y, vecu16_t z)
{
	return (x & y) ^ (~x & z);
}

inline vecu16_t MA(vecu16_t x, vecu16_t y, vecu16_t z)
{
	return (x & y) ^ (x & z) ^ (y & z);
}

inline vecu16_t ROTR(vecu16_t x, int y)
{
	return (x >> __builtin_nyuzi_makevectori(y)) | (x << (__builtin_nyuzi_makevectori(32 - y)));
}

inline vecu16_t SIG0(vecu16_t x)
{
	return ROTR(x, 2) ^ ROTR(x, 13) ^ ROTR(x, 22);
}

inline vecu16_t SIG1(vecu16_t x)
{
	return ROTR(x, 6) ^ ROTR(x, 11) ^ ROTR(x, 25);
}

const unsigned int K[] = {
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5
};

// Run 16 parallel hashes
void sha2Hash(vecu16_t pointers, int totalBlocks, vecu16_t outHashes)
{
	// Initial H values
	vecu16_t A = __builtin_nyuzi_makevectori(0x6A09E667);
	vecu16_t B = __builtin_nyuzi_makevectori(0xBB67AE85);
	vecu16_t C = __builtin_nyuzi_makevectori(0x3C6EF372);
	vecu16_t D = __builtin_nyuzi_makevectori(0xA54FF53A);
	vecu16_t E = __builtin_nyuzi_makevectori(0x510E527F);
	vecu16_t F = __builtin_nyuzi_makevectori(0x9B05688C);
	vecu16_t G = __builtin_nyuzi_makevectori(0x1F83D9AB);
	vecu16_t H = __builtin_nyuzi_makevectori(0x5BE0CD19);

	for (int i = 0; i < totalBlocks; i++)
	{
		vecu16_t W[64];
		for (int index = 0; index < 16; index++)
		{
			W[index] = __builtin_nyuzi_gather_loadi(pointers);
			pointers += __builtin_nyuzi_makevectori(4);
		}
	
		for (int index = 16; index < 64; index++)
	  		W[index] = SIG1(W[index - 2]) + W[index - 7] + SIG0(W[index - 15]) + W[index - 16];
	
		for (int round = 0; round < 64; round++)
		{
			vecu16_t temp1 = H + SIG1(E) + CH(E, F, G) + __builtin_nyuzi_makevectori(K[round]) + W[round];
			vecu16_t temp2 = SIG0(A) + MA(A, B, C);
			H = G;
			G = F;
			F = E;
			E = D + temp1;
			D = C;
			C = B;
			B = A;
			A = temp1 + temp2;
		}
	}

	// doesn't add padding or length fields to end...
	
	__builtin_nyuzi_scatter_storei(outHashes, A);
	__builtin_nyuzi_scatter_storei(outHashes + __builtin_nyuzi_makevectori(4), B);
	__builtin_nyuzi_scatter_storei(outHashes + __builtin_nyuzi_makevectori(8), C);
	__builtin_nyuzi_scatter_storei(outHashes + __builtin_nyuzi_makevectori(12), D);
	__builtin_nyuzi_scatter_storei(outHashes + __builtin_nyuzi_makevectori(16), E);
	__builtin_nyuzi_scatter_storei(outHashes + __builtin_nyuzi_makevectori(20), F);
	__builtin_nyuzi_scatter_storei(outHashes + __builtin_nyuzi_makevectori(24), G);
	__builtin_nyuzi_scatter_storei(outHashes + __builtin_nyuzi_makevectori(28), H);
}

// Each thread starts here and performs 16 hashes simultaneously. With four
// threads, there are 64 hashes in flight at a time. Each thread repeats this
// four times.  The total number of hashes performed is 256.
int main()
{
	__builtin_nyuzi_write_control_reg(30, 0xf);	// Start other threads if this is thread 0

	const int kSourceBlockSize = 128;
	const int kHashSize = 32;
	const int kNumBuffers = 2;
	const int kNumLanes = 16;
	
	unsigned int basePtr = 0x100000 + __builtin_nyuzi_read_control_reg(0) * (kHashSize * kNumLanes * kNumBuffers)
		+ (kSourceBlockSize * kNumLanes);
	const vecu16_t kStepVector = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
	vecu16_t inputPtr = __builtin_nyuzi_makevectori(basePtr) + (kStepVector * __builtin_nyuzi_makevectori(kHashSize));
	vecu16_t tmpPtr = inputPtr + __builtin_nyuzi_makevectori(kSourceBlockSize * kNumLanes);
	vecu16_t outputPtr = tmpPtr + __builtin_nyuzi_makevectori(kHashSize * kNumLanes);

	for (int i = 0; i < 4; i++)
	{
		// Double sha-2 hash
		sha2Hash(inputPtr, kSourceBlockSize / kHashSize, outputPtr);
		sha2Hash(tmpPtr, 1, outputPtr);
	}
	
	return 0;
}
