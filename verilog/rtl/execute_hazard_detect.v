//
// At the end of the execute stage, the single and multi-cycle pipelines merge
// at a mux.  This creates a hazard where an instruction can arrive at the end
// of both pipelines simultaneously (one would necessarily have to be dropped). 
// This module tracks instructions through the pipeline and avoids issuing 
// instructions that would conflict.  For each of the instructions that could be 
// issued, it sets a signal indicating if the instruction would cause a conflict.
// 

`include "instruction_format.h"

module execute_hazard_detect(
	input				clk,
	input[31:0] 		if_instruction0,
	input[31:0] 		if_instruction1,
	input[31:0] 		if_instruction2,
	input[31:0] 		if_instruction3,
	input 				issue0_i,
	input 				issue1_i,
	input 				issue2_i,
	input 				issue3_i,
	output 				execute_hazard0_o,
	output 				execute_hazard1_o,
	output 				execute_hazard2_o,
	output 				execute_hazard3_o);

	wire				single_cycle0;
	wire				single_cycle1;
	wire				single_cycle2;
	wire				single_cycle3;
	wire				multi_cycle0;
	wire				multi_cycle1;
	wire				multi_cycle2;
	wire				multi_cycle3;
	reg[2:0]			writeback_allocate_ff;
	reg					issued_is_multi_cycle;
	
	latency_decoder latency_decoder0(
		.instruction_i(if_instruction0), 
		.single_cycle_result(single_cycle0), 
		.multi_cycle_result(multi_cycle0));

	latency_decoder latency_decoder1(
		.instruction_i(if_instruction1), 
		.single_cycle_result(single_cycle1), 
		.multi_cycle_result(multi_cycle1));

	latency_decoder latency_decoder2(
		.instruction_i(if_instruction2), 
		.single_cycle_result(single_cycle2), 
		.multi_cycle_result(multi_cycle2));

	latency_decoder latency_decoder3(
		.instruction_i(if_instruction3), 
		.single_cycle_result(single_cycle3), 
		.multi_cycle_result(multi_cycle3));

	always @*
	begin
		if (issue0_i)
			issued_is_multi_cycle = multi_cycle0;
		else if (issue1_i)
			issued_is_multi_cycle = multi_cycle1;
		else if (issue2_i)
			issued_is_multi_cycle = multi_cycle2;
		else if (issue3_i)
			issued_is_multi_cycle = multi_cycle3;
		else 
			issued_is_multi_cycle = 0;
	end

	// This shift register tracks when instructions are scheduled to arrive
	// at the mux.
	always @(posedge clk)
		writeback_allocate_ff <= #1 (writeback_allocate_ff << 1) | issued_is_multi_cycle;
	
	assign execute_hazard0_o = writeback_allocate_ff[2] && single_cycle0;
	assign execute_hazard1_o = writeback_allocate_ff[2] && single_cycle1;
	assign execute_hazard2_o = writeback_allocate_ff[2] && single_cycle2;
	assign execute_hazard3_o = writeback_allocate_ff[2] && single_cycle3;
endmodule



