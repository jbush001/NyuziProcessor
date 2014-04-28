			.globl _start
_start:		load_32 s0, op1
			load_32 s1, op2
			add_f s2, s0, s1
			nop
			nop
			nop
			nop
			nop
			nop
			setcr s0, 29
done: 		goto done

op1: .float 1.734
op2: .float -0.00227