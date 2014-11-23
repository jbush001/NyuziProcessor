//
// Copyright (C) 2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
//

`include "defines.sv"

//
// A single CPU, including instruction pipeline and L2 interconnect logic.
// 

module core
	#(parameter CORE_ID = 0)
	(input                                 clk,
	input                                  reset,
	output logic                           processor_halt,
	input                                  interrupt_req,

	// L2 interface
	input                                  l2_ready,
	output l2req_packet_t                  l2i_request,
	input l2rsp_packet_t                   l2_response,

	// Non-cacheable IO interface
	output ioreq_packet_t                  ior_request,
	input                                  ia_ready,
	input iorsp_packet_t                   ia_response,
	
	// Performance events
	output logic                           perf_store_rollback,
	output logic                           perf_store_count,
	output logic                           perf_instruction_retire,
	output logic                           perf_instruction_issue,
	output logic                           perf_icache_hit,
	output logic                           perf_icache_miss,
	output logic                           perf_dcache_hit,
	output logic                           perf_dcache_miss);

	scalar_t cr_creg_read_val;
	thread_bitmap_t cr_thread_enable;
	thread_bitmap_t cr_interrupt_en;
	scalar_t cr_fault_handler;
	scalar_t cr_eret_address[`THREADS_PER_CORE];

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	logic		dd_access_fault;	// From dcache_data_stage of dcache_data_stage.v
	logic		dd_cache_miss;		// From dcache_data_stage of dcache_data_stage.v
	scalar_t	dd_cache_miss_addr;	// From dcache_data_stage of dcache_data_stage.v
	logic		dd_cache_miss_synchronized;// From dcache_data_stage of dcache_data_stage.v
	thread_idx_t	dd_cache_miss_thread_idx;// From dcache_data_stage of dcache_data_stage.v
	control_register_t dd_creg_index;	// From dcache_data_stage of dcache_data_stage.v
	wire		dd_creg_read_en;	// From dcache_data_stage of dcache_data_stage.v
	wire		dd_creg_write_en;	// From dcache_data_stage of dcache_data_stage.v
	scalar_t	dd_creg_write_val;	// From dcache_data_stage of dcache_data_stage.v
	logic		dd_flush_en;		// From dcache_data_stage of dcache_data_stage.v
	decoded_instruction_t dd_instruction;	// From dcache_data_stage of dcache_data_stage.v
	wire		dd_instruction_valid;	// From dcache_data_stage of dcache_data_stage.v
	scalar_t	dd_io_addr;		// From dcache_data_stage of dcache_data_stage.v
	wire		dd_io_read_en;		// From dcache_data_stage of dcache_data_stage.v
	thread_idx_t	dd_io_thread_idx;	// From dcache_data_stage of dcache_data_stage.v
	wire		dd_io_write_en;		// From dcache_data_stage of dcache_data_stage.v
	scalar_t	dd_io_write_value;	// From dcache_data_stage of dcache_data_stage.v
	logic		dd_is_io_address;	// From dcache_data_stage of dcache_data_stage.v
	vector_lane_mask_t dd_lane_mask;	// From dcache_data_stage of dcache_data_stage.v
	cache_line_data_t dd_load_data;		// From dcache_data_stage of dcache_data_stage.v
	logic		dd_membar_en;		// From dcache_data_stage of dcache_data_stage.v
	l1d_addr_t	dd_request_addr;	// From dcache_data_stage of dcache_data_stage.v
	logic		dd_rollback_en;		// From dcache_data_stage of dcache_data_stage.v
	scalar_t	dd_rollback_pc;		// From dcache_data_stage of dcache_data_stage.v
	scalar_t	dd_store_addr;		// From dcache_data_stage of dcache_data_stage.v
	scalar_t	dd_store_bypass_addr;	// From dcache_data_stage of dcache_data_stage.v
	thread_idx_t	dd_store_bypass_thread_idx;// From dcache_data_stage of dcache_data_stage.v
	cache_line_data_t dd_store_data;	// From dcache_data_stage of dcache_data_stage.v
	logic		dd_store_en;		// From dcache_data_stage of dcache_data_stage.v
	wire [`CACHE_LINE_BYTES-1:0] dd_store_mask;// From dcache_data_stage of dcache_data_stage.v
	logic		dd_store_synchronized;	// From dcache_data_stage of dcache_data_stage.v
	thread_idx_t	dd_store_thread_idx;	// From dcache_data_stage of dcache_data_stage.v
	subcycle_t	dd_subcycle;		// From dcache_data_stage of dcache_data_stage.v
	logic		dd_suspend_thread;	// From dcache_data_stage of dcache_data_stage.v
	thread_idx_t	dd_thread_idx;		// From dcache_data_stage of dcache_data_stage.v
	logic		dd_update_lru_en;	// From dcache_data_stage of dcache_data_stage.v
	l1d_way_idx_t	dd_update_lru_way;	// From dcache_data_stage of dcache_data_stage.v
	l1d_way_idx_t	dt_fill_lru;		// From dcache_tag_stage of dcache_tag_stage.v
	decoded_instruction_t dt_instruction;	// From dcache_tag_stage of dcache_tag_stage.v
	wire		dt_instruction_valid;	// From dcache_tag_stage of dcache_tag_stage.v
	vector_lane_mask_t dt_mask_value;	// From dcache_tag_stage of dcache_tag_stage.v
	l1d_addr_t	dt_request_addr;	// From dcache_tag_stage of dcache_tag_stage.v
	l1d_tag_t	dt_snoop_tag [`L1D_WAYS];// From dcache_tag_stage of dcache_tag_stage.v
	logic		dt_snoop_valid [`L1D_WAYS];// From dcache_tag_stage of dcache_tag_stage.v
	vector_t	dt_store_value;		// From dcache_tag_stage of dcache_tag_stage.v
	subcycle_t	dt_subcycle;		// From dcache_tag_stage of dcache_tag_stage.v
	l1d_tag_t	dt_tag [`L1D_WAYS];	// From dcache_tag_stage of dcache_tag_stage.v
	thread_idx_t	dt_thread_idx;		// From dcache_tag_stage of dcache_tag_stage.v
	logic		dt_valid [`L1D_WAYS];	// From dcache_tag_stage of dcache_tag_stage.v
	logic [`VECTOR_LANES-1:0] [7:0] fx1_add_exponent;// From fp_execute_stage1 of fp_execute_stage1.v
	logic [`VECTOR_LANES-1:0] fx1_add_result_sign;// From fp_execute_stage1 of fp_execute_stage1.v
	logic [`VECTOR_LANES-1:0] [5:0] fx1_ftoi_lshift;// From fp_execute_stage1 of fp_execute_stage1.v
	decoded_instruction_t fx1_instruction;	// From fp_execute_stage1 of fp_execute_stage1.v
	wire		fx1_instruction_valid;	// From fp_execute_stage1 of fp_execute_stage1.v
	logic [`VECTOR_LANES-1:0] fx1_logical_subtract;// From fp_execute_stage1 of fp_execute_stage1.v
	vector_lane_mask_t fx1_mask_value;	// From fp_execute_stage1 of fp_execute_stage1.v
	logic [`VECTOR_LANES-1:0] [7:0] fx1_mul_exponent;// From fp_execute_stage1 of fp_execute_stage1.v
	logic [`VECTOR_LANES-1:0] fx1_mul_sign;	// From fp_execute_stage1 of fp_execute_stage1.v
	logic [`VECTOR_LANES-1:0] [31:0] fx1_multiplicand;// From fp_execute_stage1 of fp_execute_stage1.v
	logic [`VECTOR_LANES-1:0] [31:0] fx1_multiplier;// From fp_execute_stage1 of fp_execute_stage1.v
	logic [`VECTOR_LANES-1:0] fx1_result_is_inf;// From fp_execute_stage1 of fp_execute_stage1.v
	logic [`VECTOR_LANES-1:0] fx1_result_is_nan;// From fp_execute_stage1 of fp_execute_stage1.v
	logic [`VECTOR_LANES-1:0] [5:0] fx1_se_align_shift;// From fp_execute_stage1 of fp_execute_stage1.v
	scalar_t [`VECTOR_LANES-1:0] fx1_significand_le;// From fp_execute_stage1 of fp_execute_stage1.v
	scalar_t [`VECTOR_LANES-1:0] fx1_significand_se;// From fp_execute_stage1 of fp_execute_stage1.v
	subcycle_t	fx1_subcycle;		// From fp_execute_stage1 of fp_execute_stage1.v
	thread_idx_t	fx1_thread_idx;		// From fp_execute_stage1 of fp_execute_stage1.v
	logic [`VECTOR_LANES-1:0] [7:0] fx2_add_exponent;// From fp_execute_stage2 of fp_execute_stage2.v
	logic [`VECTOR_LANES-1:0] fx2_add_result_sign;// From fp_execute_stage2 of fp_execute_stage2.v
	logic [`VECTOR_LANES-1:0] [5:0] fx2_ftoi_lshift;// From fp_execute_stage2 of fp_execute_stage2.v
	logic [`VECTOR_LANES-1:0] fx2_guard;	// From fp_execute_stage2 of fp_execute_stage2.v
	decoded_instruction_t fx2_instruction;	// From fp_execute_stage2 of fp_execute_stage2.v
	wire		fx2_instruction_valid;	// From fp_execute_stage2 of fp_execute_stage2.v
	logic [`VECTOR_LANES-1:0] fx2_logical_subtract;// From fp_execute_stage2 of fp_execute_stage2.v
	vector_lane_mask_t fx2_mask_value;	// From fp_execute_stage2 of fp_execute_stage2.v
	logic [`VECTOR_LANES-1:0] [7:0] fx2_mul_exponent;// From fp_execute_stage2 of fp_execute_stage2.v
	logic [`VECTOR_LANES-1:0] fx2_mul_sign;	// From fp_execute_stage2 of fp_execute_stage2.v
	logic [`VECTOR_LANES-1:0] fx2_result_is_inf;// From fp_execute_stage2 of fp_execute_stage2.v
	logic [`VECTOR_LANES-1:0] fx2_result_is_nan;// From fp_execute_stage2 of fp_execute_stage2.v
	logic [`VECTOR_LANES-1:0] fx2_round;	// From fp_execute_stage2 of fp_execute_stage2.v
	scalar_t [`VECTOR_LANES-1:0] fx2_significand_le;// From fp_execute_stage2 of fp_execute_stage2.v
	logic [`VECTOR_LANES-1:0] [63:0] fx2_significand_product;// From fp_execute_stage2 of fp_execute_stage2.v
	scalar_t [`VECTOR_LANES-1:0] fx2_significand_se;// From fp_execute_stage2 of fp_execute_stage2.v
	logic [`VECTOR_LANES-1:0] fx2_sticky;	// From fp_execute_stage2 of fp_execute_stage2.v
	subcycle_t	fx2_subcycle;		// From fp_execute_stage2 of fp_execute_stage2.v
	thread_idx_t	fx2_thread_idx;		// From fp_execute_stage2 of fp_execute_stage2.v
	logic [`VECTOR_LANES-1:0] [7:0] fx3_add_exponent;// From fp_execute_stage3 of fp_execute_stage3.v
	logic [`VECTOR_LANES-1:0] fx3_add_result_sign;// From fp_execute_stage3 of fp_execute_stage3.v
	scalar_t [`VECTOR_LANES-1:0] fx3_add_significand;// From fp_execute_stage3 of fp_execute_stage3.v
	logic [`VECTOR_LANES-1:0] [5:0] fx3_ftoi_lshift;// From fp_execute_stage3 of fp_execute_stage3.v
	decoded_instruction_t fx3_instruction;	// From fp_execute_stage3 of fp_execute_stage3.v
	logic		fx3_instruction_valid;	// From fp_execute_stage3 of fp_execute_stage3.v
	logic [`VECTOR_LANES-1:0] fx3_logical_subtract;// From fp_execute_stage3 of fp_execute_stage3.v
	vector_lane_mask_t fx3_mask_value;	// From fp_execute_stage3 of fp_execute_stage3.v
	logic [`VECTOR_LANES-1:0] [7:0] fx3_mul_exponent;// From fp_execute_stage3 of fp_execute_stage3.v
	logic [`VECTOR_LANES-1:0] fx3_mul_sign;	// From fp_execute_stage3 of fp_execute_stage3.v
	logic [`VECTOR_LANES-1:0] fx3_result_is_inf;// From fp_execute_stage3 of fp_execute_stage3.v
	logic [`VECTOR_LANES-1:0] fx3_result_is_nan;// From fp_execute_stage3 of fp_execute_stage3.v
	logic [`VECTOR_LANES-1:0] [63:0] fx3_significand_product;// From fp_execute_stage3 of fp_execute_stage3.v
	subcycle_t	fx3_subcycle;		// From fp_execute_stage3 of fp_execute_stage3.v
	thread_idx_t	fx3_thread_idx;		// From fp_execute_stage3 of fp_execute_stage3.v
	logic [`VECTOR_LANES-1:0] [7:0] fx4_add_exponent;// From fp_execute_stage4 of fp_execute_stage4.v
	logic [`VECTOR_LANES-1:0] fx4_add_result_sign;// From fp_execute_stage4 of fp_execute_stage4.v
	logic [`VECTOR_LANES-1:0] [31:0] fx4_add_significand;// From fp_execute_stage4 of fp_execute_stage4.v
	decoded_instruction_t fx4_instruction;	// From fp_execute_stage4 of fp_execute_stage4.v
	wire		fx4_instruction_valid;	// From fp_execute_stage4 of fp_execute_stage4.v
	logic [`VECTOR_LANES-1:0] fx4_logical_subtract;// From fp_execute_stage4 of fp_execute_stage4.v
	vector_lane_mask_t fx4_mask_value;	// From fp_execute_stage4 of fp_execute_stage4.v
	logic [`VECTOR_LANES-1:0] [7:0] fx4_mul_exponent;// From fp_execute_stage4 of fp_execute_stage4.v
	logic [`VECTOR_LANES-1:0] fx4_mul_sign;	// From fp_execute_stage4 of fp_execute_stage4.v
	logic [`VECTOR_LANES-1:0] [5:0] fx4_norm_shift;// From fp_execute_stage4 of fp_execute_stage4.v
	logic [`VECTOR_LANES-1:0] fx4_result_is_inf;// From fp_execute_stage4 of fp_execute_stage4.v
	logic [`VECTOR_LANES-1:0] fx4_result_is_nan;// From fp_execute_stage4 of fp_execute_stage4.v
	logic [`VECTOR_LANES-1:0] [63:0] fx4_significand_product;// From fp_execute_stage4 of fp_execute_stage4.v
	subcycle_t	fx4_subcycle;		// From fp_execute_stage4 of fp_execute_stage4.v
	thread_idx_t	fx4_thread_idx;		// From fp_execute_stage4 of fp_execute_stage4.v
	decoded_instruction_t fx5_instruction;	// From fp_execute_stage5 of fp_execute_stage5.v
	wire		fx5_instruction_valid;	// From fp_execute_stage5 of fp_execute_stage5.v
	vector_lane_mask_t fx5_mask_value;	// From fp_execute_stage5 of fp_execute_stage5.v
	vector_t	fx5_result;		// From fp_execute_stage5 of fp_execute_stage5.v
	subcycle_t	fx5_subcycle;		// From fp_execute_stage5 of fp_execute_stage5.v
	thread_idx_t	fx5_thread_idx;		// From fp_execute_stage5 of fp_execute_stage5.v
	decoded_instruction_t id_instruction;	// From instruction_decode_stage of instruction_decode_stage.v
	logic		id_instruction_valid;	// From instruction_decode_stage of instruction_decode_stage.v
	thread_idx_t	id_thread_idx;		// From instruction_decode_stage of instruction_decode_stage.v
	logic		ifd_cache_miss;		// From ifetch_data_stage of ifetch_data_stage.v
	scalar_t	ifd_cache_miss_addr;	// From ifetch_data_stage of ifetch_data_stage.v
	thread_idx_t	ifd_cache_miss_thread_idx;// From ifetch_data_stage of ifetch_data_stage.v
	scalar_t	ifd_instruction;	// From ifetch_data_stage of ifetch_data_stage.v
	logic		ifd_instruction_valid;	// From ifetch_data_stage of ifetch_data_stage.v
	logic		ifd_near_miss;		// From ifetch_data_stage of ifetch_data_stage.v
	scalar_t	ifd_pc;			// From ifetch_data_stage of ifetch_data_stage.v
	thread_idx_t	ifd_thread_idx;		// From ifetch_data_stage of ifetch_data_stage.v
	logic		ifd_update_lru_en;	// From ifetch_data_stage of ifetch_data_stage.v
	l1i_way_idx_t	ifd_update_lru_way;	// From ifetch_data_stage of ifetch_data_stage.v
	l1i_way_idx_t	ift_fill_lru;		// From ifetch_tag_stage of ifetch_tag_stage.v
	logic		ift_instruction_requested;// From ifetch_tag_stage of ifetch_tag_stage.v
	l1i_addr_t	ift_pc;			// From ifetch_tag_stage of ifetch_tag_stage.v
	l1i_tag_t	ift_tag [`L1I_WAYS];	// From ifetch_tag_stage of ifetch_tag_stage.v
	thread_idx_t	ift_thread_idx;		// From ifetch_tag_stage of ifetch_tag_stage.v
	logic		ift_valid [`L1I_WAYS];	// From ifetch_tag_stage of ifetch_tag_stage.v
	scalar_t	ior_read_value;		// From io_request_queue of io_request_queue.v
	logic		ior_rollback_en;	// From io_request_queue of io_request_queue.v
	thread_bitmap_t	ior_wake_bitmap;	// From io_request_queue of io_request_queue.v
	decoded_instruction_t ix_instruction;	// From int_execute_stage of int_execute_stage.v
	wire		ix_instruction_valid;	// From int_execute_stage of int_execute_stage.v
	logic		ix_is_eret;		// From int_execute_stage of int_execute_stage.v
	vector_lane_mask_t ix_mask_value;	// From int_execute_stage of int_execute_stage.v
	vector_t	ix_result;		// From int_execute_stage of int_execute_stage.v
	logic		ix_rollback_en;		// From int_execute_stage of int_execute_stage.v
	scalar_t	ix_rollback_pc;		// From int_execute_stage of int_execute_stage.v
	subcycle_t	ix_subcycle;		// From int_execute_stage of int_execute_stage.v
	thread_idx_t	ix_thread_idx;		// From int_execute_stage of int_execute_stage.v
	wire		l2i_dcache_lru_fill_en;	// From l2_cache_interface of l2_cache_interface.v
	l1d_set_idx_t	l2i_dcache_lru_fill_set;// From l2_cache_interface of l2_cache_interface.v
	thread_bitmap_t	l2i_dcache_wake_bitmap;	// From l2_cache_interface of l2_cache_interface.v
	cache_line_data_t l2i_ddata_update_data;// From l2_cache_interface of l2_cache_interface.v
	wire		l2i_ddata_update_en;	// From l2_cache_interface of l2_cache_interface.v
	l1d_set_idx_t	l2i_ddata_update_set;	// From l2_cache_interface of l2_cache_interface.v
	l1d_way_idx_t	l2i_ddata_update_way;	// From l2_cache_interface of l2_cache_interface.v
	wire [`L1D_WAYS-1:0] l2i_dtag_update_en_oh;// From l2_cache_interface of l2_cache_interface.v
	l1d_set_idx_t	l2i_dtag_update_set;	// From l2_cache_interface of l2_cache_interface.v
	l1d_tag_t	l2i_dtag_update_tag;	// From l2_cache_interface of l2_cache_interface.v
	logic		l2i_dtag_update_valid;	// From l2_cache_interface of l2_cache_interface.v
	wire		l2i_icache_lru_fill_en;	// From l2_cache_interface of l2_cache_interface.v
	l1i_set_idx_t	l2i_icache_lru_fill_set;// From l2_cache_interface of l2_cache_interface.v
	thread_bitmap_t	l2i_icache_wake_bitmap;	// From l2_cache_interface of l2_cache_interface.v
	cache_line_data_t l2i_idata_update_data;// From l2_cache_interface of l2_cache_interface.v
	wire		l2i_idata_update_en;	// From l2_cache_interface of l2_cache_interface.v
	l1i_set_idx_t	l2i_idata_update_set;	// From l2_cache_interface of l2_cache_interface.v
	l1i_way_idx_t	l2i_idata_update_way;	// From l2_cache_interface of l2_cache_interface.v
	wire [`L1I_WAYS-1:0] l2i_itag_update_en_oh;// From l2_cache_interface of l2_cache_interface.v
	l1i_set_idx_t	l2i_itag_update_set;	// From l2_cache_interface of l2_cache_interface.v
	l1i_tag_t	l2i_itag_update_tag;	// From l2_cache_interface of l2_cache_interface.v
	logic		l2i_itag_update_valid;	// From l2_cache_interface of l2_cache_interface.v
	logic		l2i_snoop_en;		// From l2_cache_interface of l2_cache_interface.v
	l1d_set_idx_t	l2i_snoop_set;		// From l2_cache_interface of l2_cache_interface.v
	decoded_instruction_t of_instruction;	// From operand_fetch_stage of operand_fetch_stage.v
	logic		of_instruction_valid;	// From operand_fetch_stage of operand_fetch_stage.v
	vector_lane_mask_t of_mask_value;	// From operand_fetch_stage of operand_fetch_stage.v
	vector_t	of_operand1;		// From operand_fetch_stage of operand_fetch_stage.v
	vector_t	of_operand2;		// From operand_fetch_stage of operand_fetch_stage.v
	vector_t	of_store_value;		// From operand_fetch_stage of operand_fetch_stage.v
	subcycle_t	of_subcycle;		// From operand_fetch_stage of operand_fetch_stage.v
	thread_idx_t	of_thread_idx;		// From operand_fetch_stage of operand_fetch_stage.v
	wire		sq_rollback_en;		// From l2_cache_interface of l2_cache_interface.v
	cache_line_data_t sq_store_bypass_data;	// From l2_cache_interface of l2_cache_interface.v
	wire [`CACHE_LINE_BYTES-1:0] sq_store_bypass_mask;// From l2_cache_interface of l2_cache_interface.v
	logic		sq_store_sync_success;	// From l2_cache_interface of l2_cache_interface.v
	thread_bitmap_t	ts_fetch_en;		// From thread_select_stage of thread_select_stage.v
	decoded_instruction_t ts_instruction;	// From thread_select_stage of thread_select_stage.v
	logic		ts_instruction_valid;	// From thread_select_stage of thread_select_stage.v
	subcycle_t	ts_subcycle;		// From thread_select_stage of thread_select_stage.v
	thread_idx_t	ts_thread_idx;		// From thread_select_stage of thread_select_stage.v
	wire		wb_fault;		// From writeback_stage of writeback_stage.v
	scalar_t	wb_fault_access_addr;	// From writeback_stage of writeback_stage.v
	scalar_t	wb_fault_pc;		// From writeback_stage of writeback_stage.v
	fault_reason_t	wb_fault_reason;	// From writeback_stage of writeback_stage.v
	thread_idx_t	wb_fault_thread_idx;	// From writeback_stage of writeback_stage.v
	logic		wb_interrupt_ack;	// From writeback_stage of writeback_stage.v
	logic		wb_rollback_en;		// From writeback_stage of writeback_stage.v
	scalar_t	wb_rollback_pc;		// From writeback_stage of writeback_stage.v
	pipeline_sel_t	wb_rollback_pipeline;	// From writeback_stage of writeback_stage.v
	subcycle_t	wb_rollback_subcycle;	// From writeback_stage of writeback_stage.v
	thread_idx_t	wb_rollback_thread_idx;	// From writeback_stage of writeback_stage.v
	thread_bitmap_t	wb_suspend_thread_oh;	// From writeback_stage of writeback_stage.v
	logic		wb_writeback_en;	// From writeback_stage of writeback_stage.v
	logic		wb_writeback_is_last_subcycle;// From writeback_stage of writeback_stage.v
	logic		wb_writeback_is_vector;	// From writeback_stage of writeback_stage.v
	vector_lane_mask_t wb_writeback_mask;	// From writeback_stage of writeback_stage.v
	register_idx_t	wb_writeback_reg;	// From writeback_stage of writeback_stage.v
	thread_idx_t	wb_writeback_thread_idx;// From writeback_stage of writeback_stage.v
	vector_t	wb_writeback_value;	// From writeback_stage of writeback_stage.v
	// End of automatics
	
	logic interrupt_pending;

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
			interrupt_pending <= 0;
		else if (!interrupt_pending && interrupt_req)
			interrupt_pending <= 1;
		else if (wb_interrupt_ack)
			interrupt_pending <= 0;
	end
	
	thread_idx_t interrupt_thread_idx = 0;	// XXX hard coded

	// 
	// Instruction Execution Pipeline
	//
	ifetch_tag_stage ifetch_tag_stage(.*);
	ifetch_data_stage ifetch_data_stage(.*);
	instruction_decode_stage instruction_decode_stage(.*);
	thread_select_stage thread_select_stage(.*);
	operand_fetch_stage operand_fetch_stage(.*);
	dcache_data_stage dcache_data_stage(.*);
	dcache_tag_stage dcache_tag_stage(.*);
	int_execute_stage int_execute_stage(.*);
	fp_execute_stage1 fp_execute_stage1(.*);
	fp_execute_stage2 fp_execute_stage2(.*);
	fp_execute_stage3 fp_execute_stage3(.*);
	fp_execute_stage4 fp_execute_stage4(.*);
	fp_execute_stage5 fp_execute_stage5(.*);
	writeback_stage writeback_stage(.*);
	
	assign processor_halt = !(|cr_thread_enable);

	control_registers #(.CORE_ID(CORE_ID)) control_registers(.*);
	l2_cache_interface #(.CORE_ID(CORE_ID)) l2_cache_interface(.*);
	io_request_queue #(.CORE_ID(CORE_ID)) io_request_queue(.*);
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

