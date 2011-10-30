`include "timescale.v"

module instruction_fetch_stage(
	input							clk,
	output [31:0]   				iaddress_o,
	output reg[31:0]				pc_o,
	input [31:0]					idata_i,
	output 							iaccess_o,
	output [31:0]	    			instruction_o,
	input							restart_request_i,
	input [31:0]					restart_address_i,
	input                           stall_i);
	
	reg[31:0]						program_counter_ff;
	reg[31:0]						program_counter_nxt;

	assign iaddress_o = program_counter_nxt;
	assign iaccess_o = 1;
	assign instruction_o = idata_i;
	
	initial
	begin
		pc_o = 0;
		program_counter_ff = -4;
	end
	
	always @*
	begin
		if (restart_request_i)
			program_counter_nxt	= restart_address_i;
        else if (stall_i)
	        program_counter_nxt = program_counter_ff;
		else
			program_counter_nxt	= program_counter_ff + 32'd4;
	end

	always @(posedge clk)
	begin
		program_counter_ff 			<= #1 program_counter_nxt;
		pc_o						<= #1 program_counter_nxt + 4;
	end
endmodule
