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

;
; Alpha blend a source image with a destination buffer
; Format of framebuffer is BGRA, but we are little endian, so everything is swapped
;

alphablend					.enterscope
							.regalias src s0
							.regalias dst s1
							.regalias count s2
							.regalias srcPixel vu0
							.regalias dstPixel vu1
							.regalias srcAlpha vu2
							.regalias srcComponent vu3
							.regalias dstComponent vu4
							.regalias newPixel vu5
							.regalias oneMinusSrcAlpha vu6

mainloop					srcPixel = mem_l[src]	
							srcAlpha = srcPixel >> 24	# Grab alpha
							oneMinusSrcAlpha = 255
							oneMinusSrcAlpha = oneMinusSrcAlpha - srcAlpha
							dstPixel = mem_l[dst]
							newPixel = 0
							
							; Blue
							srcComponent = srcPixel & 0xff
							srcComponent = srcComponent * srcAlpha
							dstComponent = dstPixel & 0xff
							dstComponent = dstComponent * oneMinusSrcAlpha
							dstComponent = dstComponent + srcComponent
							dstComponent = dstComponent >> 8	; Normalize
							newPixel = dstComponent
							
							; Green
							srcComponent = srcPixel >> 8
							srcComponent = srcComponent & 0xff
							srcComponent = srcComponent * srcAlpha
							dstComponent = dstPixel >> 8
							dstComponent = dstComponent & 0xff
							dstComponent = dstComponent * oneMinusSrcAlpha
							dstComponent = dstComponent + srcComponent
							dstComponent = dstComponent >> 8	; Normalize
							
							dstComponent = dstComponent << 8	; Put in proper position
							newPixel = newPixel | dstComponent

							; Red
							srcComponent = srcPixel >> 16
							srcComponent = srcComponent & 0xff
							srcComponent = srcComponent * srcAlpha
							dstComponent = dstPixel >> 16
							dstComponent = dstComponent & 0xff
							dstComponent = dstComponent * oneMinusSrcAlpha
							dstComponent = dstComponent + srcComponent
							dstComponent = dstComponent >> 8	; Normalize

							dstComponent = dstComponent << 16	; Put in proper position
							newPixel = newPixel | dstComponent

							; Alpha
							dstComponent = 0xff
							dstComponent = dstComponent << 24
							newPixel = newPixel | dstComponent
							
							mem_l[dst] = newPixel
							dflush(dst)
							dst = dst + (64 * 4)
							src = src + (64 * 4)
							count = count - 1
							if count goto mainloop
							pc = link
							.exitscope

_start						s2 = 0xf
							cr30 = s2				; Start all strands		
							s2 = cr0				; Get my strand ID

							s3 = s2 << 6			; Multiple strand ID by 64
													; strands interleave accesses

							s1 = &data_start		; Dest
							s2 = 1
							s2 = s2 << 14			; 64 * 64 * 4
							s0 = s1 + s2			; Src
							s1 = s1 + s3			; Set interleave offset
							s0 = s0 + s3
		
							s2 = 64					; Count

							call alphablend
							
							; Update number of finished strands
							s0 = &running_strands
retry						s1 = mem_sync[s0]
							s1 = s1 - 1
							mem_sync[s0] = s1
							if !s1 goto retry

wait_done					s0 = mem_l[running_strands]
							if s0 goto wait_done
							cr31 = s0				; halt
							
running_strands				.word 4					
							
							.align 1024
data_start
														
