// 
// Copyright 2013-2014 Jeff Bush
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

//
// SHA-256 RFC 4634 (ish)
//

typedef unsigned int vecu16 __attribute__((__vector_size__(16 * sizeof(int))));

inline vecu16 CH(vecu16 x, vecu16 y, vecu16 z)
{
	return (x & y) ^ (~x & z);
}

inline vecu16 MA(vecu16 x, vecu16 y, vecu16 z)
{
	return (x & y) ^ (x & z) ^ (y & z);
}

inline vecu16 ROTR(vecu16 x, int y)
{
	return (x >> __builtin_vp_makevectori(y)) | (x << (__builtin_vp_makevectori(32 - y)));
}

inline vecu16 SIG0(vecu16 x)
{
	return ROTR(x, 2) ^ ROTR(x, 13) ^ ROTR(x, 22);
}

inline vecu16 SIG1(vecu16 x)
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
void sha2Hash(vecu16 pointers, int totalBlocks, vecu16 outHashes)
{
	// Initial H values
	vecu16 A = __builtin_vp_makevectori(0x6A09E667);
	vecu16 B = __builtin_vp_makevectori(0xBB67AE85);
	vecu16 C = __builtin_vp_makevectori(0x3C6EF372);
	vecu16 D = __builtin_vp_makevectori(0xA54FF53A);
	vecu16 E = __builtin_vp_makevectori(0x510E527F);
	vecu16 F = __builtin_vp_makevectori(0x9B05688C);
	vecu16 G = __builtin_vp_makevectori(0x1F83D9AB);
	vecu16 H = __builtin_vp_makevectori(0x5BE0CD19);

	for (int i = 0; i < totalBlocks; i++)
	{
		vecu16 W[64];
		for (int index = 0; index < 16; index++)
		{
			W[index] = __builtin_vp_gather_loadi(pointers);
			pointers += __builtin_vp_makevectori(4);
		}
	
		for (int index = 16; index < 64; index++)
	  		W[index] = SIG1(W[index - 2]) + W[index - 7] + SIG0(W[index - 15]) + W[index - 16];
	
		for (int round = 0; round < 64; round++)
		{
			vecu16 temp1 = H + SIG1(E) + CH(E, F, G) + __builtin_vp_makevectori(K[round]) + W[round];
			vecu16 temp2 = SIG0(A) + MA(A, B, C);
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
	
	__builtin_vp_scatter_storei(outHashes, A);
	__builtin_vp_scatter_storei(outHashes + __builtin_vp_makevectori(4), B);
	__builtin_vp_scatter_storei(outHashes + __builtin_vp_makevectori(8), C);
	__builtin_vp_scatter_storei(outHashes + __builtin_vp_makevectori(12), D);
	__builtin_vp_scatter_storei(outHashes + __builtin_vp_makevectori(16), E);
	__builtin_vp_scatter_storei(outHashes + __builtin_vp_makevectori(20), F);
	__builtin_vp_scatter_storei(outHashes + __builtin_vp_makevectori(24), G);
	__builtin_vp_scatter_storei(outHashes + __builtin_vp_makevectori(28), H);
}

int main()
{
	const int kHashSize = 32;
	const int kNumBuffers = 3;
	const int kNumLanes = 16;
	
	unsigned int basePtr = 0x100000 + __builtin_vp_get_current_strand() * kHashSize * kNumLanes * kNumBuffers;
	const vecu16 kStepVector = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
	vecu16 inputPtr = __builtin_vp_makevectori(basePtr) + (kStepVector * __builtin_vp_makevectori(kHashSize));
	vecu16 tmpPtr = inputPtr + __builtin_vp_makevectori(kHashSize * kNumLanes);
	vecu16 outputPtr = tmpPtr + __builtin_vp_makevectori(kHashSize * kNumLanes);
	
	// Double sha-2 hash
	sha2Hash(inputPtr, 1, outputPtr);
	sha2Hash(tmpPtr, 1, outputPtr);
	
	return 0;
}
