
module scalar_register_file(
	input 					clk,
	input [6:0] 			sel1_i,
	input [6:0] 			sel2_i,
	output reg[31:0] 		value1_o = 0,
	output reg[31:0] 		value2_o = 0,
	input [6:0] 			write_reg_i,
	input [31:0] 			write_value_i,
	input 					write_enable_i);

	localparam NUM_REGISTERS = 4 * 32; // 32 registers per strand * 4 strands

	reg[31:0]				registers[0:NUM_REGISTERS - 1];	
	integer					i;
	
	initial
	begin
		// synthesis translate_off
		for (i = 0; i < NUM_REGISTERS; i = i + 1)
			registers[i] = 0;

		// synthesis translate_on
	end
	
	always @(posedge clk)
	begin
		value1_o <= #1 registers[sel1_i];
		value2_o <= #1 registers[sel2_i];
		if (write_enable_i)
			registers[write_reg_i] <= #1 write_value_i;
	end
	
endmodule
