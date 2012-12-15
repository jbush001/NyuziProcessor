// 
// Copyright 2011-2012 Jeff Bush
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

`include "instruction_format.h"

//
// Strand finite state machine. 
//
// This tracks the state of a single strand.  It will keep track of cache misses 
// and restart a strand when it receives updates from the L1 cache.
//
// This also handles delaying strands when there are RAW conflicts (because of 
// memory loads or long latency instructions). Currently, we don't detect these 
// conflicts explicitly but always delay the next instruction when one of these
// instructions that coudl generate a RAW is issued.
//
// There are three types of rollbacks, which are encoded as follows:
//
// +------------------------+--------------------+----------+----------+
// | Type                   |  suspend_strand_i  | flush_i  | retry_i  |
// +------------------------+--------------------+----------+----------+
// | dcache miss/stbuf full |          1         |    0     |    0     |
// | mispredicted branch    |          0         |    1     |    0     |
// | retry                  |          0         |    1     |    1     |
// +------------------------+--------------------+----------+----------+
//
// A retry occurs when a cache fill completes in the same cycle that a 
// cache miss occurs for the same line.  We don't suspend the strand because
// the miss is satisfied, but we need to restart it to pick up the data.
//

module strand_fsm(
	input					clk,
	input					reset,
	input [31:0]			instruction_i,
	input					instruction_valid_i,	// instruction_i is valid
	input					grant_i, // we have permission to issue (based on request_o, watch for loop)
	output					issue_request_o,
	input					flush_i,
	output					next_instruction_o,
	input					suspend_strand_i,
	input					retry_i,
	input					resume_strand_i,
	input [31:0]			rollback_strided_offset_i,
	input [3:0]				rollback_reg_lane_i,
	output [3:0]			reg_lane_select_o,
	output [31:0]			strided_offset_o);

	localparam				STATE_NORMAL_INSTRUCTION = 0;
	localparam				STATE_VECTOR_LOAD = 1;
	localparam				STATE_VECTOR_STORE = 2;
	localparam				STATE_RAW_WAIT = 3;
	localparam				STATE_CACHE_WAIT = 4;

	reg[3:0]				load_delay_ff;
	reg[3:0]				load_delay_nxt;
	reg[2:0]				thread_state_ff = STATE_NORMAL_INSTRUCTION;
	reg[2:0]				thread_state_nxt = STATE_NORMAL_INSTRUCTION;
	reg[31:0]				strided_offset_nxt;
	reg[3:0]				reg_lane_select_ff ;
	reg[3:0]				reg_lane_select_nxt;
	reg[31:0]				strided_offset_ff; 

	wire is_fmt_a = instruction_i[31:29] == 3'b110;	
	wire is_fmt_b = instruction_i[31] == 1'b0;	
	wire is_fmt_c = instruction_i[31:30] == 2'b10;
	wire is_multi_cycle_arith = (is_fmt_a && instruction_i[28] == 1)
		|| (is_fmt_a && instruction_i[28:23] == `OP_IMUL)
		|| (is_fmt_b && instruction_i[30:26] == `OP_IMUL);
	wire[3:0] c_op_type = instruction_i[28:25];
	wire is_load = instruction_i[29]; // Assumes fmt c
	wire is_synchronized_store = ~is_load && c_op_type == `MEM_SYNC;	// assumes fmt c
	wire is_multi_cycle_transfer = is_fmt_c 
		&& (c_op_type == `MEM_STRIDED
		|| c_op_type == `MEM_STRIDED_M
		|| c_op_type == `MEM_STRIDED_IM
		|| c_op_type == `MEM_SCGATH
		|| c_op_type == `MEM_SCGATH_M
		|| c_op_type == `MEM_SCGATH_IM);
	wire vector_transfer_end = reg_lane_select_ff == 0 && thread_state_ff != STATE_CACHE_WAIT;
	wire is_vector_transfer = thread_state_ff == STATE_VECTOR_LOAD || thread_state_ff == STATE_VECTOR_STORE
	   || is_multi_cycle_transfer;
	assign next_instruction_o = ((thread_state_ff == STATE_NORMAL_INSTRUCTION 
		&& !is_multi_cycle_transfer)
		|| (is_vector_transfer && vector_transfer_end)) && grant_i;
	wire will_issue = instruction_valid_i && grant_i;
	assign issue_request_o = thread_state_ff != STATE_RAW_WAIT
		&& thread_state_ff != STATE_CACHE_WAIT
		&& instruction_valid_i
		&& !flush_i;

	// When a load occurs, there is a potential RAW dependency.  We just insert nops 
	// to cover that.  A more efficient implementation could detect when a true 
	// dependency exists.
	always @*
	begin
		if (thread_state_ff == STATE_RAW_WAIT)
			load_delay_nxt = load_delay_ff - 1;
		else 
			load_delay_nxt = 3; 
	end
	
	always @*
	begin
		if (suspend_strand_i || retry_i)
		begin
			reg_lane_select_nxt = rollback_reg_lane_i;
			strided_offset_nxt = rollback_strided_offset_i;
		end
		else if (flush_i || (vector_transfer_end && will_issue))
		begin
			reg_lane_select_nxt = 4'd15;
			strided_offset_nxt = 0;
		end
		else if (((thread_state_ff == STATE_VECTOR_LOAD || thread_state_ff == STATE_VECTOR_STORE)
		  || is_multi_cycle_transfer) 
		  && thread_state_ff != STATE_CACHE_WAIT
		  && thread_state_ff != STATE_RAW_WAIT
		  && will_issue)
		begin
			reg_lane_select_nxt = reg_lane_select_ff - 1;
			strided_offset_nxt = strided_offset_ff + instruction_i[24:15];
		end
		else
		begin
			reg_lane_select_nxt = reg_lane_select_ff;
			strided_offset_nxt = strided_offset_ff;
		end
	end

	always @*
	begin
		if (flush_i)
		begin
			if (suspend_strand_i)
				thread_state_nxt = STATE_CACHE_WAIT;
			else
				thread_state_nxt = STATE_NORMAL_INSTRUCTION;
		end
		else
		begin
			case (thread_state_ff)
				STATE_NORMAL_INSTRUCTION:
				begin
					// Only update state machine if this is a valid instruction
					if (will_issue && is_fmt_c)
					begin
						// Memory transfer
						if (is_multi_cycle_transfer && !vector_transfer_end)
						begin
							// Vector transfer
							if (is_load)
								thread_state_nxt = STATE_VECTOR_LOAD;
							else
								thread_state_nxt = STATE_VECTOR_STORE;
						end
						else if (is_load || is_synchronized_store)
							thread_state_nxt = STATE_RAW_WAIT;	
						else
							thread_state_nxt = STATE_NORMAL_INSTRUCTION;
					end
					else if (is_multi_cycle_arith && will_issue)
						thread_state_nxt = STATE_RAW_WAIT;	// long latency instruction
					else
						thread_state_nxt = STATE_NORMAL_INSTRUCTION;
				end
				
				STATE_VECTOR_LOAD:
				begin
					if (vector_transfer_end)
						thread_state_nxt = STATE_RAW_WAIT;
					else
						thread_state_nxt = STATE_VECTOR_LOAD;
				end
				
				STATE_VECTOR_STORE:
				begin
					if (vector_transfer_end)
						thread_state_nxt = STATE_NORMAL_INSTRUCTION;
					else
						thread_state_nxt = STATE_VECTOR_STORE;
				end
				
				STATE_RAW_WAIT:
				begin
					if (load_delay_ff == 1)
						thread_state_nxt = STATE_NORMAL_INSTRUCTION;
					else
						thread_state_nxt = STATE_RAW_WAIT;
				end
				
				STATE_CACHE_WAIT:
				begin
					if (resume_strand_i)
						thread_state_nxt = STATE_NORMAL_INSTRUCTION;
					else
						thread_state_nxt = STATE_CACHE_WAIT;
				end
			endcase
		end
	end
	
	// Performance Counters 
	reg[63:0] raw_wait_count;
	reg[63:0] dcache_wait_count;
	reg[63:0] icache_wait_count;

	assign reg_lane_select_o = reg_lane_select_ff;
	assign strided_offset_o = strided_offset_ff;
	
	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			reg_lane_select_ff <= 4'd15;

			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			dcache_wait_count <= 64'h0;
			icache_wait_count <= 64'h0;
			load_delay_ff <= 4'h0;
			raw_wait_count <= 64'h0;
			strided_offset_ff <= 32'h0;
			thread_state_ff <= 3'h0;
			// End of automatics
		end
		else
		begin
			if (flush_i)
				load_delay_ff				<= #1 0;
			else
				load_delay_ff				<= #1 load_delay_nxt;
	
			thread_state_ff					<= #1 thread_state_nxt;
			reg_lane_select_ff				<= #1 reg_lane_select_nxt;
			strided_offset_ff				<= #1 strided_offset_nxt;

			// Performance Counters
			if (thread_state_ff == STATE_RAW_WAIT)
				raw_wait_count <= #1 raw_wait_count + 1;		
			else if (thread_state_ff == STATE_CACHE_WAIT)
				dcache_wait_count <= #1 dcache_wait_count + 1;
			else if (!instruction_valid_i)
				icache_wait_count <= #1 icache_wait_count + 1;			
		end
	end
endmodule
