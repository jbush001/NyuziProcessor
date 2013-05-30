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

_start:			.regalias device_base s0
				.regalias ch s1
				.regalias status s2

				device_base = 0xffff0018
wait_rx_ready:	status = mem_l[device_base]		; Read status register
				status = status == 3			; check that both receive and transmit are ready
				if !status goto wait_rx_ready	; If either is busy, wait

				ch = mem_l[device_base + 4]
				mem_l[device_base + 8] = ch
				goto wait_rx_ready

