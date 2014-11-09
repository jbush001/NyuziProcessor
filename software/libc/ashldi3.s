# 
# Copyright (C) 2011-2014 Jeff Bush
# 
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
# 
# You should have received a copy of the GNU Library General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
# Boston, MA  02110-1301, USA.
# 

#
# Arithmetic shift left of a 64 bit integer.  The param to be shifted is in s0, s1
# and the shift amount is in s2
#

					.global __ashldi3
__ashldi3:			move s3, 32
					sub_i s3, s3, s2
					shr s3, s1, s3	# Align bits that will be shifted in
					shl s0, s0, s2	# Shift upper word 
					or s0, s0, s3	# Fill in bits in upper word
					shl s1, s1, s2	# Shift lower word
					move pc, ra		

