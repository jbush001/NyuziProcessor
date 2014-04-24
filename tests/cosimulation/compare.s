
.equ BU, 0xc0800018
.equ BS, 0x60123498
.equ SM, 1

			.globl _start
_start:		lea s0, vec1
			load_v v0, (s0)
			load_v v1, 64(s0)

			seteq_i s0, v0, v1
			setne_i s1, v0, v1
			setgt_i s2, v0, v1
			setlt_i s3, v0, v1
			setge_i s4, v0, v1
			setle_i s5, v0, v1
			setgt_u s6, v0, v1
			setlt_u s7, v0, v1
			setge_u s8, v0, v1
			setle_u s9, v0, v1

			load_32 s20, val3
			seteq_i s0, v0, s20
			setne_i s1, v0, s20
			setgt_i s2, v0, s20
			setlt_i s3, v0, s20
			setge_i s4, v0, s20
			setle_i s5, v0, s20
			setgt_u s6, v0, s20
			setlt_u s7, v0, s20
			setge_u s8, v0, s20
			setle_u s9, v0, s20
			
			load_32 s21, val4
			seteq_i s0, s21, s20
			setne_i s1, s21, s20
			setgt_i s2, s21, s20
			setlt_i s3, s21, s20
			setge_i s4, s21, s20
			setle_i s5, s21, s20
			setgt_u s6, s21, s20
			setlt_u s7, s21, s20
			setge_u s8, s21, s20
			setle_u s9, s21, s20

			setcr s0, 29
done: 		goto done

			.align 64
vec1: .long BU, BS, BU, BS, BU, SM, BS, SM, BU, BS, BU, BS, BU, SM, BS, SM 
vec2: .long BU, BS, BS, BU, SM, BU, SM, BS, BU, BS, BS, BU, SM, BU, SM, BS
val3: .long BU
val4: .long BS
