
			.regalias count s1
			.regalias source s2
			.regalias dest s3
			.regalias temp s4

_start		count = mem_l[length]
			source = &dataStart
			dest = source + count
			
loop		temp = mem_b[source]
			mem_b[dest] = temp
			source = source + 1
			dest = dest + 1
			count = count - 1
			if count goto loop
			
			cr31 = s0		; halt simulation

length			.word 2048
dataStart		.word 0
