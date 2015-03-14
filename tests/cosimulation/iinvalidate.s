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

# This test patches a nop instruction in the middle of a loop to convert it
# to a jump out of the loop
# This test should fail if the iinvalidate is commented out.

			.globl _start

_start:		lea s0, jumploc
			load_32 s1, newinst

looptop:	move s10, 1
jumploc:	nop				# This location will be patched
1:			move s10, 2

			# patch instruction to jump out of loop
			store_32 s1, (s0)
			iinvalidate s0
			membar
			goto looptop		

			# Control will flow here after patch
breakout:	move s10, 3
			setcr s0, 29
done: 		goto done


newinst:	.long	0xf6000280	; goto +20			
