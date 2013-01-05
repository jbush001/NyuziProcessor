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


;
; Vectorized count bits
;

_start:			u2 = 15
				cr30 = u2		; Start all threads
				v0 = mem_l[initialVec]
				
loop0:			u2 = v0 <> 0
				if !u2 goto done
				v1{u2} = v0 - 1
				v0{u2} = v0 & v1
				v2{u2} = v2 + 1
				goto loop0
				
done:			cr31 = s0		; stop all threads

				.align 64
initialVec:		.word 0x36d3b84, 0xf068351, 0x3deda6e, 0x3d8548c, 0x674a952
				.word 0xb271cbf, 0xc04de04, 0x7559cbd, 0x1dd6f9d, 0xbf2c0d5 
				.word 0xed99b36, 0x659fe9, 0x59bbe4c, 0xb838c34, 0x5757a0c, 0x9d6abe6