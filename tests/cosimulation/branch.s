# 
# Copyright (C) 2011-2014 Jeff Bush
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
# 


#
# Test all branch types
#


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
			move s10, 3
			goto 2f
1:			move s10, 4

# bfalse, not taken
2:			bfalse s0, 1f
			move s10, 5
			goto 2f
1:			move s10, 6


# btrue, taken
2:			btrue s0, 1f
			move s10, 7
			goto 2f
1:			move s10, 8

# btrue, not taken
2:			btrue s1, 1f
			move s10, 9
			goto 2f
1:			move s10, 10

# ball, taken
2:			ball s2, 1f
			move s10, 11
			goto 2f
1:			move s10, 12

# ball, not taken, zero
2:			ball s1, 1f
			move s10, 13
			goto 2f
1:			move s10, 14

# ball, not taken, some bits
2:			ball s0, 1f
			move s10, 15
			goto 2f
1:			move s10, 16

# bnall not taken
2:			bnall s2, 1f
			move s10, 17
			goto 2f
1:			move s10, 18

# bnall, taken, zero
2:			bnall s1, 1f
			move s10, 19
			goto 2f
1:			move s10, 20

# bnall, not taken, some bits
2:			bnall s0, 1f
			move s10, 21
			goto 2f
1:			move s10, 22

# Call
2:			call calltest1
calltest1:	move s10, 23

# Call register
			lea s0, calltest2
			call s0
calltest2: 	move s10, 24
			
# Load PC from memory
			lea s1, pcloaddest
			load_32 pc, (s1)
			move s11, 123		# This should not happen
pcloaddest:	.long pcloadhere
pcloadhere:	move s10, 1

# Load PC from register
			lea s1, pcarithhere
			move pc, s1
			move s10, 25
pcarithhere: move s10, 26

# Make sure vector moves don't trigger branch
			move v31, s1
			move s10, 27

			setcr s0, 29
done: 		goto done
