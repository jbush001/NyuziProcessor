//
// Writeback stage
//  - Handle aligning memory reads that are smaller than a word
//  - Determine what the source of the register writeback should be
//  - Control signals to control commit of values back to the register file
//

module writeback_stage(
	input					clk,
	input[31:0]				instruction_i,
	input[4:0]				writeback_reg_i,
	input					writeback_is_vector_i,	
	input	 				has_writeback_i,
	input[15:0]				mask_i,
	output reg				writeback_is_vector_o,	
	output reg				has_writeback_o,
	output reg[4:0]			writeback_reg_o,
	output reg[511:0]		writeback_value_o,
	output reg[15:0]		mask_o,
	input [31:0]			ddata_i,
	input [511:0]			result_i,
	input [3:0]				lane_select_i);

	wire 					is_memory_access;
	wire					is_load;
	reg[511:0]				writeback_value_nxt;
	reg[15:0]				mask_nxt;
	reg[31:0]				aligned_read_value;
	reg[15:0]				half_aligned;
	reg[7:0]				byte_aligned;
	wire					is_control_register_transfer;

	initial
	begin
		writeback_is_vector_o = 0;
		has_writeback_o = 0;
		writeback_reg_o = 0;
		writeback_value_o = 0;
		mask_o = 0;
		writeback_value_nxt = 0;
		mask_nxt = 0;
	end
	
	assign is_control_register_transfer = instruction_i[28:25] == 4'b0110;
	assign is_load = instruction_i[31:30] == 2'b10 && instruction_i[29];

	// Byte aligner.  result_i still contains the effective address,
	// so use that to determine where the data will appear.
	always @*
	begin
		case (result_i[1:0])
			2'b00: byte_aligned = ddata_i[31:24];
			2'b01: byte_aligned = ddata_i[23:16];
			2'b10: byte_aligned = ddata_i[15:8];
			2'b11: byte_aligned = ddata_i[7:0];

		endcase
	end

	// Halfword aligner.  Same as above.
	always @*
	begin
		case (result_i[1])
			1'b0: half_aligned = { ddata_i[23:16], ddata_i[31:24] };
			1'b1: half_aligned = { ddata_i[7:0], ddata_i[15:8] };
		endcase
	end

	// Pick the proper aligned result and sign extend as requested.
	always @*
	begin
		case (instruction_i[28:25])		// Load width
			// unsigned byte
			4'b0000: aligned_read_value = { 24'b0, byte_aligned };	

			// Signed byte
			4'b0001: aligned_read_value = { {24{byte_aligned[7]}}, byte_aligned }; 

			// Unsigned half-word
			4'b0010: aligned_read_value = { 16'b0, half_aligned };

			// Signed half-word
			4'b0011: aligned_read_value = { {16{half_aligned[15]}}, half_aligned };

			// Word (100) and others
			default: aligned_read_value = { ddata_i[7:0], ddata_i[15:8],
				ddata_i[23:16], ddata_i[31:24] };	
		endcase
	end

	always @*
	begin
		if (is_load && !is_control_register_transfer)
		begin
			// Load result
			writeback_value_nxt = {16{aligned_read_value}};
			mask_nxt = (16'h8000 >> lane_select_i) & mask_i;	
		end
		else
		begin
			// Arithmetic expression
			writeback_value_nxt = result_i;
			mask_nxt = mask_i;
		end
	end

	always @(posedge clk)
	begin
		writeback_value_o 			<= #1 writeback_value_nxt;
		mask_o 						<= #1 mask_nxt;
		writeback_is_vector_o 		<= #1 writeback_is_vector_i;
		has_writeback_o 			<= #1 has_writeback_i;
		writeback_reg_o 			<= #1 writeback_reg_i;
	end
endmodule
