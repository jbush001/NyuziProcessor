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
; Build a binary tree in memory, then traverse it.
;


;
;	struct node {	// 12 bytes
;		int index;
;		node *left;
;		node *right;
;	};
;
_start:			u0 = 7	; depth
				u29 = 1
				u29 = u29 << 16
				u29 = u29 - 4		; Set stack pointer to 0x10000 - 4

				call make_tree
				call walk_tree
				cr31 = s0			; Halt

; 
; int walk_tree(struct node *root);
;
walk_tree:		; Prolog
				sp = sp - 12
				mem_l[sp] = link
				mem_l[sp + 4] = s15		; s15 is the pointer to the root
				mem_l[sp + 8] = s16		; s16 is the count of this & children
				s15 = s0
				; 
				
				s16 = mem_l[s15]		; get index of this node

				s0 = mem_l[s15 + 4]		; check left child
				if !s0 goto leafnode	; if i'm a leaf, then skip
				call walk_tree			
				s16 = s16 + s0
				
				s0 = mem_l[s15 + 8]		; check right child
				call walk_tree
				s16 = s16 + s0
				
				; Epilog
leafnode:		s0 = s16
				s16 = mem_l[sp + 8]
				s15 = mem_l[sp + 4]
				link = mem_l[sp]
				sp = sp + 12
				pc = link

;
; struct node *make_tree(int depth);
;
make_tree:		; Prolog
				sp = sp - 12
				mem_l[sp] = link
				mem_l[sp + 4] = s15		; s15 is stored depth
				mem_l[sp + 8] = s16		; s16 is stored node pointer
				s15 = s0
				;
				
				; Allocate this node
				s0 = 12					; size of a node
				call allocate
				s16 = s0
				
				; Allocate an index for this node and increment
				; the next index
				s4 = mem_l[next_node_id]
				mem_l[s16] = s4
				s4 = s4 + 1
				mem_l[next_node_id] = s4
				
				s0 = s15 - 1		; Decrease depth by one
				if !s0 goto no_children
				call make_tree
				mem_l[s16 + 4] = s0	; stash left child

				s0 = s15 - 1
				call make_tree
				mem_l[s16 + 8] = s0	; stash right child

				; Epilog
no_children:	s0 = s16			; return this node
				s16 = mem_l[sp + 8]
				s15 = mem_l[sp + 4]
				link = mem_l[sp]
				sp = sp + 12
				pc = link
				
next_node_id:	.word 1

;
; void *allocate(int size);
;
allocate:		s1 = mem_l[heap_end]
				s2 = s1 + s0
				s0 = s1
				mem_l[heap_end] = s2
				pc = link
heap_end:		.word	1024
