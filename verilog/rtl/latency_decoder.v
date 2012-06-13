//
// This needs to agree with what is in the execute stage mux.
// XXX should this result just be pushed down the pipeline to avoid duplication
// of logic?
// 
`include "instruction_format.h"

module latency_decoder(
	input [31:0] instruction_i,
	output single_cycle_result,
	output multi_cycle_result);

	wire is_fmt_a = instruction_i[31:29] == 3'b110;
	wire is_fmt_b = instruction_i[31] == 1'b0;
	wire is_multi_cycle = (is_fmt_a && instruction_i[28] == 1)
		|| (is_fmt_a && instruction_i[28:23] == `OP_IMUL)	
		|| (is_fmt_b && instruction_i[30:26] == `OP_IMUL);	

	assign multi_cycle_result = is_multi_cycle && instruction_i != `NOP;
	assign single_cycle_result = !is_multi_cycle && instruction_i != `NOP;
endmodule
