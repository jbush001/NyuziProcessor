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
// Instruction execution pipeline
//

module instruction_pipeline
	#(parameter CORE_ID = 0)
	(input                                 clk,
	input                                 reset,
	output logic                          processor_halt,

	// To/From ring controller
	input [`L1D_WAYS - 1:0]               rc_dtag_update_en_oh,
	input l1d_set_idx_t                   rc_dtag_update_set,
	input l1d_tag_t                       rc_dtag_update_tag,
	input cache_line_state_t              rc_dtag_update_state,
	input                                 rc_ddata_update_en,
	input l1d_way_idx_t                   rc_ddata_update_way,
	input l1d_set_idx_t                   rc_ddata_update_set,
	input [`CACHE_LINE_BITS - 1:0]        rc_ddata_update_data,
	input [`THREADS_PER_CORE - 1:0]       rc_dcache_wake_oh,
	input                                 rc_ddata_read_en,
	input l1d_set_idx_t                   rc_ddata_read_set,
 	input l1d_way_idx_t                   rc_ddata_read_way,
	input                                 rc_snoop_en,
	input l1d_set_idx_t                   rc_snoop_set,
	output cache_line_state_t             dt_snoop_state[`L1D_WAYS],
	output l1d_tag_t                      dt_snoop_tag[`L1D_WAYS],
	output l1d_way_idx_t                  dt_snoop_lru,
	output                                dd_cache_miss,
	output scalar_t                       dd_cache_miss_addr,
	output                                dd_cache_miss_store,
	output thread_idx_t                   dd_cache_miss_thread_idx,
	output logic[`CACHE_LINE_BITS - 1:0]  dd_ddata_read_data,
	input [`L1I_WAYS - 1:0]               rc_itag_update_en_oh,
	input l1i_set_idx_t                   rc_itag_update_set,
	input l1i_tag_t                       rc_itag_update_tag,
	input logic                           rc_itag_update_valid,
	input                                 rc_idata_update_en,
	input l1i_way_idx_t                   rc_idata_update_way,
	input l1i_set_idx_t                   rc_idata_update_set,
	input [`CACHE_LINE_BITS - 1:0]        rc_idata_update_data,
	input                                 rc_invalidate_en,
	input l1d_addr_t                      rc_invalidate_addr,
	output logic                          ifd_cache_miss,
	output scalar_t                       ifd_cache_miss_addr,
	output thread_idx_t                   ifd_cache_miss_thread_idx,
	input [`THREADS_PER_CORE - 1:0]       rc_icache_wake_oh,
	input                                 rc_ilru_read_en,
	input l1i_set_idx_t                   rc_ilru_read_set,
	output l1i_way_idx_t                  ift_lru,
	
	// Performance counters
	output                                perf_icache_hit,
	output                                perf_icache_miss,
	output                                perf_dcache_hit,
	output                                perf_dcache_miss,
	output                                perf_instruction_issue,
	output                                perf_instruction_retire);

	scalar_t ift_pc;
	thread_idx_t ift_thread_idx;
	thread_idx_t ifd_thread_idx;
	decoded_instruction_t id_instruction;
	scalar_t ifd_instruction;
	scalar_t ifd_pc;
	thread_idx_t id_thread_idx;
	thread_idx_t dt_thread_idx;
	decoded_instruction_t dt_instruction;
	decoded_instruction_t dd_instruction;
	vector_t dd_result;
	thread_idx_t dd_thread_idx;
	scalar_t dt_request_addr;
	scalar_t dd_request_addr;
	vector_t dt_store_value;
	subcycle_t dt_subcycle;
	subcycle_t dd_subcycle;
	control_register_t dd_creg_index;
	scalar_t dd_creg_write_val;
	scalar_t cr_creg_read_val;
	scalar_t dd_rollback_pc;
	cache_line_state_t dt_state[`L1D_WAYS - 1:0];
	l1d_tag_t dt_tag[`L1D_WAYS];
	l1d_set_idx_t dd_update_lru_set;
	l1i_tag_t ift_tag[`L1I_WAYS];
	l1d_set_idx_t ifd_update_lru_set;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	logic [`THREADS_PER_CORE-1:0] cr_thread_enable;// From control_registers of control_registers.v
	wire		dd_creg_read_en;	// From dcache_data_stage of dcache_data_stage.v
	wire		dd_creg_write_en;	// From dcache_data_stage of dcache_data_stage.v
	logic [`THREADS_PER_CORE-1:0] dd_dcache_wait_oh;// From dcache_data_stage of dcache_data_stage.v
	wire		dd_instruction_valid;	// From dcache_data_stage of dcache_data_stage.v
	wire [`VECTOR_LANES-1:0] dd_mask_value;	// From dcache_data_stage of dcache_data_stage.v
	wire [`CACHE_LINE_BITS-1:0] dd_read_data;// From dcache_data_stage of dcache_data_stage.v
	logic		dd_rollback_en;		// From dcache_data_stage of dcache_data_stage.v
	logic		dd_sync_store_success;	// From dcache_data_stage of dcache_data_stage.v
	logic		dd_update_lru_en;	// From dcache_data_stage of dcache_data_stage.v
	logic [2:0]	dd_update_lru_flags;	// From dcache_data_stage of dcache_data_stage.v
	wire		dt_instruction_valid;	// From dcache_tag_stage of dcache_tag_stage.v
	logic [2:0]	dt_lru_flags;		// From dcache_tag_stage of dcache_tag_stage.v
	wire [`VECTOR_LANES-1:0] dt_mask_value;	// From dcache_tag_stage of dcache_tag_stage.v
	logic		id_instruction_valid;	// From instruction_decode_stage of instruction_decode_stage.v
	logic		ifd_instruction_valid;	// From ifetch_data_stage of ifetch_data_stage.v
	logic		ifd_near_miss;		// From ifetch_data_stage of ifetch_data_stage.v
	logic		ifd_update_lru_en;	// From ifetch_data_stage of ifetch_data_stage.v
	logic [2:0]	ifd_update_lru_flags;	// From ifetch_data_stage of ifetch_data_stage.v
	logic		ift_instruction_requested;// From ifetch_tag_stage of ifetch_tag_stage.v
	logic [2:0]	ift_lru_flags;		// From ifetch_tag_stage of ifetch_tag_stage.v, ...
	logic		ift_valid [`L1I_WAYS];	// From ifetch_tag_stage of ifetch_tag_stage.v, ...
	logic [`VECTOR_LANES-1:0] [7:0] mx1_add_exponent;// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	logic [`VECTOR_LANES-1:0] mx1_add_result_sign;// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	decoded_instruction_t mx1_instruction;	// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	wire		mx1_instruction_valid;	// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	logic [`VECTOR_LANES-1:0] mx1_logical_subtract;// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
	wire [`VECTOR_LANES-1:0] mx1_mask_value;// From multi_cycle_execute_stage1 of multi_cycle_execute_stage1.v
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
	wire [`VECTOR_LANES-1:0] mx2_mask_value;// From multi_cycle_execute_stage2 of multi_cycle_execute_stage2.v
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
	logic [`VECTOR_LANES-1:0] mx3_mask_value;// From multi_cycle_execute_stage3 of multi_cycle_execute_stage3.v
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
	wire [`VECTOR_LANES-1:0] mx4_mask_value;// From multi_cycle_execute_stage4 of multi_cycle_execute_stage4.v
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
	wire [`VECTOR_LANES-1:0] mx5_mask_value;// From multi_cycle_execute_stage5 of multi_cycle_execute_stage5.v
	vector_t	mx5_result;		// From multi_cycle_execute_stage5 of multi_cycle_execute_stage5.v
	subcycle_t	mx5_subcycle;		// From multi_cycle_execute_stage5 of multi_cycle_execute_stage5.v
	thread_idx_t	mx5_thread_idx;		// From multi_cycle_execute_stage5 of multi_cycle_execute_stage5.v
	decoded_instruction_t of_instruction;	// From operand_fetch_stage of operand_fetch_stage.v
	logic		of_instruction_valid;	// From operand_fetch_stage of operand_fetch_stage.v
	logic [`VECTOR_LANES-1:0] of_mask_value;// From operand_fetch_stage of operand_fetch_stage.v
	vector_t	of_operand1;		// From operand_fetch_stage of operand_fetch_stage.v
	vector_t	of_operand2;		// From operand_fetch_stage of operand_fetch_stage.v
	vector_t	of_store_value;		// From operand_fetch_stage of operand_fetch_stage.v
	subcycle_t	of_subcycle;		// From operand_fetch_stage of operand_fetch_stage.v
	thread_idx_t	of_thread_idx;		// From operand_fetch_stage of operand_fetch_stage.v
	decoded_instruction_t sx_instruction;	// From single_cycle_execute_stage of single_cycle_execute_stage.v
	wire		sx_instruction_valid;	// From single_cycle_execute_stage of single_cycle_execute_stage.v
	wire [`VECTOR_LANES-1:0] sx_mask_value;	// From single_cycle_execute_stage of single_cycle_execute_stage.v
	vector_t	sx_result;		// From single_cycle_execute_stage of single_cycle_execute_stage.v
	logic		sx_rollback_en;		// From single_cycle_execute_stage of single_cycle_execute_stage.v
	scalar_t	sx_rollback_pc;		// From single_cycle_execute_stage of single_cycle_execute_stage.v
	subcycle_t	sx_subcycle;		// From single_cycle_execute_stage of single_cycle_execute_stage.v
	thread_idx_t	sx_thread_idx;		// From single_cycle_execute_stage of single_cycle_execute_stage.v
	wire [`THREADS_PER_CORE-1:0] ts_fetch_en;// From thread_select_stage of thread_select_stage.v
	decoded_instruction_t ts_instruction;	// From thread_select_stage of thread_select_stage.v
	logic		ts_instruction_valid;	// From thread_select_stage of thread_select_stage.v
	subcycle_t	ts_subcycle;		// From thread_select_stage of thread_select_stage.v
	thread_idx_t	ts_thread_idx;		// From thread_select_stage of thread_select_stage.v
	wire		wb_fault;		// From writeback_stage of writeback_stage.v
	scalar_t	wb_fault_address;	// From writeback_stage of writeback_stage.v
	fault_reason_t	wb_fault_reason;	// From writeback_stage of writeback_stage.v
	logic		wb_rollback_en;		// From writeback_stage of writeback_stage.v
	scalar_t	wb_rollback_pc;		// From writeback_stage of writeback_stage.v
	pipeline_sel_t	wb_rollback_pipeline;	// From writeback_stage of writeback_stage.v
	subcycle_t	wb_rollback_subcycle;	// From writeback_stage of writeback_stage.v
	thread_idx_t	wb_rollback_thread_idx;	// From writeback_stage of writeback_stage.v
	logic		wb_writeback_en;	// From writeback_stage of writeback_stage.v
	logic		wb_writeback_is_last_subcycle;// From writeback_stage of writeback_stage.v
	logic		wb_writeback_is_vector;	// From writeback_stage of writeback_stage.v
	wire [`VECTOR_LANES-1:0] wb_writeback_mask;// From writeback_stage of writeback_stage.v
	register_idx_t	wb_writeback_reg;	// From writeback_stage of writeback_stage.v
	thread_idx_t	wb_writeback_thread_idx;// From writeback_stage of writeback_stage.v
	vector_t	wb_writeback_value;	// From writeback_stage of writeback_stage.v
	// End of automatics

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
	control_registers #(.CORE_ID(CORE_ID)) control_registers(.*);
	
	assign processor_halt = !(|cr_thread_enable);
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
