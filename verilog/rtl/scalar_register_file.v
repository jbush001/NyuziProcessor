`include "../timescale.v"

module scalar_register_file(
	input 					clk,
	input [4:0] 			sel1_i,
	input [4:0] 			sel2_i,
	output reg[31:0] 		value1_o,
	output reg[31:0] 		value2_o,
	input [4:0] 			write_reg_i,
	input [31:0] 			write_value_i,
	input 					write_enable_i);

	reg[31:0]				registers[0:30];
	integer					i;
	
	initial
	begin
		value1_o = 0;
		value2_o = 0;
		for (i = 0; i < 30; i = i + 1)
			registers[i] = 0;
	end
	
	always @(posedge clk)
	begin
		value1_o <= #1 registers[sel1_i];
		value2_o <= #1 registers[sel2_i];
		if (write_enable_i)
		begin
			$display("s%d = %08x", write_reg_i, write_value_i);
			registers[write_reg_i] <= #1 write_value_i;
		end
	end
	
endmodule
