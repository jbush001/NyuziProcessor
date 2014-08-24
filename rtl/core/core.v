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

`include "defines.v"

//
// A single CPU, including instruction pipeline and L2 interconnect logic.
// 

module core
	#(parameter CORE_ID = 0)
	(input                                 clk,
	input                                  reset,
	output logic                           processor_halt,

	// L2 interface
	input                                  l2_ready,
	output l2req_packet_t                  l2i_request,
	input l2rsp_packet_t                   l2_response,

	// Non-cacheable IO interface
	output ioreq_packet_t                  ior_request,
	input                                  ia_ready,
	input iorsp_packet_t                   ia_response);

	scalar_t cr_creg_read_val;
	vector_lane_mask_t cr_thread_enable;
	vector_lane_mask_t cr_interrupt_en;
	

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
	logic [`VECTOR_LANES-1:0] [7:0] mx1_add_exponent;// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	logic [`VECTOR_LANES-1:0] mx1_add_result_sign;// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	decoded_instruction_t mx1_instruction;	// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	wire		mx1_instruction_valid;	// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	logic [`VECTOR_LANES-1:0] mx1_logical_subtract;// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	vector_lane_mask_t mx1_mask_value;	// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	logic [`VECTOR_LANES-1:0] [7:0] mx1_mul_exponent;// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	logic [`VECTOR_LANES-1:0] mx1_mul_sign;	// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	logic [`VECTOR_LANES-1:0] [31:0] mx1_multiplicand;// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	logic [`VECTOR_LANES-1:0] [31:0] mx1_multiplier;// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	logic [`VECTOR_LANES-1:0] mx1_result_is_inf;// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	logic [`VECTOR_LANES-1:0] mx1_result_is_nan;// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	logic [`VECTOR_LANES-1:0] [5:0] mx1_se_align_shift;// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	scalar_t [`VECTOR_LANES-1:0] mx1_significand_le;// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	scalar_t [`VECTOR_LANES-1:0] mx1_significand_se;// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	subcycle_t	mx1_subcycle;		// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	thread_idx_t	mx1_thread_idx;		// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	logic [`VECTOR_LANES-1:0] [7:0] mx2_add_exponent;// From multi_cycle_execute_stage2 of multi_cycle_execute_stage2.v
	logic [`VECTOR_LANES-1:0] mx2_add_result_sign;// From multi_cycle_execute_stage2 of multi_cycle_execute_stage2.v
	logic [`VECTOR_LANES-1:0] mx2_guard;	// From multi_cycle_execute_stage2 of multi_cycle_execute_stage2.v
	decoded_instruction_t mx2_instruction;	// From multi_cycle_execute_stage2 of multi_cycle_execute_stage2.v
	wire		mx2_instruction_valid;	// From multi_cycle_execute_stage2 of multi_cycle_execute_stage2.v
	logic [`VECTOR_LANES-1:0] mx2_logical_subtract;// From multi_cycle_execute_stage2 of multi_cycle_execute_stage2.v
	vector_lane_mask_t mx2_mask_value;	// From multi_cycle_execute_stage2 of multi_cycle_execute_stage2.v
	logic [`VECTOR_LANES-1:0] [7:0] mx2_mul_exponent;// From multi_cycle_execute_stage2 of multi_cycle_execute_stage2.v
	logic [`VECTOR_LANES-1:0] mx2_mul_sign;	// From multi_cycle_execute_stage2 of multi_cycle_execute_stage2.v
	logic [`VECTOR_LANES-1:0] mx2_result_is_inf;// From multi_cycle_execute_stage2 of multi_cycle_execute_stage2.v
	logic [`VECTOR_LANES-1:0] mx2_result_is_nan;// From multi_cycle_execute_stage2 of multi_cycle_execute_stage2.v
	logic [`VECTOR_LANES-1:0] mx2_round;	// From multi_cycle_execute_stage2 of multi_cycle_execute_stage2.v
	scalar_t [`VECTOR_LANES-1:0] mx2_significand_le;// From multi_cycle_execute_stage2 of multi_cycle_execute_stage2.v
	logic [`VECTOR_LANES-1:0] [63:0] mx2_significand_product;// From multi_cycle_execute_stage2 of multi_cycle_execute_stage2.v
	scalar_t [`VECTOR_LANES-1:0] mx2_significand_se;// From multi_cycle_execute_stage2 of multi_cycle_execute_stage2.v
	logic [`VECTOR_LANES-1:0] mx2_sticky;	// From multi_cycle_execute_stage2 of multi_cycle_execute_stage2.v
	subcycle_t	mx2_subcycle;		// From multi_cycle_execute_stage2 of multi_cycle_execute_stage2.v
	thread_idx_t	mx2_thread_idx;		// From multi_cycle_execute_stage2 of multi_cycle_execute_stage2.v
	logic [`VECTOR_LANES-1:0] [7:0] mx3_add_exponent;// From multi_cycle_execute_stage3 of multi_cycle_execute_stage3.v
	logic [`VECTOR_LANES-1:0] mx3_add_result_sign;// From multi_cycle_execute_stage3 of multi_cycle_execute_stage3.v
	scalar_t [`VECTOR_LANES-1:0] mx3_add_significand;// From multi_cycle_execute_stage3 of multi_cycle_execute_stage3.v
	decoded_instruction_t mx3_instruction;	// From multi_cycle_execute_stage3 of multi_cycle_execute_stage3.v
	logic		mx3_instruction_valid;	// From multi_cycle_execute_stage3 of multi_cycle_execute_stage3.v
	logic [`VECTOR_LANES-1:0] mx3_logical_subtract;// From multi_cycle_execute_stage3 of multi_cycle_execute_stage3.v
	vector_lane_mask_t mx3_mask_value;	// From multi_cycle_execute_stage3 of multi_cycle_execute_stage3.v
	logic [`VECTOR_LANES-1:0] [7:0] mx3_mul_exponent;// From multi_cycle_execute_stage3 of multi_cycle_execute_stage3.v
	logic [`VECTOR_LANES-1:0] mx3_mul_sign;	// From multi_cycle_execute_stage3 of multi_cycle_execute_stage3.v
	logic [`VECTOR_LANES-1:0] mx3_result_is_inf;// From multi_cycle_execute_stage3 of multi_cycle_execute_stage3.v
	logic [`VECTOR_LANES-1:0] mx3_result_is_nan;// From multi_cycle_execute_stage3 of multi_cycle_execute_stage3.v
	logic [`VECTOR_LANES-1:0] [63:0] mx3_significand_product;// From multi_cycle_execute_stage3 of multi_cycle_execute_stage3.v
	subcycle_t	mx3_subcycle;		// From multi_cycle_execute_stage3 of multi_cycle_execute_stage3.v
	thread_idx_t	mx3_thread_idx;		// From multi_cycle_execute_stage3 of multi_cycle_execute_stage3.v
	logic [`VECTOR_LANES-1:0] [7:0] mx4_add_exponent;// From multi_cycle_execute_stage4 of multi_cycle_execute_stage4.v
	logic [`VECTOR_LANES-1:0] mx4_add_result_sign;// From multi_cycle_execute_stage4 of multi_cycle_execute_stage4.v
	logic [`VECTOR_LANES-1:0] [31:0] mx4_add_significand;// From multi_cycle_execute_stage4 of multi_cycle_execute_stage4.v
	decoded_instruction_t mx4_instruction;	// From multi_cycle_execute_stage4 of multi_cycle_execute_stage4.v
	wire		mx4_instruction_valid;	// From multi_cycle_execute_stage4 of multi_cycle_execute_stage4.v
	logic [`VECTOR_LANES-1:0] mx4_logical_subtract;// From multi_cycle_execute_stage4 of multi_cycle_execute_stage4.v
	vector_lane_mask_t mx4_mask_value;	// From multi_cycle_execute_stage4 of multi_cycle_execute_stage4.v
	logic [`VECTOR_LANES-1:0] [7:0] mx4_mul_exponent;// From multi_cycle_execute_stage4 of multi_cycle_execute_stage4.v
	logic [`VECTOR_LANES-1:0] mx4_mul_sign;	// From multi_cycle_execute_stage4 of multi_cycle_execute_stage4.v
	logic [`VECTOR_LANES-1:0] [5:0] mx4_norm_shift;// From multi_cycle_execute_stage4 of multi_cycle_execute_stage4.v
	logic [`VECTOR_LANES-1:0] mx4_result_is_inf;// From multi_cycle_execute_stage4 of multi_cycle_execute_stage4.v
	logic [`VECTOR_LANES-1:0] mx4_result_is_nan;// From multi_cycle_execute_stage4 of multi_cycle_execute_stage4.v
	logic [`VECTOR_LANES-1:0] [63:0] mx4_significand_product;// From multi_cycle_execute_stage4 of multi_cycle_execute_stage4.v
	subcycle_t	mx4_subcycle;		// From multi_cycle_execute_stage4 of multi_cycle_execute_stage4.v
	thread_idx_t	mx4_thread_idx;		// From multi_cycle_execute_stage4 of multi_cycle_execute_stage4.v
	decoded_instruction_t mx5_instruction;	// From multi_cycle_execute_stage5 of multi_cycle_execute_stage5.v
	wire		mx5_instruction_valid;	// From multi_cycle_execute_stage5 of multi_cycle_execute_stage5.v
	vector_lane_mask_t mx5_mask_value;	// From multi_cycle_execute_stage5 of multi_cycle_execute_stage5.v
	vector_t	mx5_result;		// From multi_cycle_execute_stage5 of multi_cycle_execute_stage5.v
	subcycle_t	mx5_subcycle;		// From multi_cycle_execute_stage5 of multi_cycle_execute_stage5.v
	thread_idx_t	mx5_thread_idx;		// From multi_cycle_execute_stage5 of multi_cycle_execute_stage5.v
	decoded_instruction_t of_instruction;	// From operand_fetch_stage of operand_fetch_stage.v
	logic		of_instruction_valid;	// From operand_fetch_stage of operand_fetch_stage.v
	vector_lane_mask_t of_mask_value;	// From operand_fetch_stage of operand_fetch_stage.v
	vector_t	of_operand1;		// From operand_fetch_stage of operand_fetch_stage.v
	vector_t	of_operand2;		// From operand_fetch_stage of operand_fetch_stage.v
	vector_t	of_store_value;		// From operand_fetch_stage of operand_fetch_stage.v
	subcycle_t	of_subcycle;		// From operand_fetch_stage of operand_fetch_stage.v
	thread_idx_t	of_thread_idx;		// From operand_fetch_stage of operand_fetch_stage.v
	logic		perf_dcache_hit;	// From dcache_data_stage of dcache_data_stage.v
	logic		perf_dcache_miss;	// From dcache_data_stage of dcache_data_stage.v
	logic		perf_icache_hit;	// From ifetch_data_stage of ifetch_data_stage.v
	logic		perf_icache_miss;	// From ifetch_data_stage of ifetch_data_stage.v
	logic		perf_instruction_issue;	// From thread_select_stage of thread_select_stage.v
	logic		perf_instruction_retire;// From writeback_stage of writeback_stage.v
	logic		perf_store_count;	// From dcache_data_stage of dcache_data_stage.v
	logic		perf_store_rollback;	// From writeback_stage of writeback_stage.v
	wire		sq_rollback_en;		// From l2_cache_interface of l2_cache_interface.v
	cache_line_data_t sq_store_bypass_data;	// From l2_cache_interface of l2_cache_interface.v
	wire [`CACHE_LINE_BYTES-1:0] sq_store_bypass_mask;// From l2_cache_interface of l2_cache_interface.v
	logic		sq_store_sync_success;	// From l2_cache_interface of l2_cache_interface.v
	decoded_instruction_t sx_instruction;	// From single_cycle_execute_stage of single_cycle_execute_stage.v
	wire		sx_instruction_valid;	// From single_cycle_execute_stage of single_cycle_execute_stage.v
	vector_lane_mask_t sx_mask_value;	// From single_cycle_execute_stage of single_cycle_execute_stage.v
	vector_t	sx_result;		// From single_cycle_execute_stage of single_cycle_execute_stage.v
	logic		sx_rollback_en;		// From single_cycle_execute_stage of single_cycle_execute_stage.v
	scalar_t	sx_rollback_pc;		// From single_cycle_execute_stage of single_cycle_execute_stage.v
	subcycle_t	sx_subcycle;		// From single_cycle_execute_stage of single_cycle_execute_stage.v
	thread_idx_t	sx_thread_idx;		// From single_cycle_execute_stage of single_cycle_execute_stage.v
	thread_bitmap_t	ts_fetch_en;		// From thread_select_stage of thread_select_stage.v
	decoded_instruction_t ts_instruction;	// From thread_select_stage of thread_select_stage.v
	logic		ts_instruction_valid;	// From thread_select_stage of thread_select_stage.v
	subcycle_t	ts_subcycle;		// From thread_select_stage of thread_select_stage.v
	thread_idx_t	ts_thread_idx;		// From thread_select_stage of thread_select_stage.v
	wire		wb_fault;		// From writeback_stage of writeback_stage.v
	scalar_t	wb_fault_pc;		// From writeback_stage of writeback_stage.v
	fault_reason_t	wb_fault_reason;	// From writeback_stage of writeback_stage.v
	thread_idx_t	wb_fault_thread_idx;	// From writeback_stage of writeback_stage.v
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
	
	// XXX not connected yet
	logic interrupt_req = 0;
	thread_idx_t interrupt_thread_idx = 0;

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
	single_cycle_execute_stage single_cycle_execute_stage(.*);
	multi_cycle_execute_stage1 multi_cycle_execute_stage1(.*);
	multi_cycle_execute_stage2 multi_cycle_execute_stage2(.*);
	multi_cycle_execute_stage3 multi_cycle_execute_stage3(.*);
	multi_cycle_execute_stage4 multi_cycle_execute_stage4(.*);
	multi_cycle_execute_stage5 multi_cycle_execute_stage5(.*);
	writeback_stage writeback_stage(.*);
	
	assign processor_halt = !(|cr_thread_enable);

	control_registers #(.CORE_ID(CORE_ID)) control_registers(.*);
	l2_cache_interface #(.CORE_ID(CORE_ID)) l2_cache_interface(.*);
	io_request_queue #(.CORE_ID(CORE_ID)) io_request_queue(.*);
	
	performance_counters #(.NUM_COUNTERS(8)) performance_counters(
		.perf_event({	
			perf_store_rollback,
			perf_store_count,
			perf_instruction_retire,
			perf_instruction_issue,
			perf_icache_hit,
			perf_icache_miss,
			perf_dcache_hit,
			perf_dcache_miss 
		}),
		.*);
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

