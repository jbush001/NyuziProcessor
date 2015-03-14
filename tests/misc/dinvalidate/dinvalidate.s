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


# This test writes something to the cache, then uses dinvalidate to remove it.

			.globl _start

_start:		lea s0, dataloc
			load_32 s1, storedat
			store_32 s1, (s0)
			dinvalidate s0		# This should blow away the word we just stored
			membar
			load_32 s2, (s0)	# Reload it to ensure the old value is still present
			setcr s0, 29
done: 		goto done
storedat:	.long	0x12345678

			.align 128
dataloc:	.long	0xdeadbeef			; will be at address 256
