# 
# Copyright 2015 Jeff Bush
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# 

#
# Identity map memory
#

						.globl tlb_miss_handler
tlb_miss_handler:		setcr s0, 11		# Save s0 in scratchpad
						setcr s1, 12        # Save s1
						getcr s0, 5			# Get fault virtual address
						getcr s1, 3			# Get fault reason
						cmpeq_i s1, s1, 5	# Is ITLB miss?
						btrue s1, fill_itlb # If so, branch to update ITLB
fill_dltb:				or s0, s0, 2		# Set write enable bit
						getcr s1, 5			# Get virtual address
						dtlbinsert s1, s0
						goto done
fill_itlb:				getcr s1, 5			# Get virtual address
						itlbinsert s1, s0
done:					getcr s0, 11        # Get saved s0 from scratchpad
						getcr s1, 12        # Get saved s1
						eret

						.globl enable_mmu
enable_mmu:				setcr ra, 2			# Set exception PC to return address
						move s0, 8
						setcr s0, 4			# Set prev MMU enable
						eret				# Enable everything and return