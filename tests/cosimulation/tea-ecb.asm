; 
; Copyright 2011-2013 Jeff Bush
; 
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
; 
;     http://www.apache.org/licenses/LICENSE-2.0
; 
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.
; 

;
; Tiny Encryption Algorithm, using electronic codebook mode
; http://www.springerlink.com/content/p16916lx735m2562/
;

_start:		s0 = &encrypt_data
			u10 = mem_l[k0]
			u11 = mem_l[k1]
			u12 = mem_l[k2]
			u13 = mem_l[k3]
			call tea_encrypt
			cr31 = s0		; halt

			.align 64
encrypt_data: .word 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
			.word 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
			.emitliteralpool

			
tea_encrypt: 
			; Preliminaries: set up some constants we will use later
			s1 = mem_l[lower_mask]		
			s2 = mem_l[delta]
			s7 = mem_l[even_mask]
			v8 = mem_l[high_combine]
			v9 = mem_l[low_combine]
			v2 = mem_l[odd_extract]
			v3 = mem_l[even_extract]

			; Read a block of 128 bytes from memory
			v0 = mem_l[s0]
			v1 = mem_l[s0 + 64]
			
			; Rearrange the two vectors into vectors of even and odd words.
			; v4 will contain the even elements, v5 will contain the odd ones
			v4 = shuffle(v0, v2)
			v5 = shuffle(v0, v3)
			v4{s1} = shuffle(v1, v2)
			v5{s1} = shuffle(v1, v3)

			; Perform the actual encryption 
			; s2 is delta
			; v10 is sum
			; s4 is iteration count
			; v6 and v7 are temporaries
			s4 = 32
			v10 = mem_l[initial_sums]
			
			; for (i = 0; i < 32; i++) {
	loop:	v10 = v10 + s2		; sum += delta
	
			; v[0] += ((v[1]<<4) + k0) ^ (v[1] + sum) ^ ((v[1]>>5) + k1)
			v6 = v5 << 4		; v[1] << 4
			v6 = v6 + s10		; add k0
			v7 = v5 + v10		; v[1] + sum
			v6 = v6 ^ v7		; xor
			vu7 = vu5 >> 5		; v[1] >> 5
			v7 = v7 + s11		; add k1
			v6 = v6 ^ v7		; xor
			v4 = v4 + v6		; v[0] += ...
			
			; v[1] += ((v[0]<<4) + k2) ^ (v[0] + sum) ^ ((v[0]>>5) + k3); 
			v6 = v4 << 4		; v[0] << 4
			v6 = v6 + s12		; + k2
			v7 = v4 + v10		; v[0] + sum
			v6 = v6 ^ v7		; xor
			vu7 = vu4 >> 5		; v[0] >> 5
			v7 = v7 + s13		; + k3
			v6 = v6 ^ v7		; xor
			v5 = v5 + v6		; v[1] += ...
			
			s4 = s4 - 1
			if s4 goto loop
			
			; } // end for

			; Put the elements back into memory order
			v0 = shuffle(v4, v8)
			v1 = shuffle(v4, v9)
			v0{s7} = shuffle(v5, v8)
			v1{s7} = shuffle(v5, v9)

			; Store back to memory
			mem_l[s0] = v0
			mem_l[s0 + 64] = v1
			s0 = s0 + 128
			pc = link

k0:			.word 0x12345678
k1:			.word 0xdeadbeef
k2:			.word 0xa5a5a5a5
k3:			.word 0x98765432
lower_mask: .word 0x00ff
even_mask: 	.word 0x5555
delta: 		.word 0x9e3779b9
			.emitliteralpool

.align 64
even_extract: .word 14, 12, 10, 8, 6, 4, 2, 0, 14, 12, 10, 8, 6, 4, 2, 0
odd_extract: .word 15, 13, 11, 9, 7, 5, 3, 1, 15, 13, 11, 9, 7, 5, 3, 1
high_combine: .word 15, 15, 14, 14, 13, 13, 12, 12, 11, 11, 10, 10, 9, 9, 8, 8
low_combine: .word 7, 7, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1, 1, 0, 0

; each lane is 'lane * 32 * delta'.  This is effectively what sum
; would be at the end of each block if you were doing them sequentially.
initial_sums: .word 0x0, 0xc6ef3720, 0x8dde6e40, 0x54cda560, 0x1bbcdc80
	.word 0xe2ac13a0, 0xa99b4ac0, 0x708a81e0, 0x3779b900, 0xfe68f020
	.word 0xc5582740, 0x8c475e60, 0x53369580, 0x1a25cca0, 0xe11503c0
	.word 0xa8043ae0

