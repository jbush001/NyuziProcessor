//
// Reconcile rollback requests from multiple stages and strands.
//

module rollback_controller(
	input 						clk,
	input [1:0]					ds_strand_i,
	input						ex_rollback_request_i, 	// execute
	input [31:0]				ex_rollback_address_i, 
	input [1:0]					ex_strand_i,
	input						ma_rollback_request_i,	// memory access
	input [31:0]				ma_rollback_address_i,
	input [1:0]					ma_strand_i,
	input [31:0]				ma_rollback_strided_offset_i,
	input [3:0]					ma_rollback_reg_lane_i,
	input						wb_rollback_request_i, 	// writeback
	input [31:0]				wb_rollback_address_i,
	input [1:0]					wb_strand_i,
	output 						flush_ds_o,		// decode
	output 						flush_ex_o,		// execute
	output 						flush_ma_o,		// memory access
	output 						rollback_request_str0_o,
	output reg[31:0]			rollback_address_str0_o = 0,
	output reg[31:0]			rollback_strided_offset_str0_o = 0,
	output reg[3:0]				rollback_reg_lane_str0_o = 0,
	output 						rollback_request_str1_o,
	output reg[31:0]			rollback_address_str1_o = 0,
	output reg[31:0]			rollback_strided_offset_str1_o = 0,
	output reg[3:0]				rollback_reg_lane_str1_o = 0,
	output 						rollback_request_str2_o,
	output reg[31:0]			rollback_address_str2_o = 0,
	output reg[31:0]			rollback_strided_offset_str2_o = 0,
	output reg[3:0]				rollback_reg_lane_str2_o = 0,
	output 						rollback_request_str3_o,
	output reg[31:0]			rollback_address_str3_o = 0,
	output reg[31:0]			rollback_strided_offset_str3_o = 0,
	output reg[3:0]				rollback_reg_lane_str3_o = 0);

	wire rollback_wb_str0 = wb_rollback_request_i && wb_strand_i == 0;
	wire rollback_wb_str1 = wb_rollback_request_i && wb_strand_i == 1;
	wire rollback_wb_str2 = wb_rollback_request_i && wb_strand_i == 2;
	wire rollback_wb_str3 = wb_rollback_request_i && wb_strand_i == 3;
	wire rollback_ma_str0 = ma_rollback_request_i && ma_strand_i == 0;
	wire rollback_ma_str1 = ma_rollback_request_i && ma_strand_i == 1;
	wire rollback_ma_str2 = ma_rollback_request_i && ma_strand_i == 2;
	wire rollback_ma_str3 = ma_rollback_request_i && ma_strand_i == 3;
	wire rollback_ex_str0 = ex_rollback_request_i && ex_strand_i == 0;
	wire rollback_ex_str1 = ex_rollback_request_i && ex_strand_i == 1;
	wire rollback_ex_str2 = ex_rollback_request_i && ex_strand_i == 2;
	wire rollback_ex_str3 = ex_rollback_request_i && ex_strand_i == 3;

	assign rollback_request_str0_o = rollback_wb_str0
		|| rollback_ma_str0
		|| rollback_ex_str0;
	assign rollback_request_str1_o = rollback_wb_str1
		|| rollback_ma_str1
		|| rollback_ex_str1;
	assign rollback_request_str2_o = rollback_wb_str2
		|| rollback_ma_str2
		|| rollback_ex_str2;
	assign rollback_request_str3_o = rollback_wb_str3
		|| rollback_ma_str3
		|| rollback_ex_str3;

	assign flush_ma_o = (rollback_wb_str0 && ma_strand_i == 0)
		|| (rollback_wb_str1 && ma_strand_i == 1)
		|| (rollback_wb_str2 && ma_strand_i == 2)
		|| (rollback_wb_str3 && ma_strand_i == 3);
	assign flush_ex_o = ((rollback_wb_str0 || rollback_ma_str0) && ex_strand_i == 0)
		|| ((rollback_wb_str1 || rollback_ma_str1) && ex_strand_i == 1)
		|| ((rollback_wb_str2 || rollback_ma_str2) && ex_strand_i == 2)
		|| ((rollback_wb_str3 || rollback_ma_str3) && ex_strand_i == 3);
	assign flush_ds_o = (rollback_request_str0_o && ds_strand_i == 0)
		|| (rollback_request_str1_o && ds_strand_i == 1)
		|| (rollback_request_str2_o && ds_strand_i == 2)
		|| (rollback_request_str3_o && ds_strand_i == 3);
		
	always @*
	begin
		if (rollback_wb_str0)
		begin
			rollback_address_str0_o = wb_rollback_address_i;
			rollback_strided_offset_str0_o = 0;
			rollback_reg_lane_str0_o = 0;
		end
		else if (rollback_ma_str0)
		begin
			rollback_address_str0_o = ma_rollback_address_i;
			rollback_strided_offset_str0_o = ma_rollback_strided_offset_i;
			rollback_reg_lane_str0_o = ma_rollback_reg_lane_i;
		end
		else /* if (rollback_ex_str0) or don't care */
		begin
			rollback_address_str0_o = ex_rollback_address_i;
			rollback_strided_offset_str0_o = 0;
			rollback_reg_lane_str0_o = 0;
		end
	end

	always @*
	begin
		if (rollback_wb_str1)
		begin
			rollback_address_str1_o = wb_rollback_address_i;
			rollback_strided_offset_str1_o = 1;
			rollback_reg_lane_str1_o = 1;
		end
		else if (rollback_ma_str1)
		begin
			rollback_address_str1_o = ma_rollback_address_i;
			rollback_strided_offset_str1_o = ma_rollback_strided_offset_i;
			rollback_reg_lane_str1_o = ma_rollback_reg_lane_i;
		end
		else /* if (rollback_ex_str1) or don't care */
		begin
			rollback_address_str1_o = ex_rollback_address_i;
			rollback_strided_offset_str1_o = 1;
			rollback_reg_lane_str1_o = 1;
		end
	end

	always @*
	begin
		if (rollback_wb_str2)
		begin
			rollback_address_str2_o = wb_rollback_address_i;
			rollback_strided_offset_str2_o = 2;
			rollback_reg_lane_str2_o = 2;
		end
		else if (rollback_ma_str2)
		begin
			rollback_address_str2_o = ma_rollback_address_i;
			rollback_strided_offset_str2_o = ma_rollback_strided_offset_i;
			rollback_reg_lane_str2_o = ma_rollback_reg_lane_i;
		end
		else /* if (rollback_ex_str2) or don't care */
		begin
			rollback_address_str2_o = ex_rollback_address_i;
			rollback_strided_offset_str2_o = 2;
			rollback_reg_lane_str2_o = 2;
		end
	end

	always @*
	begin
		if (rollback_wb_str3)
		begin
			rollback_address_str3_o = wb_rollback_address_i;
			rollback_strided_offset_str3_o = 3;
			rollback_reg_lane_str3_o = 3;
		end
		else if (rollback_ma_str3)
		begin
			rollback_address_str3_o = ma_rollback_address_i;
			rollback_strided_offset_str3_o = ma_rollback_strided_offset_i;
			rollback_reg_lane_str3_o = ma_rollback_reg_lane_i;
		end
		else /* if (rollback_ex_str3) or don't care */
		begin
			rollback_address_str3_o = ex_rollback_address_i;
			rollback_strided_offset_str3_o = 3;
			rollback_reg_lane_str3_o = 3;
		end
	end
endmodule
