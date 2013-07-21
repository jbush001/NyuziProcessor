
					.text
					.globl _start
					.align 4
					.type _start,@function
_start:				load.32 sp, stack_top
					call main
done:				goto done

stack_top:			.word 0xfffc0