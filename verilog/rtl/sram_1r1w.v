//
// Block SRAM with 1 read port and 1 write port
//

module sram_1r1w
	#(parameter WIDTH = 32,
	parameter SIZE = 1024,
	parameter ADDR_WIDTH = 10,
	parameter READ_BEFORE_WRITE = 0)	// If true, return old data when there is a
										// simultaneous read and write to the same
										// location.  Otherwise the newly written
										// data is returned (write-before-read).
	(input						clk,
	input [ADDR_WIDTH - 1:0]	rd_addr,
	output reg[WIDTH - 1:0]		rd_data = 0,
	input [ADDR_WIDTH - 1:0]	wr_addr,
	input [WIDTH - 1:0]			wr_data,
	input						wr_enable);

	reg[WIDTH - 1:0]			data[0:SIZE - 1];
	integer						i;

	initial
	begin
		for (i = 0; i < SIZE; i = i + 1)
			data[i] = 0;
	end

	always @(posedge clk)
	begin
		if (wr_enable)
			data[wr_addr] <= #1 wr_data;	
			
		if (!READ_BEFORE_WRITE && wr_enable && wr_addr == rd_addr)
			rd_data <= #1 wr_data;
		else
			rd_data <= #1 data[rd_addr];
	end
endmodule
