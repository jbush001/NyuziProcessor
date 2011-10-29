
; s30 - stack pointer

_start			s30 = s30 + 256		; Initialize stack
				s0 = &sort_array
				s1 = mem_l[strlen]
				s7 = pc + 8
				mem_l[s30] = s7				; save return address
				goto quicksort
done			goto done

sort_array		.byte 5, 7, 1, 8, 2, 4, 3, 6
strlen			.word	8


; void quicksort(char *array, int length)
;
; s0 - array
; s1 - length
; s2 - storeIndex
; s3 - checkIndex
; s4 - pivotValue
; s5, s6, s7 - temp
;

quicksort	; pivotValue = array[length - 1];
			s5 = s0 + s1
			s5 = s5 - 1
			s4 = mem_b[s5]

			; storeIndex = 0
			s2 = s2 ^ s2

			;for (checkIndex = 0; checkIndex < length - 1; checkIndex++)
			s3 = s3 ^ s3
loop0		s5 = s1 - 1
			s5 = s3 < s5
			bfalse s5, loopdone

			; if (array[checkIndex] <= pivotValue)
			s5 = s0 + s3
			s5 = mem_b[s5]
			s5 = s5 <= s4
			bfalse s5, endif0

			; {
			; temp = array[checkIndex];
			s5 = s0 + s3
			s5 = mem_b[s5]

			; array[checkIndex] = array[storeIndex];
			s6 = s0 + s2
			s6 = mem_b[s6]
			s7 = s0 + s3
			mem_b[s7] = s6

			; array[storeIndex] = temp;
			s6 = s0 + s2
			mem_b[s6] = s5

			; storeIndex = storeIndex + 1;
			s2 = s2 + 1
			; }

endif0		; }
			s3 = s3 + 1
			goto loop0

loopdone	; temp = array[storeIndex];
			s5 = s0 + s2
			s5 = mem_b[s5]

			; array[storeIndex] = pivotValue;
			s6 = s0 + s2
			mem_b[s6] = s4

			; array[length - 1] = temp;
			s6 = s0 + s1
			s6 = s6 - 1
			mem_b[s6] = s5

			; if (storeIndex > 1)
			s5 = s2 > 1
			bfalse s5, skip0

			; sort(array, storeIndex);
			s30 = s30 - 16				; reserve stack space
			mem_l[s30 + 12] = s0		; save base ptr
			mem_l[s30 + 8] = s1			; save length
			mem_l[s30 + 4] = s2			; save right pointer
			s1 = s2						; update length
			s5 = pc + 8
			mem_l[s30] = s5				; save return address
			goto quicksort
			s2 = mem_l[s30 + 4]
			s1 = mem_l[s30 + 8]
			s0 = mem_l[s30 + 12]
			s30 = s30 + 16

			; if (storeIndex < length - 1)
skip0		s5 = s1 - 1
			s5 = s2 < s5
			bfalse s5, skip1

			; sort(array + storeIndex, length - storeIndex);
			s0 = s0 + s2				; array + storeIndex
			s1 = s1 - s2				; length - storeIndex
			s30 = s30 - 4
			s5 = pc + 8
			mem_l[s30] = s5				; save return address
			goto quicksort
			s30 = s30 + 4
skip1		pc = mem_l[s30]
