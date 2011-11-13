//
// This is currently stubbed out for one thread.  When multiple threads
// are added, it will need to choose one thread each cycle and dispatch it.
//

module strand_select_stage(
	input					clk,
	input [31:0]			instruction_i,
	output reg[31:0]		instruction_o,
	input [31:0]			pc_i,
	output reg[31:0]		pc_o,
	output reg[3:0]			reg_lane_select_o,
	input					flush_i,
	output					stall_o,
	output reg[31:0]		strided_offset_o);

	reg[3:0]				lane_select_nxt;
	reg[3:0]				load_delay_ff;
	reg[3:0]				load_delay_nxt;
	reg[1:0]				thread_state_ff;
	reg[1:0]				thread_state_nxt;
	reg[31:0]				instruction_nxt;
	wire					is_multi_cycle_arith;	// arithmetic op with more than one cycle of latency
	wire					is_multi_cycle_transfer;
	wire					is_fmt_a;
	wire					is_fmt_b;
	wire					is_fmt_c;
	wire[3:0]				c_op_type;
	wire					is_load;
	reg[31:0]				strided_offset_nxt;

	parameter				STATE_NORMAL_INSTRUCTION = 0;
	parameter				STATE_VECTOR_LOAD = 1;
	parameter				STATE_VECTOR_STORE = 2;
	parameter				STATE_RAW_WAIT = 3;

	initial
	begin
		instruction_o = 0;
		reg_lane_select_o = 0;
		pc_o = 0;
		lane_select_nxt = 0;
		load_delay_ff = 0;
		load_delay_nxt = 0;
		thread_state_ff = STATE_NORMAL_INSTRUCTION;
		thread_state_nxt = STATE_NORMAL_INSTRUCTION;
		instruction_nxt = 0;
		strided_offset_o = 0;
		strided_offset_nxt = 0;
	end

	assign is_fmt_a = instruction_i[31:29] == 3'b110;	
	assign is_fmt_b = instruction_i[31] == 1'b0;	
	assign is_fmt_c = instruction_i[31:30] == 2'b10;	
	assign stall_o = thread_state_nxt != STATE_NORMAL_INSTRUCTION;
	assign is_multi_cycle_arith = (is_fmt_a && instruction_i[28] == 1)
		|| (is_fmt_a && instruction_i[28:23] == 6'b000111)	// Integer multiply
		|| (is_fmt_b && instruction_i[30:26] == 5'b00111);	// Integer multiply
	assign c_op_type = instruction_i[28:25];
	assign is_load = instruction_i[29];
	assign is_multi_cycle_transfer = c_op_type == 4'b1010
		|| c_op_type == 4'b1011
		|| c_op_type == 4'b1100
		|| c_op_type == 4'b1101
		|| c_op_type == 4'b1110
		|| c_op_type == 4'b1111;

	// When a load occurs, there is a RAW dependency.  We just insert nops 
	// to cover that.  A more efficient implementation could detect when a true 
	// dependency exists.
	always @*
	begin
		if (thread_state_ff == STATE_RAW_WAIT)
			load_delay_nxt = load_delay_ff - 1;
		else if (is_multi_cycle_arith)
			load_delay_nxt = 3;	// Floating point pipeline is 3 stages
		else
			load_delay_nxt = 2;	// 2 stages to commit load result
	end

	always @*
	begin
		case (thread_state_ff)
			STATE_NORMAL_INSTRUCTION, STATE_RAW_WAIT: 
			begin
				lane_select_nxt = 0;
				strided_offset_nxt = 0;
			end
				
			STATE_VECTOR_LOAD, STATE_VECTOR_STORE: 
			begin
				lane_select_nxt = reg_lane_select_o + 1;
				strided_offset_nxt = strided_offset_o + instruction_i[24:15];
			end
		endcase	
	end

	always @*
	begin
		if (flush_i)
			thread_state_nxt = STATE_NORMAL_INSTRUCTION;
		else
		begin
			case (thread_state_ff)
				STATE_NORMAL_INSTRUCTION:
				begin
					if (is_fmt_c)
					begin
						// Memory transfer
						if (is_multi_cycle_transfer)
						begin
							// Vector transfer
							if (is_load)
								thread_state_nxt = STATE_VECTOR_LOAD;
							else
								thread_state_nxt = STATE_VECTOR_STORE;
						end
						else if (is_load)
							thread_state_nxt = STATE_RAW_WAIT;	// scalar load
						else
							thread_state_nxt = STATE_NORMAL_INSTRUCTION;
					end
					else if (is_multi_cycle_arith)
						thread_state_nxt = STATE_RAW_WAIT;	// long latency instruction
					else
						thread_state_nxt = STATE_NORMAL_INSTRUCTION;
				end
				
				STATE_VECTOR_LOAD:
				begin
					if (reg_lane_select_o == 4'b1110)
						thread_state_nxt = STATE_RAW_WAIT;
					else
						thread_state_nxt = STATE_VECTOR_LOAD;
				end
				
				STATE_VECTOR_STORE:
				begin
					if (reg_lane_select_o == 4'b1110)
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
			endcase
		end
	end
	
	always @*
	begin
		if (flush_i || thread_state_ff == STATE_RAW_WAIT)
			instruction_nxt = 0;	// NOP
		else
			instruction_nxt = instruction_i;
	end

	always @(posedge clk)
	begin
		if (flush_i)
		begin
			pc_o						<= #1 0;
			reg_lane_select_o				<= #1 0;
			load_delay_ff				<= #1 0;
		end
		else
		begin
			pc_o						<= #1 pc_i;
			reg_lane_select_o			<= #1 lane_select_nxt;
			load_delay_ff				<= #1 load_delay_nxt;
		end

		instruction_o					<= #1 instruction_nxt;
		thread_state_ff					<= #1 thread_state_nxt;
		strided_offset_o				<= #1 strided_offset_nxt;
	end
	
endmodule
