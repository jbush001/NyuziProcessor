// 
// Copyright 2011-2015 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
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
	vecu16_t h0 = __builtin_nyuzi_makevectori(0x6A09E667);
	vecu16_t h1 = __builtin_nyuzi_makevectori(0xBB67AE85);
	vecu16_t h2 = __builtin_nyuzi_makevectori(0x3C6EF372);
	vecu16_t h3 = __builtin_nyuzi_makevectori(0xA54FF53A);
	vecu16_t h4 = __builtin_nyuzi_makevectori(0x510E527F);
	vecu16_t h5 = __builtin_nyuzi_makevectori(0x9B05688C);
	vecu16_t h6 = __builtin_nyuzi_makevectori(0x1F83D9AB);
	vecu16_t h7 = __builtin_nyuzi_makevectori(0x5BE0CD19);

	for (int i = 0; i < totalBlocks; i++)
	{
		vecu16_t w[64];
		for (int index = 0; index < 16; index++)
		{
			w[index] = __builtin_nyuzi_gather_loadi(pointers);
			pointers += __builtin_nyuzi_makevectori(4);
		}
	
		for (int index = 16; index < 64; index++)
	  		w[index] = SIG1(w[index - 2]) + w[index - 7] + SIG0(w[index - 15]) + w[index - 16];

		vecu16_t a = h0;
		vecu16_t b = h1;
		vecu16_t c = h2;
		vecu16_t d = h3;
		vecu16_t e = h4;
		vecu16_t f = h5;
		vecu16_t g = h6;
		vecu16_t h = h7;
	
		for (int round = 0; round < 64; round++)
		{
			vecu16_t temp1 = h + SIG1(e) + CH(e, f, g) + __builtin_nyuzi_makevectori(K[round]) + w[round];
			vecu16_t temp2 = SIG0(a) + MA(a, b, c);
			h = g;
			g = f;
			f = e;
			e = d + temp1;
			d = c;
			c = b;
			b = a;
			a = temp1 + temp2;
		}
		
		h0 += a;
		h1 += b;
		h2 += c;
		h3 += d;
		h4 += e;
		h5 += f;
		h6 += g;
		h7 += h;
	}

	// doesn't add padding or length fields to end...
	
	__builtin_nyuzi_scatter_storei(outHashes, h0);
	__builtin_nyuzi_scatter_storei(outHashes + __builtin_nyuzi_makevectori(4), h1);
	__builtin_nyuzi_scatter_storei(outHashes + __builtin_nyuzi_makevectori(8), h2);
	__builtin_nyuzi_scatter_storei(outHashes + __builtin_nyuzi_makevectori(12), h3);
	__builtin_nyuzi_scatter_storei(outHashes + __builtin_nyuzi_makevectori(16), h4);
	__builtin_nyuzi_scatter_storei(outHashes + __builtin_nyuzi_makevectori(20), h5);
	__builtin_nyuzi_scatter_storei(outHashes + __builtin_nyuzi_makevectori(24), h6);
	__builtin_nyuzi_scatter_storei(outHashes + __builtin_nyuzi_makevectori(28), h7);
}

// Each thread starts here and performs 16 hashes simultaneously. With four
// threads, there are 64 hashes in flight at a time. Each thread repeats this
// four times.  The total number of hashes performed is 256.
int main()
{
	__builtin_nyuzi_write_control_reg(30, 0xffffffff);	// Start other threads

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
