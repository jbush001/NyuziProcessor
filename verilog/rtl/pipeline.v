
module pipeline(
	input				clk,
	output [31:0]		iaddress_o,
	input [31:0]		idata_i,
	output				iaccess_o,
	input				icache_hit_i,
	output [31:0]		daddress_o,
	output				daccess_o,
	input				dcache_hit_i,
	input               dstbuf_full_i,
	output				dwrite_o,
	output [63:0]		dwrite_mask_o,
	output [511:0]		ddata_o,
	input [511:0]		ddata_i,
	input               cache_load_complete_i);
	
	wire[31:0]			if_instruction;
	wire[31:0]			ss_instruction;
	wire[31:0]			dc_instruction;
	wire[31:0]			ex_instruction;
	wire[31:0]			ma_instruction;
	wire[4:0]			scalar_sel1;
	wire[4:0]			scalar_sel2;
	wire[4:0]			vector_sel1;
	wire[4:0]			vector_sel2;
	wire[31:0]			scalar_value1;
	wire[31:0]			scalar_value2;
	wire[511:0]			vector_value1;
	wire[511:0]			vector_value2;
	wire[31:0]			immediate_value;
	wire[2:0]			mask_src;
	wire				op1_is_vector;
	wire[1:0]			op2_src;
	wire				store_value_is_vector;
	wire[511:0]			ex_store_value;
	wire				ds_has_writeback;
	wire[4:0]			ds_writeback_reg;
	wire				ds_writeback_is_vector;
	wire				ex_has_writeback;
	wire[4:0]			ex_writeback_reg;
	wire				ex_writeback_is_vector;
	wire				ma_has_writeback;
	wire[4:0]			ma_writeback_reg;
	wire				ma_writeback_is_vector;
	wire[4:0]			wb_writeback_reg;
	wire[511:0]			wb_writeback_value;
	wire[15:0]			wb_writeback_mask;
	wire				wb_writeback_is_vector;
	reg					rf_has_writeback;
	reg[4:0]			rf_writeback_reg;		// One cycle after writeback
	reg[511:0]			rf_writeback_value;
	reg[15:0]			rf_writeback_mask;
	reg					rf_writeback_is_vector;
	wire[15:0]			ex_mask;
	wire[15:0]			ma_mask;
	wire[511:0]			ex_result;
	wire[511:0]			ma_result;
	wire[5:0]			alu_op;
	wire				enable_scalar_reg_store;
	wire				enable_vector_reg_store;
	wire [3:0]			ss_reg_lane_select;
	wire [3:0]			ds_reg_lane_select;
	wire [3:0]			ex_reg_lane_select;
	wire [3:0]			ma_reg_lane_select;
	reg[4:0]			vector_sel1_l;
	reg[4:0]			vector_sel2_l;
	reg[4:0]			scalar_sel1_l;
	reg[4:0]			scalar_sel2_l;
	wire[31:0]			if_pc;
	wire[31:0]			ss_pc;
	wire[31:0]			ds_pc;
	wire[31:0]			ex_pc;
	wire[31:0]			ma_pc;
	wire				ex_rollback_request;
	wire[31:0]			ex_rollback_address;
	wire				ma_rollback_request;
	wire				wb_rollback_request;
	wire[31:0]			wb_rollback_address;
	wire				flush_request1;
	wire				flush_request2;
	wire				flush_request3;
	wire				flush_request4;
	wire				restart_request;
	wire[31:0]			restart_address;
	wire				stall;
	wire				wb_has_writeback;
	wire[3:0]           ex_cache_lane_select;
	wire[3:0]           ma_cache_lane_select;
	wire[31:0]          ss_strided_offset;
	wire[31:0]          ds_strided_offset;
	wire                ma_was_access;
	wire[31:0]          ma_rollback_address;
	
	initial
	begin
		rf_has_writeback = 0;
		rf_writeback_reg = 0;	
		rf_writeback_value = 0;
		rf_writeback_mask = 0;
		rf_writeback_is_vector = 0;
		vector_sel1_l = 0;
		vector_sel2_l = 0;
		scalar_sel1_l = 0;
		scalar_sel2_l = 0;
	end
	
	instruction_fetch_stage ifs(
		.clk(clk),
		.pc_o(if_pc),
		.iaddress_o(iaddress_o),
		.iaccess_o(iaccess_o),
		.idata_i(idata_i),
		.icache_hit_i(icache_hit_i),
		.instruction_o(if_instruction),
		.restart_request_i(restart_request),
		.restart_address_i(restart_address),
		.stall_i(stall));

	strand_select_stage ss(
		.clk(clk),
		.pc_i(if_pc),
		.pc_o(ss_pc),
		.reg_lane_select_o(ss_reg_lane_select),
		.instruction_i(if_instruction),
		.instruction_o(ss_instruction),
		.flush_i(flush_request1),
		.stall_o(stall),
		.strided_offset_o(ss_strided_offset),
		.suspend_strand_i(ma_rollback_request),
		.resume_strand_i(cache_load_complete_i));

	decode_stage ds(
		.clk(clk),
		.instruction_i(ss_instruction),
		.instruction_o(dc_instruction),
		.pc_i(ss_pc),
		.pc_o(ds_pc),
		.reg_lane_select_i(ss_reg_lane_select),
		.reg_lane_select_o(ds_reg_lane_select),
		.immediate_o(immediate_value),
		.mask_src_o(mask_src),
		.op1_is_vector_o(op1_is_vector),
		.op2_src_o(op2_src),
		.store_value_is_vector_o(store_value_is_vector),
		.scalar_sel1_o(scalar_sel1),
		.scalar_sel2_o(scalar_sel2),
		.vector_sel1_o(vector_sel1),
		.vector_sel2_o(vector_sel2),
		.has_writeback_o(ds_has_writeback),
		.writeback_reg_o(ds_writeback_reg),
		.writeback_is_vector_o(ds_writeback_is_vector),
		.alu_op_o(alu_op),
		.flush_i(flush_request2),
		.strided_offset_i(ss_strided_offset),
		.strided_offset_o(ds_strided_offset));

	assign enable_scalar_reg_store = wb_has_writeback && ~wb_writeback_is_vector;
	assign enable_vector_reg_store = wb_has_writeback && wb_writeback_is_vector;

	scalar_register_file srf(
		.clk(clk),
		.sel1_i(scalar_sel1),
		.sel2_i(scalar_sel2),
		.value1_o(scalar_value1),
		.value2_o(scalar_value2),
		.write_reg_i(wb_writeback_reg),
		.write_value_i(wb_writeback_value[31:0]),
		.write_enable_i(enable_scalar_reg_store));
	
	vector_register_file vrf(
		.clk(clk),
		.sel1_i(vector_sel1),
		.sel2_i(vector_sel2),
		.value1_o(vector_value1),
		.value2_o(vector_value2),
		.write_reg_i(wb_writeback_reg),
		.write_value_i(wb_writeback_value),
		.write_mask_i(wb_writeback_mask),
		.write_en_i(enable_vector_reg_store));
	
	always @(posedge clk)
	begin
		vector_sel1_l <= #1 vector_sel1;
		vector_sel2_l <= #1 vector_sel2;
		scalar_sel1_l <= #1 scalar_sel1;
		scalar_sel2_l <= #1 scalar_sel2;
	end
	
	execute_stage exs(
		.clk(clk),
		.instruction_i(dc_instruction),
		.instruction_o(ex_instruction),
		.flush_i(flush_request3),
		.pc_i(ds_pc),
		.pc_o(ex_pc),
		.reg_lane_select_i(ds_reg_lane_select),
		.reg_lane_select_o(ex_reg_lane_select),
		.mask_src_i(mask_src),
		.op1_is_vector_i(op1_is_vector),
		.op2_src_i(op2_src),
		.scalar_value1_i(scalar_value1),
		.scalar_value2_i(scalar_value2),
		.vector_value1_i(vector_value1),
		.vector_value2_i(vector_value2),
		.scalar_sel1_i(scalar_sel1_l),
		.scalar_sel2_i(scalar_sel2_l),
		.vector_sel1_i(vector_sel1_l),
		.vector_sel2_i(vector_sel2_l),
		.immediate_i(immediate_value),
		.store_value_is_vector_i(store_value_is_vector),
		.store_value_o(ex_store_value),
		.has_writeback_i(ds_has_writeback),
		.writeback_reg_i(ds_writeback_reg),
		.writeback_is_vector_i(ds_writeback_is_vector),
		.has_writeback_o(ex_has_writeback),
		.writeback_reg_o(ex_writeback_reg),
		.writeback_is_vector_o(ex_writeback_is_vector),
		.mask_o(ex_mask),
		.result_o(ex_result),
		.alu_op_i(alu_op),
		.daddress_o(daddress_o),
		.daccess_o(daccess_o),
		.bypass1_register(ma_writeback_reg),	
		.bypass1_has_writeback(ma_has_writeback),
		.bypass1_is_vector(ma_writeback_is_vector),
		.bypass1_value(ma_result),
		.bypass1_mask(ma_mask),
		.bypass2_register(wb_writeback_reg),	
		.bypass2_has_writeback(wb_has_writeback),
		.bypass2_is_vector(wb_writeback_is_vector),
		.bypass2_value(wb_writeback_value),
		.bypass2_mask(wb_writeback_mask),
		.bypass3_register(rf_writeback_reg),	
		.bypass3_has_writeback(rf_has_writeback),
		.bypass3_is_vector(rf_writeback_is_vector),
		.bypass3_value(rf_writeback_value),
		.bypass3_mask(rf_writeback_mask),
		.rollback_request_o(ex_rollback_request),
		.rollback_address_o(ex_rollback_address),
		.cache_lane_select_o(ex_cache_lane_select),
		.strided_offset_i(ds_strided_offset),
		.was_access_o(ma_was_access));

	memory_access_stage mas(
		.clk(clk),
		.instruction_i(ex_instruction),
		.instruction_o(ma_instruction),
		.flush_i(flush_request4),
		.pc_i(ex_pc),
		.reg_lane_select_i(ex_reg_lane_select),
		.reg_lane_select_o(ma_reg_lane_select),
		.ddata_o(ddata_o),
		.dwrite_o(dwrite_o),
		.write_mask_o(dwrite_mask_o),
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
		.cache_hit_i(dcache_hit_i),
		.dstbuf_full_i(dstbuf_full_i),
		.cache_lane_select_i(ex_cache_lane_select),
		.cache_lane_select_o(ma_cache_lane_select),
		.rollback_request_o(ma_rollback_request),
		.rollback_address_o(ma_rollback_address),
		.was_access_i(ma_was_access));

	writeback_stage wbs(
		.clk(clk),
		.instruction_i(ma_instruction),
		.reg_lane_select_i(ma_reg_lane_select),
		.has_writeback_i(ma_has_writeback),
		.writeback_reg_i(ma_writeback_reg),
		.writeback_is_vector_i(ma_writeback_is_vector),
		.has_writeback_o(wb_has_writeback),
		.writeback_is_vector_o(wb_writeback_is_vector),
		.writeback_reg_o(wb_writeback_reg),
		.writeback_value_o(wb_writeback_value),
		.ddata_i(ddata_i),
		.result_i(ma_result),
		.mask_o(wb_writeback_mask),
		.mask_i(ma_mask),
		.cache_lane_select_i(ma_cache_lane_select),
		.rollback_request_o(wb_rollback_request),
		.rollback_address_o(wb_rollback_address));
	
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
		.rollback_request1_i(ex_rollback_request),
		.rollback_address1_i(ex_rollback_address),
		.rollback_request2_i(ma_rollback_request),
		.rollback_address2_i(ma_rollback_address),
		.rollback_request3_i(wb_rollback_request),
		.rollback_address3_i(wb_rollback_address),
		.flush_request1_o(flush_request1),
		.flush_request2_o(flush_request2),
		.flush_request3_o(flush_request3),
		.flush_request4_o(flush_request4),
		.restart_request_o(restart_request),
		.restart_address_o(restart_address));
endmodule
