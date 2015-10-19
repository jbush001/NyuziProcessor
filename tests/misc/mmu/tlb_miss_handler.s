

					.globl tlb_miss_handler
tlb_miss_handler:	setcr s0, 11		# Save register in scratchpad
					setcr s1, 12
					getcr s0, 5			# Get fault virtual address
					setcr s0, 8			# Set physical address
					getcr s1, 3			# Get fault reason
					cmpeq_i s1, s1, 5	# Is ITLB miss?
					btrue s1, fill_itlb
fill_dltb:			setcr s0, 10
					goto done
fill_itlb:			setcr s0, 9
done:				getcr s0, 11
					getcr s1, 12
					eret
