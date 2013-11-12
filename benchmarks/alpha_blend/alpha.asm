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

							NUM_STRANDS = 2

alphablend:					.enterscope
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

mainloop:					srcPixel = mem_l[src]	
							dstPixel = mem_l[dst]
							srcAlpha = srcPixel >> 24	# Grab alpha
							oneMinusSrcAlpha = 255
							oneMinusSrcAlpha = oneMinusSrcAlpha - srcAlpha
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
							dst = dst + (64 * NUM_STRANDS)
							src = src + (64 * NUM_STRANDS)
							count = count - 1
							if count goto mainloop
							pc = link

							.emitliteralpool
							.exitscope

_start:						.enterscope

							.regalias src s0
							.regalias dest s1
							.regalias count s2
							.regalias temp s3
							.regalias strandid s4
							
							temp = ((1 << NUM_STRANDS) - 1)
							cr30 = temp				; Start strands		
							strandid = cr0				; Get my strand ID

							dest = &data_start		; start of destination buffer
							temp = 1
							temp = temp << 14 		; 64 * 64 * 4 bpp (total size of buffer)
							src = dest + temp		; compute start of start buffer
							
							temp = strandid << 6		; Multiple strand ID by 64
							dest = dest + temp			; Set initial offset for each strand
							src = src + temp
		
							count = 256 / NUM_STRANDS	; Count

							call alphablend
							
                            cr29 = s0
done:                       goto done

							.emitliteralpool
							
running_strands:			.word NUM_STRANDS				
							
							.align 1024
data_start:					.exitscope
														
