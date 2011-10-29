`include "timescale.v"

module strand_select_stage(
	input					clk,
	input [31:0] 			instruction_i,
	output reg[31:0]		instruction_o,
	input [31:0]			pc_i,
	output reg[31:0]		pc_o,
	output reg[3:0]			lane_select_o,
	input					flush_i);

	initial
	begin
		instruction_o = 0;
		lane_select_o = 0;
		pc_o = 0;
	end

	always @(posedge clk)
	begin
		if (flush_i)
		begin
			instruction_o 		<= 0;	// NOP
			pc_o				<= 0;
		end
		else
		begin
			instruction_o 		<= #1 instruction_i;
			pc_o				<= #1 pc_i;
		end
	end
	
endmodule
