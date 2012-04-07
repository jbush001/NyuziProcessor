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

`include "instruction_format.h"

module strand_fsm(
	input					clk,
	input [31:0]			instruction_i,
	input					instruction_valid_i,	// instruction_i is valid
	input					grant_i, // we have permission to issue (based on request_o, watch for loop)
	output					issue_request_o,
	input [31:0]			pc_i,
	input					flush_i,
	output					next_instruction_o,
	input					suspend_strand_i,
	input					resume_strand_i,
	input [31:0]			rollback_strided_offset_i,
	input [3:0]				rollback_reg_lane_i,
	output [3:0]			reg_lane_select_o,
	output [31:0]			strided_offset_o,
	output [31:0]			pc_o,
	output [31:0]			instruction_o);

	reg[3:0]				load_delay_ff = 0;
	reg[3:0]				load_delay_nxt = 0;
	reg[2:0]				thread_state_ff = STATE_NORMAL_INSTRUCTION;
	reg[2:0]				thread_state_nxt = STATE_NORMAL_INSTRUCTION;
	reg[31:0]				strided_offset_nxt = 0;
	reg[3:0]				reg_lane_select_ff = 0;
	reg[31:0]				reg_lane_select_nxt = 0;
	reg[31:0]				strided_offset_ff = 0; 

	parameter				STATE_NORMAL_INSTRUCTION = 0;
	parameter				STATE_VECTOR_LOAD = 1;
	parameter				STATE_VECTOR_STORE = 2;
	parameter				STATE_RAW_WAIT = 3;
	parameter				STATE_CACHE_WAIT = 4;

	wire is_fmt_a = instruction_i[31:29] == 3'b110;	
	wire is_fmt_b = instruction_i[31] == 1'b0;	
	wire is_fmt_c = instruction_i[31:30] == 2'b10;
	wire is_multi_cycle_arith = (is_fmt_a && instruction_i[28] == 1)
		|| (is_fmt_a && instruction_i[28:23] == 6'b000111)	// Integer multiply
		|| (is_fmt_b && instruction_i[30:26] == 5'b00111);	// Integer multiply
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
	wire vector_transfer_end = reg_lane_select_ff == 4'b1111	&& thread_state_ff != STATE_CACHE_WAIT;
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

	// When a load occurs, there is a RAW dependency.  We just insert nops 
	// to cover that.  A more efficient implementation could detect when a true 
	// dependency exists.
	always @*
	begin
		if (thread_state_ff == STATE_RAW_WAIT)
			load_delay_nxt = load_delay_ff - 1;
		else if (is_multi_cycle_arith)
			load_delay_nxt = 3; // Floating point pipeline is 3 stages
		else
			load_delay_nxt = 2; // 2 stages to commit load result
	end
	
	always @*
	begin
		if (suspend_strand_i)
		begin
			reg_lane_select_nxt = rollback_reg_lane_i;
			strided_offset_nxt = rollback_strided_offset_i;
		end
		else if (flush_i || (vector_transfer_end && will_issue))
		begin
			reg_lane_select_nxt = 0;
			strided_offset_nxt = 0;
		end
		else if (((thread_state_ff == STATE_VECTOR_LOAD || thread_state_ff == STATE_VECTOR_STORE)
		  || is_multi_cycle_transfer) 
		  && thread_state_ff != STATE_CACHE_WAIT
		  && thread_state_ff != STATE_RAW_WAIT
		  && will_issue)
		begin
			reg_lane_select_nxt = reg_lane_select_ff + 1;
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
	
	/// Performance Statistics //////////////////////////////////
	reg[63:0] raw_wait_count = 0;
	reg[63:0] dcache_wait_count = 0;
	reg[63:0] icache_wait_count = 0;
	
	always @(posedge clk)
	begin
		if (!instruction_valid_i)
			icache_wait_count <= icache_wait_count + 1;			
		else if (thread_state_ff == STATE_RAW_WAIT)
			raw_wait_count <= raw_wait_count + 1;		
		else if (thread_state_ff == STATE_CACHE_WAIT)
			dcache_wait_count <= dcache_wait_count + 1;
	end
	////////////////////////////////////////////////////////////

	assign pc_o = pc_i;
	assign instruction_o = instruction_i;
	assign reg_lane_select_o = reg_lane_select_ff;
	assign strided_offset_o = strided_offset_ff;
	
	always @(posedge clk)
	begin
		if (flush_i)
			load_delay_ff				<= #1 0;
		else
			load_delay_ff				<= #1 load_delay_nxt;

		thread_state_ff					<= #1 thread_state_nxt;
		reg_lane_select_ff				<= #1 reg_lane_select_nxt;
		strided_offset_ff				<= #1 strided_offset_nxt;
	end
endmodule
