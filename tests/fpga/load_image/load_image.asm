; 
; Copyright 2011-2013 Jeff Bush
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


_start:			s0 = 0x10000000		; Address of SDRAM
				s1 = 640 * 480 * 4	; count
				s2 = 0xffff0000		; device base

wait_char:		s3 = mem_l[s2 + 0x18] ; check status register
				s3 = s3 & 2				; check RX FIFO bit				
				if !s3 goto wait_char	; nothing ready, wait a bit

				; write and update
				s3 = mem_l[s2 + 0x1c] ; read a character
				mem_b[s0] = s3

				s3 = s0 & 63
				s3 = s0 == 63
				if !s3 goto noflush
				dflush(s0)
noflush:		s0 = s0 + 1
				s1 = s1 - 1
				if s1 goto wait_char

done:			goto done



