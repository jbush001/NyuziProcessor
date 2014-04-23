				.globl _start
				.align 64
value1:			.long 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16
value2:			.long 0xaaaaaaaa, 0xbbbbbbbb, 0xcccccccc, 0xdddddddd, 0xeeeeeeee, 0xffffffff
				.long 0x11111111, 0x22222222, 0x33333333, 0x44444444, 0x55555555, 0x66666666
				.long 0x77777777, 0x88888888, 0x99999999
mask:			.long 0x5a5a

_start:			load_v v0, value1
				load_v v1, value2
				load_32 s0, mask

				# We perform a move each time to ensure the value is actually saved correctly into the register
				add_i v2, v0, v1
				move v20, v2
				sub_i v3, v0, v1
				move v20, v3
				and v4, v0, v1
				move v20, v4
				or v5, v0, v1
				move v20, v5
				xor v6, v0, v1
				move v20, v6
				shr v7, v0, v1
				move v20, v7
				shl v8, v0, v1
				move v20, v8
				clz v9, v0
				move v20, v9
				ctz v10, v0
				move v20, v10
				
				add_i_mask v2, s0, v0, v1
				move v20, v2
				sub_i_mask v3, s0, v0, v1
				move v20, v3
				and_mask v4, s0, v0, v1
				move v20, v4
				or_mask v5, s0, v0, v1
				move v20, v5
				xor_mask v6, s0, v0, v1
				move v20, v6
				shr_mask v7, s0, v0, v1
				move v20, v7
				shl_mask v8, s0, v0, v1
				move v20, v8
				clz_mask v9, s0, v0
				move v20, v9
				ctz_mask v10, s0, v0
				move v20, v10

				add_i_mask v2, s0, v0, v1
				move v20, v2
				sub_i_mask v3, s0, v0, v1
				move v20, v3
				and_mask v4, s0, v0, v1
				move v20, v4
				or_mask v5, s0, v0, v1
				move v20, v5
				xor_mask v6, s0, v0, v1
				move v20, v6
				shr_mask v7, s0, v0, v1
				move v20, v7
				shl_mask v8, s0, v0, v1
				move v20, v8
				clz_mask v9, s0, v0
				move v20, v9
				ctz_mask v10, s0, v0
				move v20, v10

				setcr s0, 29
done: 			goto done
				
