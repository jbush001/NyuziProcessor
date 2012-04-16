//
// Contains the 6 pipeline stages (instruction fetch, strand select,
// decode, execute, memory access, writeback), and the vector and scalar
// register files.
//

module pipeline
	#(parameter			CORE_ID = 30'd0)

	(input				clk,
	output [31:0]		icache_addr,
	input [31:0]		icache_data,
	output				icache_request,
	input				icache_hit,
	output [1:0]		icache_req_strand,
	input [3:0]			icache_load_complete_strands,
	input				icache_load_collision,
	output [31:0]		dcache_addr,
	output				dcache_request,
	output				dcache_req_sync,
	input				dcache_hit,
	input				stbuf_rollback,
	output				dcache_write,
	output [1:0]		dcache_req_strand,
	output [63:0]		dcache_write_mask,
	output [511:0]		data_to_dcache,
	input [511:0]		data_from_dcache,
	input [3:0]			dcache_resume_strands,
	input				dcache_load_collision,
	output				halt_o);
	
	wire[31:0]			dc_instruction;
	wire[31:0]			ma_instruction;
	wire[6:0]			scalar_sel1;
	wire[6:0]			scalar_sel2;
	wire[6:0]			vector_sel1;
	wire[6:0]			vector_sel2;
	wire[31:0]			scalar_value1;
	wire[31:0]			scalar_value2;
	wire[511:0]			vector_value1;
	wire[511:0]			vector_value2;
	wire[31:0]			immediate_value;
	wire[2:0]			mask_src;
	wire				op1_is_vector;
	wire[1:0]			op2_src;
	wire				store_value_is_vector;
	wire				ds_has_writeback;
	wire[6:0]			ds_writeback_reg;
	wire				ds_writeback_is_vector;
	wire				ma_has_writeback;
	wire[6:0]			ma_writeback_reg;
	wire				ma_writeback_is_vector;
	wire[6:0]			wb_writeback_reg;
	wire[511:0]			wb_writeback_value;
	wire[15:0]			wb_writeback_mask;
	wire				wb_writeback_is_vector;
	reg					rf_has_writeback = 0;
	reg[6:0]			rf_writeback_reg = 0;		// One cycle after writeback
	reg[511:0]			rf_writeback_value = 0;
	reg[15:0]			rf_writeback_mask = 0;
	reg					rf_writeback_is_vector = 0;
	wire[15:0]			ma_mask;
	wire[511:0]			ma_result;
	wire[5:0]			alu_op;
	wire [3:0]			ss_reg_lane_select;
	wire [3:0]			ds_reg_lane_select;
	wire [3:0]			ma_reg_lane_select;
	reg[6:0]			vector_sel1_l = 0;
	reg[6:0]			vector_sel2_l = 0;
	reg[6:0]			scalar_sel1_l = 0;
	reg[6:0]			scalar_sel2_l = 0;
	wire[31:0]			ds_pc;
	wire[31:0]			ma_pc;
	wire				wb_rollback_request;
	wire[31:0]			wb_rollback_pc;
	wire				flush_ss;
	wire				flush_ds;
	wire				flush_ex;
	wire				flush_ma;
	wire				rb_rollback_strand0;
	wire[31:0]			rb_rollback_pc0;
	wire[31:0]			rollback_strided_offset0;
	wire[3:0]			rollback_reg_lane0;
	wire				rb_rollback_strand1;
	wire[31:0]			rb_rollback_pc1;
	wire[31:0]			rollback_strided_offset1;
	wire[3:0]			rollback_reg_lane1;
	wire				rb_rollback_strand2;
	wire[31:0]			rb_rollback_pc2;
	wire[31:0]			rollback_strided_offset2;
	wire[3:0]			rollback_reg_lane2;
	wire				rb_rollback_strand3;
	wire[31:0]			rb_rollback_pc3;
	wire[31:0]			rollback_strided_offset3;
	wire[3:0]			rollback_reg_lane3;
	wire				wb_has_writeback;
	wire[3:0]			ma_cache_lane_select;
	wire[31:0]			ds_strided_offset;
	wire[31:0]			ma_strided_offset;
	wire				ma_was_access;
	wire[1:0]			ss_strand;
	wire[1:0]			ds_strand;
	wire[1:0]			ma_strand;
	wire[31:0]			base_addr;
	wire				wb_suspend_request;
	wire				suspend_strand0;
	wire				suspend_strand1;
	wire				suspend_strand2;
	wire				suspend_strand3;
	wire[3:0]			strand_enable;
	
	assign halt_o = strand_enable == 0;	// If all threads disabled, halt
	
	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire		ex_has_writeback;	// From exs of execute_stage.v
	wire [31:0]	ex_instruction;		// From exs of execute_stage.v
	wire [15:0]	ex_mask;		// From exs of execute_stage.v
	wire [31:0]	ex_pc;			// From exs of execute_stage.v
	wire [3:0]	ex_reg_lane_select;	// From exs of execute_stage.v
	wire [511:0]	ex_result;		// From exs of execute_stage.v
	wire [31:0]	ex_rollback_pc;		// From exs of execute_stage.v
	wire		ex_rollback_request;	// From exs of execute_stage.v
	wire [511:0]	ex_store_value;		// From exs of execute_stage.v
	wire [1:0]	ex_strand;		// From exs of execute_stage.v
	wire [31:0]	ex_strided_offset;	// From exs of execute_stage.v
	wire		ex_writeback_is_vector;	// From exs of execute_stage.v
	wire [6:0]	ex_writeback_reg;	// From exs of execute_stage.v
	wire [31:0]	if_instruction0;	// From ifs of instruction_fetch_stage.v
	wire [31:0]	if_instruction1;	// From ifs of instruction_fetch_stage.v
	wire [31:0]	if_instruction2;	// From ifs of instruction_fetch_stage.v
	wire [31:0]	if_instruction3;	// From ifs of instruction_fetch_stage.v
	wire		if_instruction_valid0;	// From ifs of instruction_fetch_stage.v
	wire		if_instruction_valid1;	// From ifs of instruction_fetch_stage.v
	wire		if_instruction_valid2;	// From ifs of instruction_fetch_stage.v
	wire		if_instruction_valid3;	// From ifs of instruction_fetch_stage.v
	wire [31:0]	if_pc0;			// From ifs of instruction_fetch_stage.v
	wire [31:0]	if_pc1;			// From ifs of instruction_fetch_stage.v
	wire [31:0]	if_pc2;			// From ifs of instruction_fetch_stage.v
	wire [31:0]	if_pc3;			// From ifs of instruction_fetch_stage.v
	wire [31:0]	ss_instruction;		// From ss of strand_select_stage.v
	wire		ss_instruction_req0;	// From ss of strand_select_stage.v
	wire		ss_instruction_req1;	// From ss of strand_select_stage.v
	wire		ss_instruction_req2;	// From ss of strand_select_stage.v
	wire		ss_instruction_req3;	// From ss of strand_select_stage.v
	wire [31:0]	ss_pc;			// From ss of strand_select_stage.v
	wire [31:0]	ss_strided_offset;	// From ss of strand_select_stage.v
	// End of automatics

	instruction_fetch_stage ifs(/*AUTOINST*/
				    // Outputs
				    .icache_addr	(icache_addr[31:0]),
				    .icache_request	(icache_request),
				    .icache_req_strand	(icache_req_strand[1:0]),
				    .if_instruction0	(if_instruction0[31:0]),
				    .if_instruction_valid0(if_instruction_valid0),
				    .if_pc0		(if_pc0[31:0]),
				    .if_instruction1	(if_instruction1[31:0]),
				    .if_instruction_valid1(if_instruction_valid1),
				    .if_pc1		(if_pc1[31:0]),
				    .if_instruction2	(if_instruction2[31:0]),
				    .if_instruction_valid2(if_instruction_valid2),
				    .if_pc2		(if_pc2[31:0]),
				    .if_instruction3	(if_instruction3[31:0]),
				    .if_instruction_valid3(if_instruction_valid3),
				    .if_pc3		(if_pc3[31:0]),
				    // Inputs
				    .clk		(clk),
				    .icache_data	(icache_data[31:0]),
				    .icache_hit		(icache_hit),
				    .icache_load_complete_strands(icache_load_complete_strands[3:0]),
				    .icache_load_collision(icache_load_collision),
				    .ss_instruction_req0(ss_instruction_req0),
				    .rb_rollback_strand0(rb_rollback_strand0),
				    .rb_rollback_pc0	(rb_rollback_pc0[31:0]),
				    .ss_instruction_req1(ss_instruction_req1),
				    .rb_rollback_strand1(rb_rollback_strand1),
				    .rb_rollback_pc1	(rb_rollback_pc1[31:0]),
				    .ss_instruction_req2(ss_instruction_req2),
				    .rb_rollback_strand2(rb_rollback_strand2),
				    .rb_rollback_pc2	(rb_rollback_pc2[31:0]),
				    .ss_instruction_req3(ss_instruction_req3),
				    .rb_rollback_strand3(rb_rollback_strand3),
				    .rb_rollback_pc3	(rb_rollback_pc3[31:0]));

	wire resume_strand0 = dcache_resume_strands[0];
	wire resume_strand1 = dcache_resume_strands[1];
	wire resume_strand2 = dcache_resume_strands[2];
	wire resume_strand3 = dcache_resume_strands[3];

	strand_select_stage ss(/*AUTOINST*/
			       // Outputs
			       .ss_instruction_req0(ss_instruction_req0),
			       .ss_instruction_req1(ss_instruction_req1),
			       .ss_instruction_req2(ss_instruction_req2),
			       .ss_instruction_req3(ss_instruction_req3),
			       .ss_pc		(ss_pc[31:0]),
			       .ss_instruction	(ss_instruction[31:0]),
			       .ss_reg_lane_select(ss_reg_lane_select[3:0]),
			       .ss_strided_offset(ss_strided_offset[31:0]),
			       .ss_strand	(ss_strand[1:0]),
			       // Inputs
			       .clk		(clk),
			       .strand_enable	(strand_enable[3:0]),
			       .if_instruction0	(if_instruction0[31:0]),
			       .if_instruction_valid0(if_instruction_valid0),
			       .if_pc0		(if_pc0[31:0]),
			       .rb_rollback_strand0(rb_rollback_strand0),
			       .suspend_strand0	(suspend_strand0),
			       .resume_strand0	(resume_strand0),
			       .rollback_strided_offset0(rollback_strided_offset0[31:0]),
			       .rollback_reg_lane0(rollback_reg_lane0[3:0]),
			       .if_instruction1	(if_instruction1[31:0]),
			       .if_instruction_valid1(if_instruction_valid1),
			       .if_pc1		(if_pc1[31:0]),
			       .rb_rollback_strand1(rb_rollback_strand1),
			       .suspend_strand1	(suspend_strand1),
			       .resume_strand1	(resume_strand1),
			       .rollback_strided_offset1(rollback_strided_offset1[31:0]),
			       .rollback_reg_lane1(rollback_reg_lane1[3:0]),
			       .if_instruction2	(if_instruction2[31:0]),
			       .if_instruction_valid2(if_instruction_valid2),
			       .if_pc2		(if_pc2[31:0]),
			       .rb_rollback_strand2(rb_rollback_strand2),
			       .suspend_strand2	(suspend_strand2),
			       .resume_strand2	(resume_strand2),
			       .rollback_strided_offset2(rollback_strided_offset2[31:0]),
			       .rollback_reg_lane2(rollback_reg_lane2[3:0]),
			       .if_instruction3	(if_instruction3[31:0]),
			       .if_instruction_valid3(if_instruction_valid3),
			       .if_pc3		(if_pc3[31:0]),
			       .rb_rollback_strand3(rb_rollback_strand3),
			       .suspend_strand3	(suspend_strand3),
			       .resume_strand3	(resume_strand3),
			       .rollback_strided_offset3(rollback_strided_offset3[31:0]),
			       .rollback_reg_lane3(rollback_reg_lane3[3:0]));

	decode_stage ds(
		.clk(clk),
		.instruction_i(ss_instruction),
		.instruction_o(dc_instruction),
		.strand_i(ss_strand),
		.strand_o(ds_strand),
		.pc_i(ss_pc),
		.pc_o(ds_pc),
		.reg_lane_select_i(ss_reg_lane_select),
		.reg_lane_select_o(ds_reg_lane_select),
		.immediate_o(immediate_value),
		.mask_src_o(mask_src),
		.op1_is_vector_o(op1_is_vector),
		.op2_src_o(op2_src),
		.store_value_is_vector_o(store_value_is_vector),
		.scalar_sel1(scalar_sel1),
		.scalar_sel2(scalar_sel2),
		.vector_sel1_o(vector_sel1),
		.vector_sel2_o(vector_sel2),
		.has_writeback_o(ds_has_writeback),
		.writeback_reg_o(ds_writeback_reg),
		.writeback_is_vector_o(ds_writeback_is_vector),
		.alu_op_o(alu_op),	// XXX rename to ds_alu_op
		.flush_i(flush_ds),
		.strided_offset_i(ss_strided_offset),
		.strided_offset_o(ds_strided_offset));

	wire enable_scalar_reg_store = wb_has_writeback && ~wb_writeback_is_vector;
	wire enable_vector_reg_store = wb_has_writeback && wb_writeback_is_vector;

	scalar_register_file srf(/*AUTOINST*/
				 // Outputs
				 .scalar_value1		(scalar_value1[31:0]),
				 .scalar_value2		(scalar_value2[31:0]),
				 // Inputs
				 .clk			(clk),
				 .scalar_sel1		(scalar_sel1[6:0]),
				 .scalar_sel2		(scalar_sel2[6:0]),
				 .wb_writeback_reg	(wb_writeback_reg[6:0]),
				 .wb_writeback_value	(wb_writeback_value[31:0]),
				 .enable_scalar_reg_store(enable_scalar_reg_store));
	
	vector_register_file vrf(/*AUTOINST*/
				 // Outputs
				 .vector_value1		(vector_value1[511:0]),
				 .vector_value2		(vector_value2[511:0]),
				 // Inputs
				 .clk			(clk),
				 .vector_sel1		(vector_sel1[6:0]),
				 .vector_sel2		(vector_sel2[6:0]),
				 .wb_writeback_reg	(wb_writeback_reg[6:0]),
				 .wb_writeback_value	(wb_writeback_value[511:0]),
				 .wb_writeback_mask	(wb_writeback_mask[15:0]),
				 .enable_vector_reg_store(enable_vector_reg_store));
	
	always @(posedge clk)
	begin
		vector_sel1_l <= #1 vector_sel1;
		vector_sel2_l <= #1 vector_sel2;
		scalar_sel1_l <= #1 scalar_sel1;
		scalar_sel2_l <= #1 scalar_sel2;
	end
	
	execute_stage exs(/*AUTOINST*/
			  // Outputs
			  .ex_instruction	(ex_instruction[31:0]),
			  .ex_strand		(ex_strand[1:0]),
			  .ex_pc		(ex_pc[31:0]),
			  .ex_store_value	(ex_store_value[511:0]),
			  .ex_has_writeback	(ex_has_writeback),
			  .ex_writeback_reg	(ex_writeback_reg[6:0]),
			  .ex_writeback_is_vector(ex_writeback_is_vector),
			  .ex_mask		(ex_mask[15:0]),
			  .ex_result		(ex_result[511:0]),
			  .ex_reg_lane_select	(ex_reg_lane_select[3:0]),
			  .ex_rollback_request	(ex_rollback_request),
			  .ex_rollback_pc	(ex_rollback_pc[31:0]),
			  .ex_strided_offset	(ex_strided_offset[31:0]),
			  .base_addr		(base_addr[31:0]),
			  // Inputs
			  .clk			(clk),
			  .dc_instruction	(dc_instruction[31:0]),
			  .ds_strand		(ds_strand[1:0]),
			  .ds_pc		(ds_pc[31:0]),
			  .scalar_value1	(scalar_value1[31:0]),
			  .scalar_sel1_l	(scalar_sel1_l[6:0]),
			  .scalar_value2	(scalar_value2[31:0]),
			  .scalar_sel2_l	(scalar_sel2_l[6:0]),
			  .vector_value1	(vector_value1[511:0]),
			  .vector_sel1_l	(vector_sel1_l[6:0]),
			  .vector_value2	(vector_value2[511:0]),
			  .vector_sel2_l	(vector_sel2_l[6:0]),
			  .immediate_value	(immediate_value[31:0]),
			  .mask_src		(mask_src[2:0]),
			  .op1_is_vector	(op1_is_vector),
			  .op2_src		(op2_src[1:0]),
			  .store_value_is_vector(store_value_is_vector),
			  .ds_has_writeback	(ds_has_writeback),
			  .ds_writeback_reg	(ds_writeback_reg[6:0]),
			  .ds_writeback_is_vector(ds_writeback_is_vector),
			  .alu_op		(alu_op[5:0]),
			  .ds_reg_lane_select	(ds_reg_lane_select[3:0]),
			  .ma_writeback_reg	(ma_writeback_reg[6:0]),
			  .ma_has_writeback	(ma_has_writeback),
			  .ma_writeback_is_vector(ma_writeback_is_vector),
			  .ma_result		(ma_result[511:0]),
			  .ma_mask		(ma_mask[15:0]),
			  .wb_writeback_reg	(wb_writeback_reg[6:0]),
			  .wb_has_writeback	(wb_has_writeback),
			  .wb_writeback_is_vector(wb_writeback_is_vector),
			  .wb_writeback_value	(wb_writeback_value[511:0]),
			  .wb_writeback_mask	(wb_writeback_mask[15:0]),
			  .rf_writeback_reg	(rf_writeback_reg[6:0]),
			  .rf_has_writeback	(rf_has_writeback),
			  .rf_writeback_is_vector(rf_writeback_is_vector),
			  .rf_writeback_value	(rf_writeback_value[511:0]),
			  .rf_writeback_mask	(rf_writeback_mask[15:0]),
			  .flush_ex		(flush_ex),
			  .ds_strided_offset	(ds_strided_offset[31:0]));

	assign dcache_req_strand = ex_strand;
		
	memory_access_stage #(CORE_ID) mas(
		.clk(clk),
		.instruction_i(ex_instruction),
		.instruction_o(ma_instruction),
		.strand_i(ex_strand),
		.strand_o(ma_strand),
		.dcache_addr(dcache_addr),
		.dcache_request(dcache_request),
		.dcache_req_sync(dcache_req_sync),
		.strided_offset_i(ex_strided_offset),
		.strided_offset_o(ma_strided_offset),
		.flush_i(flush_ma),
		.base_addr_i(base_addr),
		.pc_i(ex_pc),
		.pc_o(ma_pc),
		.reg_lane_select_i(ex_reg_lane_select),
		.reg_lane_select_o(ma_reg_lane_select),
		.data_to_dcache(data_to_dcache),
		.dcache_write(dcache_write),
		.write_mask_o(dcache_write_mask),
		.store_value_i(ex_store_value),
		.has_writeback_i(ex_has_writeback),
		.writeback_reg_i(ex_writeback_reg),
		.writeback_is_vector_i(ex_writeback_is_vector),
		.has_writeback_o(ma_has_writeback),
		.writeback_reg_o(ma_writeback_reg),
		.writeback_is_vector_o(ma_writeback_is_vector),
		.mask_i(ex_mask),
		.mask_o(ma_mask),
		.result_i(ex_result),
		.result_o(ma_result),
		.cache_lane_select_o(ma_cache_lane_select),
		.strand_enable(strand_enable),
		.was_access_o(ma_was_access));

	writeback_stage wbs(
		.clk(clk),
		.instruction_i(ma_instruction),
		.pc_i(ma_pc),
		.was_access_i(ma_was_access),
		.strand_i(ma_strand),
		.cache_hit_i(dcache_hit),
		.reg_lane_select_i(ma_reg_lane_select),
		.has_writeback_i(ma_has_writeback),
		.writeback_reg_i(ma_writeback_reg),
		.writeback_is_vector_i(ma_writeback_is_vector),
		.has_writeback_o(wb_has_writeback),
		.writeback_is_vector_o(wb_writeback_is_vector),
		.writeback_reg_o(wb_writeback_reg),
		.writeback_value_o(wb_writeback_value),
		.dcache_load_collision(dcache_load_collision),
		.data_from_dcache(data_from_dcache),
		.result_i(ma_result),
		.mask_o(wb_writeback_mask),
		.mask_i(ma_mask),
		.stbuf_rollback(stbuf_rollback),
		.cache_lane_select_i(ma_cache_lane_select),
		.rollback_request_o(wb_rollback_request),
		.rollback_pc_o(wb_rollback_pc),
		.suspend_request_o(wb_suspend_request));
	
	// Even though the results have already been committed to the
	// register file on this cycle, the new register values were
	// fetched a cycle before the bypass stage, so we may still
	// have stale results there.
	always @(posedge clk)
	begin
		rf_writeback_reg			<= #1 wb_writeback_reg;
		rf_writeback_value			<= #1 wb_writeback_value;
		rf_writeback_mask			<= #1 wb_writeback_mask;
		rf_writeback_is_vector		<= #1 wb_writeback_is_vector;
		rf_has_writeback			<= #1 wb_has_writeback;
	end

	rollback_controller rbc(
		.clk(clk),

		// Rollback requests from other stages	
		.ds_strand_i(ss_strand),
		.ex_rollback_request_i(ex_rollback_request),
		.ex_rollback_pc_i(ex_rollback_pc),
		.ex_strand_i(ds_strand),
		.ma_rollback_request_i(0),	// Currently not connected
		.ma_rollback_pc_i(32'd0),	// Currently not connected
		.ma_rollback_strided_offset_i(ex_strided_offset),
		.ma_rollback_reg_lane_i(ex_reg_lane_select),
		.ma_strand_i(ex_strand), 
		.ma_suspend_request_i(0),	// Currently not connected
		.wb_rollback_request_i(wb_rollback_request),
		.wb_rollback_pc_i(wb_rollback_pc),
		.wb_strand_i(ma_strand),
		.wb_rollback_strided_offset_i(ma_strided_offset),
		.wb_rollback_reg_lane_i(ma_reg_lane_select),
		.wb_suspend_request_i(wb_suspend_request),

		.flush_ds_o(flush_ds),
		.flush_ex_o(flush_ex),
		.flush_ma_o(flush_ma),

		.rollback_request_str0_o(rb_rollback_strand0),
		.rollback_pc_str0_o(rb_rollback_pc0),
		.rollback_strided_offset_str0_o(rollback_strided_offset0),
		.rollback_reg_lane_str0_o(rollback_reg_lane0),
		.suspend_str0_o(suspend_strand0),

		.rollback_request_str1_o(rb_rollback_strand1),
		.rollback_pc_str1_o(rb_rollback_pc1),
		.rollback_strided_offset_str1_o(rollback_strided_offset1),
		.rollback_reg_lane_str1_o(rollback_reg_lane1),
		.suspend_str1_o(suspend_strand1),

		.rollback_request_str2_o(rb_rollback_strand2),
		.rollback_pc_str2_o(rb_rollback_pc2),
		.rollback_strided_offset_str2_o(rollback_strided_offset2),
		.rollback_reg_lane_str2_o(rollback_reg_lane2),
		.suspend_str2_o(suspend_strand2),

		.rollback_request_str3_o(rb_rollback_strand3),
		.rollback_pc_str3_o(rb_rollback_pc3),
		.rollback_strided_offset_str3_o(rollback_strided_offset3),
		.rollback_reg_lane_str3_o(rollback_reg_lane3),
		.suspend_str3_o(suspend_strand3));
endmodule
