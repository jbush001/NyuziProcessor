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

#define tmp s0
#define ptr s1
#define ycoord s2
#define mask s3
#define max_iterations s4
#define four s5
#define cmpresult s6
#define xstep s7
#define ystep s8
#define xleft s9
#define ytop s10

#define xcoord v0
#define x v1
#define y v2
#define xx v3
#define yy v4
#define tmp0 v5
#define x0 v6
#define y0 v7
#define iteration v8


c_four:		.float 4.0
c_xleft:	.float -2.0
c_xstep: 	.float 0.00390625		; 2.5 / 640
c_ytop:		.float -1.0
c_ystep:	.float 0.004166666		; 2.0 / 480
c_fb_addr:	.long 0x10000000

				.globl _start
_start:			move tmp, 15
				setcr tmp, 30				; start all strands

				; Load some constants
				load_32 four, c_four
				load_32 xleft, c_xleft
				load_32 xstep, c_xstep
				load_32 ytop, c_ytop
				load_32 ystep, c_ystep
				move max_iterations, 255

new_frame:		getcr tmp, 0				; get my strand id
				shl tmp, tmp, 4				; Multiply by 16 pixels
				load_v xcoord, initial_xcoords
				add_i xcoord, xcoord, tmp	; Add strand offset
				move ycoord, 0
				
				load_32 ptr, c_fb_addr
				getcr tmp, 0			; get my strand id
				shl tmp, tmp, 6			; Multiply by 64 bytes
				add_i ptr, ptr, tmp		; Offset pointer to interleave

				; Set up to compute pixel values
fill_loop:		xor x, x, x
				xor y, y, y		
				xor iteration, iteration, iteration

				; Convert coordinate space				
				itof x0, xcoord
				mul_f x0, x0, xstep
				add_f x0, x0, xleft
				itof y0, ycoord
				mul_f y0, y0, ystep
				add_f y0, y0, ytop
				
				; Determine if pixels are part of the set (16 pixels at a time)
escape_loop:	mul_f xx, x, x
				mul_f yy, y, y
				add_f tmp0, xx, yy
				setlt_f mask, tmp0, four
				setlt_f cmpresult, iteration, max_iterations
				and mask, mask, cmpresult		; while (x**2 + y**2 < 4 && iteration < max_iteration)
				bfalse mask, write_pixels
				
				; y = 2 * x * y + y0
				mul_f y, x, y			
				add_f y, y, y			; times two
				add_f y, y, y0
				
				; x = x**2 - y**2 + x0
				sub_f x, xx, yy
				add_f x, x, x0
				add_i_mask iteration, mask, iteration, 1
				goto escape_loop

				; Write out pixels
write_pixels:	seteq_i mask, iteration, max_iterations	; Determine which pixels are in the set and save it

				; Scale up colors for more contrast
				shl iteration, iteration, 2
				add_i iteration, iteration, 40
				setgt_i cmpresult, iteration, 255

				; Clamp values that have overflowed
				move tmp, 255
				move_mask iteration, cmpresult, tmp

				xor_mask iteration, mask, iteration, iteration		; Color pixels in the set black
				store_v iteration, (ptr)
				dflush ptr
				
				; Increment horizontally. Strands are interleaved,
				; each one does 16 pixels, then skips forward 64.
				add_i ptr, ptr, 256
				add_i xcoord, xcoord, 64

				getlane tmp, xcoord, 0
				setlt_i tmp, tmp, 640
				btrue tmp, fill_loop

				; Past end of line.  Wrap around to the next line.
				sub_i xcoord, xcoord, 640 
				add_i ycoord, ycoord, 1
				seteq_i tmp, ycoord, 480
				bfalse tmp, fill_loop

done:			goto done

				.align 64
initial_xcoords: .long 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15

