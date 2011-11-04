`include "../timescale.v"

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
	output reg[3:0]			lane_select_o,
	input					flush_i,
	output					stall_o);

	reg[3:0]				lane_select_nxt;
	reg[3:0]				load_delay_ff;
	reg[3:0]				load_delay_nxt;
	reg[1:0]				thread_state_ff;
	reg[1:0]				thread_state_nxt;
	reg[31:0]				instruction_nxt;

	parameter				LOAD_LATENCY = 2;

	parameter				STATE_NORMAL_INSTRUCTION = 0;
	parameter				STATE_VECTOR_LOAD = 1;
	parameter				STATE_VECTOR_STORE = 2;
	parameter				STATE_LOAD_WAIT = 3;

	initial
	begin
		instruction_o = 0;
		lane_select_o = 0;
		pc_o = 0;
		lane_select_nxt = 0;
		load_delay_ff = 0;
		load_delay_nxt = 0;
		thread_state_ff = STATE_NORMAL_INSTRUCTION;
		thread_state_nxt = STATE_NORMAL_INSTRUCTION;
		instruction_nxt = 0;
	end

	assign stall_o = thread_state_nxt != STATE_NORMAL_INSTRUCTION;

	// When a load occurs, there is a RAW dependency.  We just insert nops 
	// to cover that.  A more efficient implementation could detect when a true 
	// dependency exists.
	always @*
	begin
		if (thread_state_ff == STATE_LOAD_WAIT)
			load_delay_nxt = load_delay_ff - 1;
		else
			load_delay_nxt = LOAD_LATENCY;
	end

	always @*
	begin
		case (thread_state_ff)
			STATE_NORMAL_INSTRUCTION, STATE_LOAD_WAIT: 
				lane_select_nxt = 0;
				
			STATE_VECTOR_LOAD, STATE_VECTOR_STORE: 
				lane_select_nxt = lane_select_o + 1;
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
					if (instruction_i[31:30] == 3'b10)
					begin
						// Memory transfer
						if (instruction_i[28] == 1'b1 
							|| instruction_i[28:25] == 4'b0111 
							|| instruction_i[28:25] == 4'b0110)
						begin
							// Vector transfer
							if (instruction_i[29])
								thread_state_nxt = STATE_VECTOR_LOAD;
							else
								thread_state_nxt = STATE_VECTOR_STORE;
						end
						else if (instruction_i[29])
							thread_state_nxt = STATE_LOAD_WAIT;	// scalar load
						else
							thread_state_nxt = STATE_NORMAL_INSTRUCTION;
					end
					else
						thread_state_nxt = STATE_NORMAL_INSTRUCTION;
				end
				
				STATE_VECTOR_LOAD:
				begin
					if (lane_select_o == 4'b1110)
						thread_state_nxt = STATE_LOAD_WAIT;
					else
						thread_state_nxt = STATE_VECTOR_LOAD;
				end
				
				STATE_VECTOR_STORE:
				begin
					if (lane_select_o == 4'b1110)
						thread_state_nxt = STATE_NORMAL_INSTRUCTION;
					else
						thread_state_nxt = STATE_VECTOR_STORE;
				end
				
				STATE_LOAD_WAIT:
				begin
					if (load_delay_ff == 1)
						thread_state_nxt = STATE_NORMAL_INSTRUCTION;
					else
						thread_state_nxt = STATE_LOAD_WAIT;
				end
			endcase
		end
	end
	
	always @*
	begin
		if (flush_i || thread_state_ff == STATE_LOAD_WAIT)
			instruction_nxt = 0;	// NOP
		else
			instruction_nxt = instruction_i;
	end

	always @(posedge clk)
	begin
		if (flush_i)
		begin
			pc_o						<= #1 0;
			lane_select_o				<= #1 0;
			load_delay_ff				<= #1 0;
		end
		else
		begin
			pc_o						<= #1 pc_i;
			lane_select_o				<= #1 lane_select_nxt;
			load_delay_ff				<= #1 load_delay_nxt;
		end

		instruction_o					<= #1 instruction_nxt;
		thread_state_ff					<= #1 thread_state_nxt;
	end
	
endmodule
