
// - Issue memory reads and writes to data cache
// - Aligns small write values correctly

module memory_access_stage(
	input					clk,
	output reg [31:0]		ddata_o,
	output 					dwrite_o,
	output reg [3:0] 		dsel_o,
	input [31:0]			instruction_i,
	output reg[31:0]		instruction_o,
	input [31:0]			pc_i,
	input[31:0]				store_value_i,
	input					has_writeback_i,
	input[4:0]				writeback_reg_i,
	input					writeback_is_vector_i,	
	output reg 				has_writeback_o,
	output reg[4:0]			writeback_reg_o,
	output reg				writeback_is_vector_o,
	input [15:0]			mask_i,
	output reg[15:0]		mask_o,
	input [511:0]			result_i,
	output reg [511:0]		result_o,
	input 					cache_hit_i,
	input [3:0]				lane_select_i,
	output reg[3:0]			lane_select_o);

	initial
	begin
		instruction_o = 0;
		has_writeback_o = 0;
		writeback_reg_o = 0;
		writeback_is_vector_o = 0;
		mask_o = 0;
		result_o = 0;
		lane_select_o = 0;
	end

	// Not registered because it is issued in parallel with this stage.
	assign dwrite_o = instruction_i[31:29] == 3'b100;

	// dsel_o and ddata_o
	always @*
	begin
		case (instruction_i[28:25])
			4'b0000, 4'b0001: // Byte
			begin
				case (result_i[1:0])
					2'b00:
					begin
						dsel_o = 4'b1000;
						ddata_o = { store_value_i[7:0], 24'd0 };
					end

					2'b01:
					begin
						dsel_o = 4'b0100;
						ddata_o = { 8'd0, store_value_i[7:0], 16'd0 };
					end

					2'b10:
					begin
						dsel_o = 4'b0010;
						ddata_o = { 16'd0, store_value_i[7:0], 8'd0 };
					end

					2'b11:
					begin
						dsel_o = 4'b0001;
						ddata_o = { 24'd0, store_value_i[7:0] };
					end
				endcase
			end

			4'b0010, 4'b0011: // 16 bits
			begin
				if (result_i[1] == 1'b0)
				begin
					dsel_o = 4'b1100;
					ddata_o = { store_value_i[7:0], store_value_i[15:8], 16'd0 };
				end
				else
				begin
					dsel_o = 4'b0011;
					ddata_o = { 16'd0, store_value_i[7:0], store_value_i[15:8] };
				end
			end

			default: // 32-bits or vector
			begin
				dsel_o = 4'b1111;
				ddata_o = { store_value_i[7:0], store_value_i[15:8], store_value_i[23:16], 
					store_value_i[31:24] };
			end
		endcase
	end
	
	always @(posedge clk)
	begin
		instruction_o 				<= #1 instruction_i;
		writeback_reg_o 			<= #1 writeback_reg_i;
		writeback_is_vector_o 		<= #1 writeback_is_vector_i;
		has_writeback_o 			<= #1 has_writeback_i;
		mask_o 						<= #1 mask_i;
		result_o 					<= #1 result_i;
		lane_select_o				<= #1 lane_select_i;
	end
endmodule
