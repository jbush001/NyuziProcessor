
					.globl _start
_start:				load.32 sp, stack_top
					call main
done:				goto done

stack_top:			.word 0xffffc