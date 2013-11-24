; 
; Copyright 2013 Jeff Bush
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
; Common startup code for all tests. Sets up stack, calls main, then stops
; simulation
;

					.text
					.globl _start
					.align 4
					.type _start,@function
_start:				load_32 sp, stack_top
					call main
					setcr s0, 29		; Stop thread
done:				goto done

stack_top:			.long 0xfffc0