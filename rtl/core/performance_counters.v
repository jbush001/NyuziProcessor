// 
// Copyright 2013 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

//
// Collects statistics from various modules used for performance measuring and tuning.  
// Each module may assert a single pc_event_XXX signal when something of interest happens.  
// This module will count the total cycles each signal is asserted.
//
module performance_counters(
	input		clk,
	input 		reset,
	input		pc_event_l2_hit,
	input		pc_event_l2_miss,
	input		pc_event_l1d_hit,
	input		pc_event_l1d_miss,
	input		pc_event_l1d_collided_load,
	input		pc_event_l1i_hit,
	input		pc_event_l1i_miss,
	input		pc_event_l1i_collided_load,
	input		pc_event_store,
	input		pc_event_instruction_issue,
	input		pc_event_instruction_retire,
	input[3:0] 	pc_event_raw_wait,		// One bit for each strand
	input[3:0] 	pc_event_dcache_wait,
	input[3:0]	pc_event_icache_wait,
	input		pc_event_dram_page_miss,
	input		pc_event_dram_page_hit,
	input		pc_event_mispredicted_branch,
	input		pc_event_uncond_branch,
	input		pc_event_cond_branch_taken,
	input		pc_event_cond_branch_not_taken);

	localparam PRFC_WIDTH = 48;

	reg[PRFC_WIDTH - 1:0] l2_hit_count;
	reg[PRFC_WIDTH - 1:0] l2_miss_count;
	reg[PRFC_WIDTH - 1:0] l1d_hit_count;
	reg[PRFC_WIDTH - 1:0] l1d_miss_count;
	reg[PRFC_WIDTH - 1:0] l1i_hit_count;
	reg[PRFC_WIDTH - 1:0] l1i_miss_count;
	reg[PRFC_WIDTH - 1:0] mispredicted_branch_count; 
	reg[PRFC_WIDTH - 1:0] store_count;
	reg[PRFC_WIDTH - 1:0] instruction_issue_count;
	reg[PRFC_WIDTH - 1:0] instruction_retire_count;
	reg[PRFC_WIDTH - 1:0] raw_wait_count;
	reg[PRFC_WIDTH - 1:0] dcache_wait_count;
	reg[PRFC_WIDTH - 1:0] icache_wait_count;
	reg[PRFC_WIDTH - 1:0] dram_page_miss_count;
	reg[PRFC_WIDTH - 1:0] dram_page_hit_count;
	reg[PRFC_WIDTH - 1:0] l1d_collided_load_count;
	reg[PRFC_WIDTH - 1:0] l1i_collided_load_count;
	reg[PRFC_WIDTH - 1:0] uncond_branch_count;
	reg[PRFC_WIDTH - 1:0] cond_branch_taken_count;
	reg[PRFC_WIDTH - 1:0] cond_branch_not_taken_count;


	function count_bits;
		input[3:0] in_bits;
	begin
		count_bits = in_bits[0] + in_bits[1] + in_bits[2] + in_bits[3];
	end
	endfunction

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			cond_branch_not_taken_count <= {PRFC_WIDTH{1'b0}};
			cond_branch_taken_count <= {PRFC_WIDTH{1'b0}};
			dcache_wait_count <= {PRFC_WIDTH{1'b0}};
			dram_page_hit_count <= {PRFC_WIDTH{1'b0}};
			dram_page_miss_count <= {PRFC_WIDTH{1'b0}};
			icache_wait_count <= {PRFC_WIDTH{1'b0}};
			instruction_issue_count <= {PRFC_WIDTH{1'b0}};
			instruction_retire_count <= {PRFC_WIDTH{1'b0}};
			l1d_collided_load_count <= {PRFC_WIDTH{1'b0}};
			l1d_hit_count <= {PRFC_WIDTH{1'b0}};
			l1d_miss_count <= {PRFC_WIDTH{1'b0}};
			l1i_collided_load_count <= {PRFC_WIDTH{1'b0}};
			l1i_hit_count <= {PRFC_WIDTH{1'b0}};
			l1i_miss_count <= {PRFC_WIDTH{1'b0}};
			l2_hit_count <= {PRFC_WIDTH{1'b0}};
			l2_miss_count <= {PRFC_WIDTH{1'b0}};
			mispredicted_branch_count <= {PRFC_WIDTH{1'b0}};
			raw_wait_count <= {PRFC_WIDTH{1'b0}};
			store_count <= {PRFC_WIDTH{1'b0}};
			uncond_branch_count <= {PRFC_WIDTH{1'b0}};
			// End of automatics
		end
		else
		begin
			if (pc_event_l2_hit) l2_hit_count <= l2_hit_count + 1;
			if (pc_event_l2_miss) l2_miss_count <= l2_miss_count + 1;
			if (pc_event_l1d_hit) l1d_hit_count <= l1d_hit_count + 1;
			if (pc_event_l1d_miss) l1d_miss_count <= l1d_miss_count + 1;
			if (pc_event_l1i_hit) l1i_hit_count <= l1i_hit_count + 1;
			if (pc_event_l1i_miss) l1i_miss_count <= l1i_miss_count + 1;
			if (pc_event_mispredicted_branch) mispredicted_branch_count 
				<= mispredicted_branch_count + 1;
			if (pc_event_store) store_count <= store_count + 1;
			if (pc_event_instruction_issue) instruction_issue_count <= instruction_issue_count + 1;
			if (pc_event_instruction_retire) instruction_retire_count <= instruction_retire_count + 1;
			raw_wait_count <= raw_wait_count + count_bits(pc_event_raw_wait);
			dcache_wait_count <= dcache_wait_count + count_bits(pc_event_dcache_wait);
			icache_wait_count <= icache_wait_count + count_bits(pc_event_icache_wait);
			if (pc_event_dram_page_miss) dram_page_miss_count <= dram_page_miss_count + 1;
			if (pc_event_dram_page_hit) dram_page_hit_count <= dram_page_hit_count + 1;
			if (pc_event_l1i_collided_load) l1i_collided_load_count <= l1i_collided_load_count + 1;
			if (pc_event_l1d_collided_load) l1d_collided_load_count <= l1d_collided_load_count + 1;
			if (pc_event_dram_page_hit) dram_page_hit_count <= dram_page_hit_count + 1;
			if (pc_event_uncond_branch) uncond_branch_count <= uncond_branch_count + 1;
			if (pc_event_cond_branch_taken) cond_branch_taken_count <= cond_branch_taken_count + 1;
			if (pc_event_cond_branch_not_taken) cond_branch_not_taken_count <= cond_branch_not_taken_count + 1;
		end
	end
endmodule
