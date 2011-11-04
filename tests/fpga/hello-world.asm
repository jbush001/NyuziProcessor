
_start			s0 = mem_l[ser_addr]
				s1 = &message
loop			s2 = mem_b[s1]
				bzero s2, done
				mem_l[s0] = s2
				s1 = s1 + 1
				goto loop
done			goto done

ser_addr		.word	0xA0000000
message			.string "HELLO WORLD"
				.byte 0

