from testgroup import *

class MixedTests(TestGroup):
	def test_selectionSort():
		return ({}, '''
			sort_array			.byte 10, 15, 31, 32, 29, 9, 17, 16, 11, 30, 24, 26, 14 
								.byte 28, 27, 23, 20, 12, 7, 4, 22, 13, 6, 8, 5, 21, 25 
								.byte 18, 1, 19, 2, 3
			arraylen			.word	32
			
			_start				s0 = &sort_array
								s1 = mem_l[arraylen]
								s1 = s1 + s0				; s1 is now the end pointer
			outer_loop			s2 = s0 + 1
			inner_loop			s3 = mem_b[s0]
								s4 = mem_b[s2]
								s5 = s3 > s4
								if !s5 goto no_swap
								mem_b[s0] = s4
								mem_b[s2] = s3
			no_swap				s2 = s2 + 1
								s5 = s2 == s1
								if !s5 goto inner_loop
								s0 = s0 + 1
								s5 = s0 + 1
								s5 = s5 == s1
								if !s5 goto outer_loop
								goto ___done
		''', None, 4, [x + 1 for x in range(32)], 1000)

	# This could be run with multiple strands if you allocated a separate stack
	# for each one.
	def test_fibonacci():
		return ({ 'u0' : 9, 'u29' : 0x1000 }, '''
					call	fib
					goto ___done
			
		fib			sp = sp - 12
					mem_l[sp] = link
					mem_l[sp + 4] = s1		; save this
					mem_l[sp + 8] = s2		; save this

					if s0 goto notzero
					goto return				; return 0
		notzero		s0 = s0 - 1
					if s0 goto notone
					s0 = s0 + 1
					goto return				; return 1
		notone		s2 = s0	- 1				; save next value
					call fib				; call fib with n - 1
					s1 = s0					; save the return value
					s0 = s2					; restore parameter
					call fib				; call fib with n - 2
					s0 = s0 + s1			; add the two results
		return		link = mem_l[sp]
					s2 = mem_l[sp + 8]
					s1 = mem_l[sp + 4]
					sp = sp + 12
					pc = link		
		''', { 't0u0' : 34, 't0u29' : None, 't0u1' : None, 't0u2' : None, 't0u30' : None }, None, None, 5000)

	# Vectorized count bits		
	def test_countBits():
		initialVec = allocateRandomVectorValue()
		counts = [ doBitCount(x) for x in initialVec ]
	
		return ({ 'v0' : initialVec }, '''

				u2 = 15
				cr30 = u2		; Start all threads
				
		loop0	u2 = v0 <> 0
				if !u2 goto ___done
				v1{u2} = v0 - 1
				v0{u2} = v0 & v1
				v2{u2} = v2 + 1
				goto loop0
		''', { 'v0' : [0 for x in range(16)], 'v1' : None, 'v2' : counts, 'u2' : 0 },
			None, None, None)
			
	def test_matrixMultiply():
		# Multiply v0 by v1, where each vector contains a 4x4 floating point matrix in 
		# row major form
		return ({ 'v0' : [ 1.0, 5.0, 0.0, 9.0, 7.0, 3.0, 3.0, 1.0, 0.0, 0.0, 2.0, 3.0, 1.0, 0.0, 5.0, 7.0],
			'v1' : [ 2.0, 0.0, 1.0, 0.0, 1.0, 2.0, 3.0, 4.0, 9.0, 0.0, 8.0, 0.0, 1.0, 1.0, 1.0, 1.0 ] }, '''
						u0 = 15
						cr30 = u0	; Start all strands

						v2 = mem_l[permute0]
						v4 = mem_l[permute1]
						v3 = shuffle(v0, v2)
						v5 = shuffle(v1, v4)
						vf6 = vf3 * vf5

						v2 = v2 - 1
						v4 = v4 - 4
						v3 = shuffle(v0, v2)
						v5 = shuffle(v1, v4)
						vf3 = vf3 * vf5
						vf6 = vf6 + vf3

						v2 = v2 - 1
						v4 = v4 - 4
						v3 = shuffle(v0, v2)
						v5 = shuffle(v1, v4)
						vf3 = vf3 * vf5
						vf6 = vf6 + vf3

						v2 = v2 - 1
						v4 = v4 - 4
						v3 = shuffle(v0, v2)
						v5 = shuffle(v1, v4)
						vf3 = vf3 * vf5
						vf6 = vf6 + vf3	; result is in v6
						
						goto ___done
		
						; 15 14 13 12
						; 11 10  9  8
						;  7  6  5  4
						;  3  2  1  0
						.align 64
			permute0	.word 15, 15, 15, 15, 11, 11, 11, 11, 7, 7, 7, 7, 3, 3, 3, 3
			permute1	.word 15, 14, 13, 12, 15, 14, 13, 12, 15, 14, 13, 12, 15, 14, 13, 12 
		
		''', { 'v2' : None, 'v3' : None, 'v4' : None, 'v5' : None, 'u0' : None,
			'v6' : [ 16.0, 19.0, 25.0, 29.0, 45.0, 7.0, 41.0, 13.0, 21.0, 3.0, 19.0, 3.0, 54.0, 7.0, 48.0, 7.0 ] }, None, None, None)

	#
	# Build a tree in memory, then traverse it.
	#
	def test_treeWalk():
		# Heap starts at 1024
		# Stack starts at 65532
		depth = 7	
		expected = sum([x for x in range(2 ** depth)])
		
		return ({ 'u0' : depth, 'u29' : 0x10000 - 4 }, '''
			;
			;	struct node {	// 12 bytes
			;		int index;
			;		node *left;
			;		node *right;
			;	};
			;
			_start			call make_tree
							call walk_tree
							goto ___done

			; 
			; int walk_tree(struct node *root);
			;
			walk_tree		; Prolog
							sp = sp - 12
							mem_l[sp] = link
							mem_l[sp + 4] = s15		; s15 is the pointer to the root
							mem_l[sp + 8] = s16		; s16 is the count of this & children
							s15 = s0
							; 
							
							s16 = mem_l[s15]		; get index of this node

							s0 = mem_l[s15 + 4]		; check left child
							if !s0 goto leafnode	; if i'm a leaf, then skip
							call walk_tree			
							s16 = s16 + s0
							
							s0 = mem_l[s15 + 8]		; check right child
							call walk_tree
							s16 = s16 + s0
							
							; Epilog
			leafnode		s0 = s16
							s16 = mem_l[sp + 8]
							s15 = mem_l[sp + 4]
							link = mem_l[sp]
							sp = sp + 12
							pc = link
		
			;
			; struct node *make_tree(int depth);
			;
			make_tree		; Prolog
							sp = sp - 12
							mem_l[sp] = link
							mem_l[sp + 4] = s15		; s15 is stored depth
							mem_l[sp + 8] = s16		; s16 is stored node pointer
							s15 = s0
							;
							
							; Allocate this node
							s0 = 12					; size of a node
							call allocate
							s16 = s0
							
							; Allocate an index for this node and increment
							; the next index
							s4 = mem_l[next_node_id]
							mem_l[s16] = s4
							s4 = s4 + 1
							mem_l[next_node_id] = s4
							
							s0 = s15 - 1		; Decrease depth by one
							if !s0 goto no_children
							call make_tree
							mem_l[s16 + 4] = s0	; stash left child

							s0 = s15 - 1
							call make_tree
							mem_l[s16 + 8] = s0	; stash right child

							; Epilog
			no_children		s0 = s16			; return this node
							s16 = mem_l[sp + 8]
							s15 = mem_l[sp + 4]
							link = mem_l[sp]
							sp = sp + 12
							pc = link
							
			next_node_id	.word 1

			;
			; void *allocate(int size);
			;
			allocate		s1 = mem_l[heap_end]
							s2 = s1 + s0
							s0 = s1
							mem_l[heap_end] = s2
							pc = link
			heap_end		.word	1024
		''', { 't0u0' : expected, 't0u1' : None, 't0u2' : None, 't0u15' : None,
		't0u16' : None, 't0u4' : None, 't0u30' : None, 't0u29' : None}, None, None, 3500)
	
	#
	# Tiny Encryption Algorithm
	# http://www.springerlink.com/content/p16916lx735m2562/
	#
	def test_teaEncryptECB():
		k = [ 0x12345678, 0xdeadbeef, 0xa5a5a5a5, 0x98765432 ]
		clear = [x for x in range(32) ]
		expected = wordsToBytes(doTeaEncrypt(clear, k))
	
		# Key is stored in s10-s13
		return ({ 'u10' : k[0], 'u11' :  k[1], 'u12' :  k[2], 'u13' :  k[3] }, '''
			.align 64
		encrypt_data .word 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
			.word 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31

		_start
			s0 = &encrypt_data
			call tea_encrypt
			goto ___done
			
		tea_encrypt			
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
	loop	v10 = v10 + s2		; sum += delta
	
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

			lower_mask .word 0x00ff
			even_mask .word 0x5555
			delta .word 0x9e3779b9
			
			.align 64
			even_extract .word 14, 12, 10, 8, 6, 4, 2, 0, 14, 12, 10, 8, 6, 4, 2, 0
			odd_extract .word 15, 13, 11, 9, 7, 5, 3, 1, 15, 13, 11, 9, 7, 5, 3, 1
			high_combine .word 15, 15, 14, 14, 13, 13, 12, 12, 11, 11, 10, 10, 9, 9, 8, 8
			low_combine .word 7, 7, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1, 1, 0, 0

			; each lane is 'lane * 32 * delta'.  This is effectively what sum
			; would be at the end of each block if you were doing them sequentially.
			initial_sums .word 0x0, 0xc6ef3720, 0x8dde6e40, 0x54cda560, 0x1bbcdc80
				.word 0xe2ac13a0, 0xa99b4ac0, 0x708a81e0, 0x3779b900, 0xfe68f020
				.word 0xc5582740, 0x8c475e60, 0x53369580, 0x1a25cca0, 0xe11503c0
				.word 0xa8043ae0
		
		''', None, 64, expected, None)
		
		
def doBitCount(x):
	count = 0
	y = 0x80000000
	while y:
		if x & y:
			count = count + 1
			
		y >>= 1

	return count

def wordsToBytes(words):
	bytes = []
	for x in words:
		bytes += [ x & 0xff, (x >> 8) & 0xff, (x >> 16) & 0xff, (x >> 24) & 0xff ]
	
	return bytes

def doTeaEncrypt(v, k):
	result = []
	delta = 0x9e3779b9
	sum = 0
	for i in range(0, len(v), 2):
		v0 = v[i]
		v1 = v[i + 1]
		for i in range(32):
			sum = (sum + delta) & 0xffffffff
			v0 += ((v1 << 4) + k[0]) ^ (v1 + sum) ^ ((v1 >> 5) + k[1])
			v0 &= 0xffffffff
			v1 += ((v0 << 4) + k[2]) ^ (v0 + sum) ^ ((v0 >> 5) + k[3])
			v1 &= 0xffffffff

		result += [ v0, v1 ]
	
	return result