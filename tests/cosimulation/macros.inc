

.macro HALT_CURRENT_THREAD
	getcr s0, 0
	move s1, 1
	shl s1, s1, s0
	move s0, 0xffffffff
	shl s0, s0, 16
	or s0, s0, 0x64
	store_32 s1, (s0)
1:	goto 1b
.endm

.macro START_ALL_THREADS 
	move s0, 0xffffffff
	shl s0, s0, 16
	or s0, s0, 0x60
	move s1, 0xffffffff
	store_32 s1, (s0)
.endm
