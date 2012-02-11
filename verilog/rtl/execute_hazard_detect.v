//
// Detect a hazard at the end of the execute stage
// 

module execute_hazard_detect(
	input				clk,
	input[31:0] 		instruction0_i,
	input[31:0] 		instruction1_i,
	input[31:0] 		instruction2_i,
	input[31:0] 		instruction3_i,
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
	
	latency_decoder ld0(instruction0_i, single_cycle0, multi_cycle0);
	latency_decoder ld1(instruction1_i, single_cycle1, multi_cycle1);
	latency_decoder ld2(instruction2_i, single_cycle2, multi_cycle2);
	latency_decoder ld3(instruction3_i, single_cycle3, multi_cycle3);

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
	
	assign execute_hazard0_o = writeback_allocate_ff[2] && single_cycle0;
	assign execute_hazard1_o = writeback_allocate_ff[2] && single_cycle1;
	assign execute_hazard2_o = writeback_allocate_ff[2] && single_cycle2;
	assign execute_hazard3_o = writeback_allocate_ff[2] && single_cycle3;

	always @(posedge clk)
		writeback_allocate_ff <= #1 (writeback_allocate_ff << 1) | issued_is_multi_cycle;

endmodule


//
// This needs to agree with what is in the execute stage mux.
// XXX should this result just be pushed down the pipeline?
// 
module latency_decoder(
	input [31:0] instruction_i,
	output single_cycle_result,
	output multi_cycle_result);

	wire is_fmt_a = instruction_i[31:29] == 3'b110;
	wire is_fmt_b = instruction_i[31] == 1'b0;
	wire has_writeback = (is_fmt_a || is_fmt_b
		|| (instruction_i[31:30] == 2'b10 && instruction_i[29]) 
		|| instruction_i[31:25] == 7'b1111100) 
		&& instruction_i != 0;
	wire is_multi_cycle = (is_fmt_a && instruction_i[28] == 1)
		|| (is_fmt_a && instruction_i[28:23] == 6'b000111)	// Integer multiply
		|| (is_fmt_b && instruction_i[30:26] == 5'b00111);	// Integer multiply

	assign multi_cycle_result = is_multi_cycle & has_writeback;
	assign single_cycle_result = !is_multi_cycle & has_writeback;
endmodule
