`include "timescale.v"

//
// Emulates cache behavior for simulation
//
module sim_cache
	#(parameter MEM_SIZE = 'h100000)

	(input 					clk,
	
	// Instruction Port
	input[31:0]				iaddress_i,
	output reg[31:0]		idata_o,
	input					iaccess_i,
	
	// Data Port
	input[31:0]				daddress_i,
	output reg[31:0]		ddata_o,
	input[31:0]				ddata_i,
	input					dwrite_i,
	input					daccess_i,
	input[3:0]				dsel_i,
	output reg				dack_o);

	reg[31:0]				data[0:MEM_SIZE - 1];
	wire[31:0] 				orig_data;


	integer i;

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
			idata_o <= data[iaddress_i[31:2]];
	end


	reg[31:0]				daddr_stage_1;
	reg						daccess_stage_1;

	// Execute Stage (cycle 0)
	always @(posedge clk)
	begin
		daddr_stage_1 		<= #1 daddress_i;
		daccess_stage_1 	<= #1 daccess_i;
		dack_o 				<= #1 daccess_i;
	end

	// Memory Access Stage (cycle 1)
	assign orig_data = data[daddress_i[31:2]];
	always @(posedge clk)
	begin
		if (daccess_stage_1 && dwrite_i)
		begin
			data[daddr_stage_1[31:2]] <= #1 {
				dsel_i[3] ? orig_data[31:24] : ddata_i[31:24],
				dsel_i[2] ? orig_data[23:16] : ddata_i[23:16],
				dsel_i[1] ? orig_data[15:8] : ddata_i[15:8],
				dsel_i[0] ? orig_data[7:0] : ddata_i[7:0]
			};
		end
	end

	// Data read
	always @(posedge clk)
	begin
		if (daccess_stage_1 && ~dwrite_i)
			ddata_o <= #1 data[daddr_stage_1[31:2]];
	end
endmodule
