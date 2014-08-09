# 
# Copyright (C) 2011-2014 Jeff Bush
# 
# This library is free software# you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation# either
# version 2 of the License, or (at your option) any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY# without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
# 
# You should have received a copy of the GNU Library General Public
# License along with this library# if not, write to the
# Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
# Boston, MA  02110-1301, USA.
# 

#
# Blink LEDs on fpga board in sequence
#

                .global     _start

_start:	        load_32     s0, device_addr # LED Device address
		        move        s1, 1           # Current display value
                load_32     s3, delay       # Delay

loop0:	        store_32    s1, (s0)	    # Update LEDs

		        # Wait 500 ms
                move        s4, s3
delay0:	        sub_i       s4, s4, 1
                btrue       s4, delay0

		        # Rotate left
                shl         s1, s1, 1

		        # Check if we've wrapped
                shr         s2, s1, 18
                bfalse      s2, loop0

                move        s1, 1
				goto        loop0

device_addr:    .long 0xFFFF0000
delay:          .long 3000000
