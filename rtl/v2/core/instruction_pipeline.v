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

module instruction_pipeline(
	input                                 clk,
	input                                 reset,
	output logic                          processor_halt,
	
	// Cache placeholder
 	output scalar_t                       SIM_icache_request_addr,
	input scalar_t                        SIM_icache_data,
	output scalar_t                       SIM_dcache_request_addr,
	output logic                          SIM_dcache_read_en,
	input [`CACHE_LINE_BITS - 1:0]        SIM_dcache_read_data,
	output logic                          SIM_dcache_write_en,
	output logic[`CACHE_LINE_BITS - 1:0]  SIM_dcache_write_data,
	output logic[`CACHE_LINE_BYTES - 1:0] SIM_dcache_write_mask);

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

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	logic [`THREADS_PER_CORE-1:0] cr_thread_enable;// From control_registers of control_registers.v
	wire		dd_creg_read_en;	// From dcache_data_stage of dcache_data_stage.v
	wire		dd_creg_write_en;	// From dcache_data_stage of dcache_data_stage.v
	wire		dd_instruction_valid;	// From dcache_data_stage of dcache_data_stage.v
	wire [`VECTOR_LANES-1:0] dd_mask_value;	// From dcache_data_stage of dcache_data_stage.v
	wire		dt_instruction_valid;	// From dcache_tag_stage of dcache_tag_stage.v
	wire [`VECTOR_LANES-1:0] dt_mask_value;	// From dcache_tag_stage of dcache_tag_stage.v
	logic		id_instruction_valid;	// From instruction_decode_stage of instruction_decode_stage.v
	logic		ifd_instruction_valid;	// From ifetch_data_stage of ifetch_data_stage.v
	logic		ift_cache_hit;		// From ifetch_tag_stage of ifetch_tag_stage.v
	decoded_instruction_t of_instruction;	// From operand_fetch_stage of operand_fetch_stage.v
	logic		of_instruction_valid;	// From operand_fetch_stage of operand_fetch_stage.v
	logic [`VECTOR_LANES-1:0] of_mask_value;// From operand_fetch_stage of operand_fetch_stage.v
	vector_t	of_operand1;		// From operand_fetch_stage of operand_fetch_stage.v
	vector_t	of_operand2;		// From operand_fetch_stage of operand_fetch_stage.v
	vector_t	of_store_value;		// From operand_fetch_stage of operand_fetch_stage.v
	subcycle_t	of_subcycle;		// From operand_fetch_stage of operand_fetch_stage.v
	thread_idx_t	of_thread_idx;		// From operand_fetch_stage of operand_fetch_stage.v
	decoded_instruction_t sc_instruction;	// From single_cycle_execute_stage of single_cycle_execute_stage.v
	wire		sc_instruction_valid;	// From single_cycle_execute_stage of single_cycle_execute_stage.v
	wire [`VECTOR_LANES-1:0] sc_mask_value;	// From single_cycle_execute_stage of single_cycle_execute_stage.v
	vector_t	sc_result;		// From single_cycle_execute_stage of single_cycle_execute_stage.v
	logic		sc_rollback_en;		// From single_cycle_execute_stage of single_cycle_execute_stage.v
	scalar_t	sc_rollback_pc;		// From single_cycle_execute_stage of single_cycle_execute_stage.v
	thread_idx_t	sc_rollback_thread_idx;	// From single_cycle_execute_stage of single_cycle_execute_stage.v
	subcycle_t	sc_subcycle;		// From single_cycle_execute_stage of single_cycle_execute_stage.v
	thread_idx_t	sc_thread_idx;		// From single_cycle_execute_stage of single_cycle_execute_stage.v
	wire [`THREADS_PER_CORE-1:0] ts_fetch_en;// From thread_select_stage of thread_select_stage.v
	decoded_instruction_t ts_instruction;	// From thread_select_stage of thread_select_stage.v
	logic		ts_instruction_valid;	// From thread_select_stage of thread_select_stage.v
	subcycle_t	ts_subcycle;		// From thread_select_stage of thread_select_stage.v
	thread_idx_t	ts_thread_idx;		// From thread_select_stage of thread_select_stage.v
	logic		wb_is_vector;		// From writeback_stage of writeback_stage.v
	logic		wb_rollback_en;		// From writeback_stage of writeback_stage.v
	scalar_t	wb_rollback_pc;		// From writeback_stage of writeback_stage.v
	pipeline_sel_t	wb_rollback_pipeline;	// From writeback_stage of writeback_stage.v
	subcycle_t	wb_rollback_subcycle;	// From writeback_stage of writeback_stage.v
	thread_idx_t	wb_rollback_thread_idx;	// From writeback_stage of writeback_stage.v
	logic		wb_writeback_en;	// From writeback_stage of writeback_stage.v
	logic		wb_writeback_is_last_subcycle;// From writeback_stage of writeback_stage.v
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
	writeback_stage writeback_stage(.*);
	control_registers control_registers(.*);
	
	assign processor_halt = !(|cr_thread_enable);
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
