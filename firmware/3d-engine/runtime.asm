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

; Memory map
;
;  0 - Start of code
;  ... - end of code
;  0x10000 Start of buffers
;  0xf8000 strand 0 stack base
;  0xf9000 strand 1 stack base
;  0xfa000 strand 2 stack base
;  0xfb000 strand 3 stack base
;  0xfc000 Frame buffer start (frame buffer is 64x64 pixels, ARGB)
;  0x100000 Frame buffer end, top of memory
;
; All vector registers are callee save. Scalar registers are used as follows:
;   0: return value
;   0-3: parameters
;   4-11: caller save.  Leaf functions should use these.  Also temporaries that
;     are not saved across function calls.
;   12-28: callee save. Variables that are saved across function calls should go here.
;
; SP points to top of stack (decrement before push, increment after pop)
;

;
; struct Job {
;      Job *next;
;      int stage;
;      char data[];
; };
;

					JOB_SIZE = 32		; 8 words

jobLock:				.word 0
fenceActiveJobCount:	.word 0
readyJobList:			.word 0
freeJobList:			.word 0
jobAllocWilderness:		.word 0x10000


;
; Allocate a new job buffer
;
AllocateJob:		.enterscope

					.regalias tmp u12
					
					.saveregs u12, link

					; Acquire lock
					u0 = &@jobLock
					call @AcquireSpinlock

					; Try to pull a job from the free list
					s0 = mem_l[@freeJobList]	; retval
					if !s0 goto extend

					; There was a free job buffer on the free list, dequeue it
					tmp = mem_l[s0]
					mem_l[@freeJobList] = tmp
					goto done
		
					; No free jobs available, carve from wilderness area
extend:				s0 = mem_l[jobAllocWilderness]
					tmp = s0 + JOB_SIZE
					mem_l[jobAllocWilderness] = tmp

done:				; Release lock
					tmp = 0
					mem_l[@jobLock] = tmp 
					stbar

					.restoreregs u12, link
					pc = link
					.exitscope

;
; Add a job to the main job queue.  We always add to the front so data for
; later stages is processed first.  This allows the queue to drain so we 
; don't run out of buffers.
; u0 - job
; u1 - stage
;
EnqueueJob:			.enterscope
					.regalias tmp u4
					.regalias job u12
					.regalias stage u13

					; Prolog.  Save registers and copy parameters.
					.saveregs u12, u13, link
					job = u0
					stage = u1

					; Acquire lock
					u0 = &@jobLock
					call @AcquireSpinlock

					; Add item to ready queue
					tmp = mem_l[@readyJobList]
					mem_l[job] = tmp			; job->next = readyJobList
					mem_l[@readyJobList] = job	; readyJobList = job
					mem_l[job + 4] = stage

					; Release lock
					tmp = 0
					mem_l[@jobLock] = tmp 
					stbar

					.restoreregs u12, u13, link
					pc = link				; return
					.exitscope

;
; u0 = pointer to lock
;

AcquireSpinlock:	.enterscope
tryLock:			u4 = mem_sync[u0]
					if u4 goto tryLock
					u4 = 1
					mem_sync[u0] = u4
					if !u4 goto tryLock
					pc = link
					.exitscope

;
; u0 = pointer to lock
;

FastSpinlock:		.enterscope
tryLock:			u4 = mem_sync[u0]
					if u4 goto busyWait
					u4 = 1
					mem_sync[u0] = u4
					if u4 goto acquired
busyWait:			u4 = mem_l[u0]          ; check L1 cache without generating L2 request
					if u4 goto busyWait
					goto tryLock
					if !u4 goto tryLock
acquired:			pc = link
					.exitscope


;
; Main execution loop for strands (never returns)
; 
StrandMain:			.enterscope
					.regalias function u4
					.regalias tmp u5
					.regalias base u6
					.regalias job u12
					
workLoopTop:		; Lock the job queue
					u0 = &@jobLock
					call @AcquireSpinlock	
	
					; Get a pointer to the first job in the queue
					job = mem_l[@readyJobList]
					if !job goto noWork

					; Is this a fence?
					tmp = mem_l[job + 4]		; read type
					if tmp goto dequeueJob		; If this is not a fence, continue
			
					; Yes, this is a fence.  Check if there are active jobs.
					tmp = mem_l[@fenceActiveJobCount]
					if !tmp goto dequeueJob		; no pending jobs, can continue

					; Unlock job queue
noWork:				tmp = 0
					mem_l[@jobLock] = tmp
					stbar

					; Busy loop that doesn't do an expensive spinlock
waitForJobs:		tmp = mem_l[@readyJobList]
					if !tmp goto waitForJobs
					goto workLoopTop
					
dequeueJob:			; remove the job from the queue
					tmp = mem_l[job]
					mem_l[@readyJobList] = tmp

					; Increment pending job count
					tmp = mem_l[@fenceActiveJobCount]
					tmp = tmp + 1
					mem_l[@fenceActiveJobCount] = tmp

					; Unlock the job queue					
					tmp = 0
					mem_l[@jobLock] = tmp
					stbar

					; Invoke the job.  First find the pointer to the handler.
					tmp = mem_l[job + 4]		; get stage index
					tmp = tmp << 2				; multiply by 4
					base = &@jobTable
					tmp = tmp + base
					function = mem_l[tmp]

					u0 = job + 8				; pointer to data
					call function

					; Lock the job queue					
					u0 = &@jobLock
					call @AcquireSpinlock				

					; put job buffer back in free list
					tmp = mem_l[@freeJobList]
					mem_l[job] = tmp
					mem_l[@freeJobList] = job
	
					; Decrement pending job count
					tmp = mem_l[@fenceActiveJobCount]
					tmp = tmp - 1
					mem_l[@fenceActiveJobCount] = tmp
	
					; Unlock the job queue
					tmp = 0
					mem_l[@jobLock] = tmp
					stbar

					goto workLoopTop

					.exitscope

;
; Handles fence.  For now, this is a no-op, but it could restore the previous fence
; count (that is necessary to support multiple fences. Since we only use one
; for now, we'll cheat).
;
HandleFence:		pc = link

; Here is where the stages are defined
jobTable:			.word	HandleFence, 		; 0
							StartFrame, 		; 1
							FinishFrame,		; 2
							FillMasked,			; 3
							FillRects,			; 4
							RasterizeTriangle	; 5

;
; Main entry point for all strands at startup
;
_start:				.enterscope
					u0 = cr0			; get strand ID
					u0 = u0 << 2
					u1 = &stackPtrs
					u1 = u1 + u0
					sp = mem_l[u1]		; set up stack
					
					u0 = cr0
					if u0 goto @StrandMain	; Skip initialization

					; Insert cleanup job
					call @AllocateJob
					u1 = 2		; stage
					call @EnqueueJob

					; Insert a fence
					call @AllocateJob
					u1 = 0					; fence code
					call @EnqueueJob

					; Insert initial job
					call @AllocateJob
					u1 = 1		; start frame
					call @EnqueueJob

					u0 = 0xf
					cr30 = u0			; start all strands

					goto @StrandMain

stackPtrs:			.word 0xf8ffc, 0xf9ffc, 0xfaffc, 0xfbffc
heapStart:			.word 0x10000
					.exitscope
					
