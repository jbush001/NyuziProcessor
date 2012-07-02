//
// Reconcile rollback requests from multiple stages and strands.
//
// When a rollback occurs, we only rollback stages that are earlier in the 
// pipeline and are from the same strand.
//
// A rollback request does not trigger a flush of the unit that requested the 
// rollback. The requesting unit must do that.  This is mainly because of call
// instructions, which must propagate to the writeback stage to update the link
// register.
//
// Note that the ex_strandx notation may be confusing:
//    ex_strand refers to the instruction coming out of the execute stage
//    exn_strand is an intermediate strand in the multi-cycle pipeline, which may be
//     a *later* instruction that ex_strand.

module rollback_controller(
	input [1:0]					ss_strand,
	input						ex_rollback_request, 	// execute
	input [31:0]				ex_rollback_pc, 
	input [1:0]					ds_strand,
	input [1:0]					ex_strand,				// strand coming out of ex stage
	input [1:0]					ex_strand1,				// strands in multi-cycle pipeline
	input [1:0]					ex_strand2,
	input [1:0]					ex_strand3,
	input						wb_rollback_request, 	// writeback
	input [31:0]				wb_rollback_pc,
	input [31:0]				ma_strided_offset,
	input [3:0]					ma_reg_lane_select,
	input [1:0]					ma_strand,
	input						wb_suspend_request,
	output 						flush_ds,		// decode
	output 						flush_ex0,		// execute
	output 						flush_ex1,
	output 						flush_ex2,
	output 						flush_ex3,
	output 						flush_ma,		// memory access
	output 						rb_rollback_strand0,
	output reg[31:0]			rb_rollback_pc0 = 0,
	output reg[31:0]			rollback_strided_offset0 = 0,
	output reg[3:0]				rollback_reg_lane0 = 0,
	output reg					suspend_strand0 = 0,
	output 						rb_rollback_strand1,
	output reg[31:0]			rb_rollback_pc1 = 0,
	output reg[31:0]			rollback_strided_offset1 = 0,
	output reg[3:0]				rollback_reg_lane1 = 0,
	output reg					suspend_strand1 = 0,
	output 						rb_rollback_strand2,
	output reg[31:0]			rb_rollback_pc2 = 0,
	output reg[31:0]			rollback_strided_offset2 = 0,
	output reg[3:0]				rollback_reg_lane2 = 0,
	output reg					suspend_strand2 = 0,
	output 						rb_rollback_strand3,
	output reg[31:0]			rb_rollback_pc3 = 0,
	output reg[31:0]			rollback_strided_offset3 = 0,
	output reg[3:0]				rollback_reg_lane3 = 0,
	output reg					suspend_strand3 = 0);

	wire rollback_wb_str0 = wb_rollback_request && ma_strand == 0;
	wire rollback_wb_str1 = wb_rollback_request && ma_strand == 1;
	wire rollback_wb_str2 = wb_rollback_request && ma_strand == 2;
	wire rollback_wb_str3 = wb_rollback_request && ma_strand == 3;
	wire rollback_ex_str0 = ex_rollback_request && ds_strand == 0;
	wire rollback_ex_str1 = ex_rollback_request && ds_strand == 1;
	wire rollback_ex_str2 = ex_rollback_request && ds_strand == 2;
	wire rollback_ex_str3 = ex_rollback_request && ds_strand == 3;

	assign rb_rollback_strand0 = rollback_wb_str0
		|| rollback_ex_str0;
	assign rb_rollback_strand1 = rollback_wb_str1
		|| rollback_ex_str1;
	assign rb_rollback_strand2 = rollback_wb_str2
		|| rollback_ex_str2;
	assign rb_rollback_strand3 = rollback_wb_str3
		|| rollback_ex_str3;

	assign flush_ma = (rollback_wb_str0 && ex_strand == 0)
		|| (rollback_wb_str1 && ex_strand == 1)
		|| (rollback_wb_str2 && ex_strand == 2)
		|| (rollback_wb_str3 && ex_strand == 3);
	assign flush_ex0 = (rollback_wb_str0 && ds_strand == 0)
		|| (rollback_wb_str1 && ds_strand == 1)
		|| (rollback_wb_str2 && ds_strand == 2)
		|| (rollback_wb_str3 && ds_strand == 3);
	assign flush_ex1 = (rollback_wb_str0 && ex_strand1 == 0)
		|| (rollback_wb_str1 && ex_strand1 == 1)
		|| (rollback_wb_str2 && ex_strand1 == 2)
		|| (rollback_wb_str3 && ex_strand1 == 3);
	assign flush_ex2 = (rollback_wb_str0 && ex_strand2 == 0)
		|| (rollback_wb_str1 && ex_strand2 == 1)
		|| (rollback_wb_str2 && ex_strand2 == 2)
		|| (rollback_wb_str3 && ex_strand2 == 3);
	assign flush_ex3 = (rollback_wb_str0 && ex_strand3 == 0)
		|| (rollback_wb_str1 && ex_strand3 == 1)
		|| (rollback_wb_str2 && ex_strand3 == 2)
		|| (rollback_wb_str3 && ex_strand3 == 3);
	assign flush_ds = (rb_rollback_strand0 && ss_strand == 0)
		|| (rb_rollback_strand1 && ss_strand == 1)
		|| (rb_rollback_strand2 && ss_strand == 2)
		|| (rb_rollback_strand3 && ss_strand == 3);
		
	always @*
	begin
		if (rollback_wb_str0)
		begin
			rb_rollback_pc0 = wb_rollback_pc;
			rollback_strided_offset0 = ma_strided_offset;
			rollback_reg_lane0 = ma_reg_lane_select;
			suspend_strand0 = wb_suspend_request;
		end
		else /* if (rollback_ex_str0) or don't care */
		begin
			rb_rollback_pc0 = ex_rollback_pc;
			rollback_strided_offset0 = 0;
			rollback_reg_lane0 = 0;
			suspend_strand0 = 0;
		end
	end

	always @*
	begin
		if (rollback_wb_str1)
		begin
			rb_rollback_pc1 = wb_rollback_pc;
			rollback_strided_offset1 = ma_strided_offset;
			rollback_reg_lane1 = ma_reg_lane_select;
			suspend_strand1 = wb_suspend_request;
		end
		else /* if (rollback_ex_str1) or don't care */
		begin
			rb_rollback_pc1 = ex_rollback_pc;
			rollback_strided_offset1 = 0;
			rollback_reg_lane1 = 0;
			suspend_strand1 = 0;
		end
	end

	always @*
	begin
		if (rollback_wb_str2)
		begin
			rb_rollback_pc2 = wb_rollback_pc;
			rollback_strided_offset2 = ma_strided_offset;
			rollback_reg_lane2 = ma_reg_lane_select;
			suspend_strand2 = wb_suspend_request;
		end
		else /* if (rollback_ex_str2) or don't care */
		begin
			rb_rollback_pc2 = ex_rollback_pc;
			rollback_strided_offset2 = 0;
			rollback_reg_lane2 = 0;
			suspend_strand2 = 0;
		end
	end

	always @*
	begin
		if (rollback_wb_str3)
		begin
			rb_rollback_pc3 = wb_rollback_pc;
			rollback_strided_offset3 = ma_strided_offset;
			rollback_reg_lane3 = ma_reg_lane_select;
			suspend_strand3 = wb_suspend_request;
		end
		else /* if (rollback_ex_str3) or don't care */
		begin
			rb_rollback_pc3 = ex_rollback_pc;
			rollback_strided_offset3 = 0;
			rollback_reg_lane3 = 0;
			suspend_strand3 = 0;
		end
	end
endmodule
