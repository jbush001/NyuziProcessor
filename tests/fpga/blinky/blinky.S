# 
# Copyright 2011-2015 Jeff Bush
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
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
