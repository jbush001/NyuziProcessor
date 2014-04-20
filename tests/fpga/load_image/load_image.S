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

; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
; 
;     http://www.apache.org/licenses/LICENSE-2.0
; 
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.
; 

;
; Load a bitmap over the serial port and display it on the monitor
;

                .globl      _start
_start:			load_32     s0, fb_addr		; Address of SDRAM
				load_32     s1, count   	; count
				load_32     s2, device_base ; device base

wait_char:		load_32     s3, 0x18(s2)    ; check status register
				and         s3, s3, 2		; check RX FIFO bit				
				bfalse      s3, wait_char	; nothing ready, wait...

                load_32     s3, 0x1c(s2)    ; read a character from serial
                store_8     s3, (s0)        ; store in framebuffer

                ; Flush at every cache line boundary
                and         s3, s0, 63
                seteq_i     s3, s3, 63
                bfalse      s3, noflush
                dflush      s0

                ; Increment and loop
noflush:		add_i       s0, s0, 1
				sub_i       s1, s1, 1
                btrue       s1, wait_char
done:		    goto    done
                
fb_addr:        .long       0x10000000
count:          .long       640 * 480 * 4
device_base:    .long       0xffff0000




