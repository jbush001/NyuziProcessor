from testcase import *

def doBitCount(x):
	count = 0
	y = 0x80000000
	while y:
		if x & y:
			count = count + 1
			
		y >>= 1

	return count


class MixedTests(TestCase):
	def test_selectionSort():
		return ({}, '''
			sort_array			.byte 5, 7, 1, 8, 2, 4, 3, 6
			arraylen			.word	8
			
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
		''', None, 4, [1, 2, 3, 4, 5, 6, 7, 8], 1000)

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
		''', { 'u0' : 34, 'u29' : None, 'u1' : None, 'u2' : None, 'u30' : None }, None, None, 5000)

	# Vectorized count bits		
	def test_countBits():
		initialVec = allocateRandomVectorValue()
		counts = [ doBitCount(x) for x in initialVec ]
	
		return ({ 'v0' : initialVec }, '''

		loop0	u2 = v0 <> 0
				if !u2 goto ___done
				v1{u2} = v0 - 1
				v0{u2} = v0 & v1
				v2{u2} = v2 + 1
				goto loop0
		''', { 'v0' : [0 for x in range(16)], 'v1' : None, 'v2' : counts, 'u2' : 0 },
			None, None, None)
			
	def test_matrixMultiply():
		# Multiply v0 by v1, where each is a matrix in row major form
		return ({ 'v0' : [ 1.0, 5.0, 0.0, 9.0, 7.0, 3.0, 3.0, 1.0, 0.0, 0.0, 2.0, 3.0, 1.0, 0.0, 5.0, 7.0],
			'v1' : [ 2.0, 0.0, 1.0, 0.0, 1.0, 2.0, 3.0, 4.0, 9.0, 0.0, 8.0, 0.0, 1.0, 1.0, 1.0, 1.0 ] }, '''
						v2 = mem_l[permute0]
						v3 = shuffle(v0, v2)
						v4 = mem_l[permute1]
						v5 = shuffle(v1, v4)
						vf6 = vf3 * vf5

						v2 = v2 + 1
						v4 = v4 + 4
						v3 = shuffle(v0, v2)
						v5 = shuffle(v1, v4)
						vf3 = vf3 * vf5
						vf6 = vf6 + vf3

						v2 = v2 + 1
						v4 = v4 + 4
						v3 = shuffle(v0, v2)
						v5 = shuffle(v1, v4)
						vf3 = vf3 * vf5
						vf6 = vf6 + vf3

						v2 = v2 + 1
						v4 = v4 + 4
						v3 = shuffle(v0, v2)
						v5 = shuffle(v1, v4)
						vf3 = vf3 * vf5
						vf6 = vf6 + vf3	; result is in v6
						
						goto ___done
		
						;  0  1  2  3
						;  4  5  6  7
						;  8  9 10 11
						; 12 13 14 15
						.align 64
			permute0	.word 0, 0, 0, 0, 4, 4, 4, 4, 8, 8, 8, 8, 12, 12, 12, 12
			permute1	.word 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3 
		
		''', { 'v2' : None, 'v3' : None, 'v4' : None, 'v5' : None, 
			'v6' : [ 16.0, 19.0, 25.0, 29.0, 45.0, 7.0, 41.0, 13.0, 21.0, 3.0, 19.0, 3.0, 54.0, 7.0, 48.0, 7.0 ] }, None, None, None)

	#
	# Build a tree in memory, then traverse it.
	#
	def test_treeWalk():
		# Heap starts at 1024
		# Stack starts at 65532
		depth = 7	# Larger than the data cache
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
							s0 = 0
							s0 = s0 + 12		; Size of a node
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
		''', { 'u0' : expected, 'u1' : None, 'u2' : None, 'u15' : None,
		'u16' : None, 'u4' : None, 'u30' : None, 'u29' : None}, None, None, 3500)
		