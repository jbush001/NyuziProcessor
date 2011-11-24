//
// This is actually a testing placeholder right now.  It is a hybrid that 
// simulates the L1 instruction cache and the L2 interface for data.
//  

module sim_l2cache
	#(parameter MEM_SIZE = 'h100000)

	(input						clk,

	input[31:0]					iaddress_i,
	output reg[31:0]			idata_o,
	input						iaccess_i,

	input						dwrite_i,
	input						dread_i,
	output reg					dack_o,
	input [31:0]				daddr_i,
	input [511:0]				ddata_i,
	output reg[511:0]			ddata_o);

	reg[31:0]					data[0:MEM_SIZE - 1];
	integer						i;

	initial
	begin
		idata_o = 0;
		ddata_o = 0;
		for (i = 0; i < MEM_SIZE; i = i + 1)
			data[i] = 0;
			
		dack_o = 0;
	end

	// Instruction read
	always @(posedge clk)
	begin
		if (iaccess_i)
			idata_o <= #1 data[iaddress_i[31:2]];
	end

	always @(posedge clk)
	begin
		if (dwrite_i)
		begin
			data[daddr_i[31:2]] <= #1 ddata_i[511:480];
			data[daddr_i[31:2] + 1] <= #1 ddata_i[479:448];
			data[daddr_i[31:2] + 2] <= #1 ddata_i[447:416];
			data[daddr_i[31:2] + 3] <= #1 ddata_i[415:384];
			data[daddr_i[31:2] + 4] <= #1 ddata_i[383:352];
			data[daddr_i[31:2] + 5] <= #1 ddata_i[351:320];
			data[daddr_i[31:2] + 6] <= #1 ddata_i[319:288];
			data[daddr_i[31:2] + 7] <= #1 ddata_i[287:256];
			data[daddr_i[31:2] + 8] <= #1 ddata_i[255:224];
			data[daddr_i[31:2] + 9] <= #1 ddata_i[223:192];
			data[daddr_i[31:2] + 10] <= #1 ddata_i[191:160];
			data[daddr_i[31:2] + 11] <= #1 ddata_i[159:128];
			data[daddr_i[31:2] + 12] <= #1 ddata_i[127:96];
			data[daddr_i[31:2] + 13] <= #1 ddata_i[95:64];
			data[daddr_i[31:2] + 14] <= #1 ddata_i[63:32];
			data[daddr_i[31:2] + 15] <= #1 ddata_i[31:0];
		end
	end

	always @(posedge clk)
		dack_o <= #1 dwrite_i || dread_i;

	always @(posedge clk)
	begin
		ddata_o <= #1 {
			data[daddr_i[31:2]],
			data[daddr_i[31:2] + 1],
			data[daddr_i[31:2] + 2],
			data[daddr_i[31:2] + 3],
			data[daddr_i[31:2] + 4],
			data[daddr_i[31:2] + 5],
			data[daddr_i[31:2] + 6],
			data[daddr_i[31:2] + 7],
			data[daddr_i[31:2] + 8],
			data[daddr_i[31:2] + 9],
			data[daddr_i[31:2] + 10],
			data[daddr_i[31:2] + 11],
			data[daddr_i[31:2] + 12],
			data[daddr_i[31:2] + 13],
			data[daddr_i[31:2] + 14],
			data[daddr_i[31:2] + 15]
		};	
	end

endmodule
