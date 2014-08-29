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
# Validate shuffle and getlane instructions
#


				.globl _start
_start:			load_v v0, shuffle_indices
				load_v v1, shuffle_values
				shuffle v2, v1, v0
				
				getlane s1, v1, 1
				getlane s1, v1, 2
				move s0, 3
				getlane s1, v1, s0
				
				setcr s0, 29
done: 			goto done

				.align 64
shuffle_indices: .long 12, 4, 7, 0, 14, 1, 15, 10, 9, 5, 2, 11, 6, 8, 3, 13
shuffle_values: .long 0xd47c22a3, 0x2f8789dc, 0x2441bc05, 0x926a7525, 0x59cf7a0f, 0x1bd540f8, 0x7fbfa499, 0x2b5f3644
				.long 0x87c70592, 0x98b2d078, 0x84f6f597, 0xfa8de8f0, 0x6e56e899, 0x27d7de84, 0x9d750442, 0xc8816f8b
