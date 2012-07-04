//
// The integer multiplier has 3 cycles of latency.
// This is a stub for now.  It is intended to be replaced by something
// like a wallace tree.
//

module integer_multiplier(
	input wire 					clk,
	input [31:0]				multiplicand_i,
	input [31:0]				multiplier_i,
	output reg[47:0]			product_o = 0);
	
	reg[47:0]					product1 = 0;
	reg[47:0]					product2 = 0;

	always @(posedge clk)
	begin
		product1 <= #1 multiplicand_i * multiplier_i;
		product2 <= #1 product1;
		product_o <= #1 product2;
	end
endmodule
