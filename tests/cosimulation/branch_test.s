			.globl _start
_start:
			move s0, 1
			move s1, 0
			move s2, -1

# Unconditional Branch
test0:		goto 1f
			move s10, 1
			goto 2f
1:			move s10, 2

# bfalse, taken
2:			bfalse s1, 1f
			move s10, 1
			goto 2f
1:			move s10, 2

# bfalse, not taken
2:			bfalse s0, 1f
			move s10, 1
			goto 2f
1:			move s10, 2


# btrue, taken
2:			btrue s0, 1f
			move s10, 1
			goto 2f
1:			move s10, 2

# btrue, not taken
2:			btrue s1, 1f
			move s10, 1
			goto 2f
1:			move s10, 2

# ball, taken
2:			btrue s2, 1f
			move s10, 1
			goto 2f
1:			move s10, 2

# ball, not taken, zero
2:			btrue s1, 1f
			move s10, 1
			goto 2f
1:			move s10, 2

# ball, not taken, some bits
2:			btrue s0, 1f
			move s10, 1
			goto 2f
1:			move s10, 2

# bnall not taken
2:			btrue s2, 1f
			move s10, 1
			goto 2f
1:			move s10, 2

# bnall, taken, zero
2:			btrue s1, 1f
			move s10, 1
			goto 2f
1:			move s10, 2

# bnall, taken, some bits
2:			btrue s0, 1f
			move s10, 1
			goto 2f
1:			move s10, 2

# Call
2:			call calltest1
calltest1:	move s10, 1

# Call register
			lea s0, calltest2
calltest2: 	move s10, 2
			
			setcr s0, 29
done: 		goto done
