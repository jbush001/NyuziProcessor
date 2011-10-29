`include "timescale.v"

module instruction_fetch_stage(
	input				clk,
	output [31:0] 		iaddress_o,
	output reg[31:0]	pc_o,
	input [31:0]		idata_i,
	output 				iaccess_o,
	output reg [31:0]	instruction_o);
	
	reg[31:0]			program_counter;

	assign iaddress_o = program_counter;	
	assign iaccess_o = 1'b1;
	
	initial
	begin
		pc_o = 0;
		instruction_o = 0;
		program_counter = 0;
	end
	
	always @(posedge clk)
	begin
		program_counter 	<= #1 program_counter + 32'd4;
		instruction_o 		<= #1 idata_i;
		pc_o				<= #1 program_counter;
	end
endmodule
