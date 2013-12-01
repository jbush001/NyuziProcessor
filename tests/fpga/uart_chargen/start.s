
					.text
					.globl _start
					.align 4
					.type _start,@function
_start:				load_32 sp, stacks_base
					getcr s0, 0			; get my strand ID
					shl s0, s0, 13		; 8192 bytes per stack
					add_i sp, sp, s0	; Compute stack address

					call main
					setcr s0, 29		; Stop thread
done:				goto done

stacks_base:		.long 0x1012e000	; end of FB + 8192 bytes

