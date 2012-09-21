; 
; Copyright 2011-2012 Jeff Bush
; 
; Licensed under the Apache License, Version 2.0 (the "License");
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

do_mandelbrot	.enterscope
				; params
				.regalias dest s0
				.regalias x0in f1
				
				; temporaries
				.regalias x0 vf0
				.regalias x vf1
				.regalias y vf2
				.regalias tmp0 vf3
				.regalias colorVec v4
				.regalias xx vf5
				.regalias yy vf6

				.regalias mask s5
				.regalias cmpresult s6
				.regalias four f7
				.regalias maxIteration s8
				.regalias ystep f9
				.regalias rowCount s10
				.regalias tmp3 f11
				.regalias tmp4 f12
				.regalias iteration s13
				.regalias y0 f14

				four = mem_l[_four]
				tmp3 = mem_l[_xlargestep]
				tmp3 = tmp3 * x0in
				tmp4 = mem_l[_minus_two_point_five]
				tmp3 = tmp3 + tmp4
				x0 = mem_l[_xsmallstep]
				x0 = x0 + tmp3
				ystep = mem_l[_ystep]
				y0 = mem_l[minus_one]
				
				colorVec = 0
				colorVec = colorVec - 1	; 0xffffffff white
				rowCount = 64

loop0top		iteration = 75
				mask = 0
				v1 = 0		; x
				v2 = 0		; y
				
loop1top		xx = x * x
				yy = y * y
				tmp0 = xx + yy
				cmpresult = tmp0 >= four
				mask = mask | cmpresult
				if all(mask) goto loop1done
				y = x * y			; y = 2 * x * y + y0
				y = y + y			; times two
				y = y + y0
				x = xx - yy
				x = x + x0
				iteration = iteration - 1
				if iteration goto loop1top

loop1done		mem_l[dest]{mask} = colorVec
				dflush(dest)
				dest = dest + (64 * 4)		; stride, one scanline
				y0 = y0 + ystep
				rowCount = rowCount - 1
				if rowCount goto loop0top
				pc = link

_four			.float 4.0		
_xlargestep		.float 0.875 ; 3.5 / 4
_ystep			.float 0.03125	; 2 / 64
minus_one		.float -1.0
_minus_two_point_five .float -2.5
				.align 64
_xsmallstep		.float 0.0, 0.0546875, 0.109375, 0.1640625, 0.21875, 0.2734375
				.float 0.328125, 0.3828125, 0.4375, 0.4921875, 0.546875
				.float 0.6015625, 0.65625, 0.7109375, 0.765625, 0.8203125 ; steps of 3.5 / 64
				.exitscope

_start			s2 = 0xf
				cr30 = s2				; Start all strands		

				; Compute destination framebuffer address (s0)
				s0 = cr0				; Get my strand ID
				s0 = s0 << 6			; Multiply strand ID by 64 (interleave accesses)
				s1 = &fb_start			; Dest
				s0 = s0 + s1			; interleave

				; Compute x offset for strands (floating point number 0-3)
				s1 = cr0
				f2 = mem_l[_one]		
				f1 = sitof(s1, f2)

				call do_mandelbrot

				; Update number of finished strands
				s0 = &running_strands
retry			s1 = mem_sync[s0]
				s1 = s1 - 1
				s2 = s1
				mem_sync[s0] = s1
				if !s1 goto retry

wait_done		if s2 goto wait_done	; Will fall through on last ref (s2 = 1)
				cr31 = s0				; halt
				
running_strands	.word 4				
_one			.float 1.0

				.align 1024
fb_start
				
				