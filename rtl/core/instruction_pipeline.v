// 
// Copyright 2011-2012 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

`include "defines.v"

//
// Contains the 6 CPU pipeline stages (instruction fetch, strand select,
// decode, execute, memory access, writeback), and the vector and scalar
// register files.
//

module instruction_pipeline
	#(parameter CORE_ID = 30'd0)

	(input                               clk,
	input                                reset,
	output                               halt_o,
	
	// To/from instruction cache
	output [31:0]                        icache_addr,
	input [31:0]                         icache_data,
	output                               icache_request,
	input                                icache_hit,
	output [`STRAND_INDEX_WIDTH - 1:0]   icache_req_strand,
	input [`STRANDS_PER_CORE - 1:0]      icache_load_complete_strands,
	input                                icache_load_collision,

	// Non-cacheable memory signals
	output                               io_write_en,
	output                               io_read_en,
	output[31:0]                         io_address,
	output[31:0]                         io_write_data,
	input [31:0]                         io_read_data,

	// To L1 data cache/store buffer
	output [25:0]                        dcache_addr,
	output                               dcache_load,
	output                               dcache_req_sync,
	output                               dcache_store,
	output                               dcache_flush,
	output                               dcache_stbar,
	output                               dcache_dinvalidate,
	output                               dcache_iinvalidate,
	output [`STRAND_INDEX_WIDTH - 1:0]   dcache_req_strand,
	output [`CACHE_LINE_BYTES - 1:0]     dcache_store_mask,
	output [`CACHE_LINE_BITS - 1:0]      data_to_dcache,

	// From L1 data cache/store buffer
	input                                dcache_hit,
	input                                stbuf_rollback,
	input [`CACHE_LINE_BITS - 1:0]       data_from_dcache,
	input [`STRANDS_PER_CORE - 1:0]      dcache_resume_strands,
	input                                dcache_load_collision,

	// Performance counter events
	output                               pc_event_mispredicted_branch,
	output                               pc_event_instruction_issue,
	output                               pc_event_instruction_retire,
	output                               pc_event_uncond_branch,
	output                               pc_event_cond_branch_taken,
	output                               pc_event_cond_branch_not_taken,
	output                               pc_event_vector_ins_issue,
	output                               pc_event_mem_ins_issue);
	
	logic rf_enable_vector_writeback;
	logic rf_enable_scalar_writeback;
	logic[`REG_IDX_WIDTH - 1:0] rf_writeback_reg;		// One cycle after writeback
	logic[`VECTOR_BITS - 1:0] rf_writeback_value;
	logic[`VECTOR_LANES - 1:0] rf_writeback_mask;
	mask_src_t ds_mask_src;
	op2_src_t ds_op2_src;
	arith_opcode_t ds_alu_op;
	
	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	logic [31:0]	cr_exception_handler_address;// From control_registers of control_registers.v
	logic [31:0]	cr_read_value;		// From control_registers of control_registers.v
	logic [`STRANDS_PER_CORE-1:0] cr_strand_enable;// From control_registers of control_registers.v
	logic		ds_branch_predicted;	// From decode_stage of decode_stage.v
	logic		ds_enable_scalar_writeback;// From decode_stage of decode_stage.v
	logic		ds_enable_vector_writeback;// From decode_stage of decode_stage.v
	logic [31:0]	ds_immediate_value;	// From decode_stage of decode_stage.v
	logic [31:0]	ds_instruction;		// From decode_stage of decode_stage.v
	logic		ds_long_latency;	// From decode_stage of decode_stage.v
	logic		ds_op1_is_vector;	// From decode_stage of decode_stage.v
	logic [31:0]	ds_pc;			// From decode_stage of decode_stage.v
	logic [3:0]	ds_reg_lane_select;	// From decode_stage of decode_stage.v
	logic [`REG_IDX_WIDTH-1:0] ds_scalar_sel1;// From decode_stage of decode_stage.v
	logic [`REG_IDX_WIDTH-1:0] ds_scalar_sel1_l;// From decode_stage of decode_stage.v
	logic [`REG_IDX_WIDTH-1:0] ds_scalar_sel2;// From decode_stage of decode_stage.v
	logic [`REG_IDX_WIDTH-1:0] ds_scalar_sel2_l;// From decode_stage of decode_stage.v
	logic		ds_store_value_is_vector;// From decode_stage of decode_stage.v
	logic [`STRAND_INDEX_WIDTH-1:0] ds_strand;// From decode_stage of decode_stage.v
	logic [31:0]	ds_strided_offset;	// From decode_stage of decode_stage.v
	logic [`REG_IDX_WIDTH-1:0] ds_vector_sel1;// From decode_stage of decode_stage.v
	logic [`REG_IDX_WIDTH-1:0] ds_vector_sel1_l;// From decode_stage of decode_stage.v
	logic [`REG_IDX_WIDTH-1:0] ds_vector_sel2;// From decode_stage of decode_stage.v
	logic [`REG_IDX_WIDTH-1:0] ds_vector_sel2_l;// From decode_stage of decode_stage.v
	logic [`REG_IDX_WIDTH-1:0] ds_writeback_reg;// From decode_stage of decode_stage.v
	logic [31:0]	ex_base_addr;		// From execute_stage of execute_stage.v
	logic		ex_enable_scalar_writeback;// From execute_stage of execute_stage.v
	logic		ex_enable_vector_writeback;// From execute_stage of execute_stage.v
	logic [31:0]	ex_instruction;		// From execute_stage of execute_stage.v
	logic [`VECTOR_LANES-1:0] ex_mask;	// From execute_stage of execute_stage.v
	logic [31:0]	ex_pc;			// From execute_stage of execute_stage.v
	logic [3:0]	ex_reg_lane_select;	// From execute_stage of execute_stage.v
	logic [`VECTOR_BITS-1:0] ex_result;	// From execute_stage of execute_stage.v
	wire [31:0]	ex_rollback_pc;		// From execute_stage of execute_stage.v
	wire		ex_rollback_request;	// From execute_stage of execute_stage.v
	logic [`VECTOR_BITS-1:0] ex_store_value;// From execute_stage of execute_stage.v
	logic [`STRAND_INDEX_WIDTH-1:0] ex_strand;// From execute_stage of execute_stage.v
	wire [`STRAND_INDEX_WIDTH-1:0] ex_strand1;// From execute_stage of execute_stage.v
	wire [`STRAND_INDEX_WIDTH-1:0] ex_strand2;// From execute_stage of execute_stage.v
	wire [`STRAND_INDEX_WIDTH-1:0] ex_strand3;// From execute_stage of execute_stage.v
	logic [31:0]	ex_strided_offset;	// From execute_stage of execute_stage.v
	logic [`REG_IDX_WIDTH-1:0] ex_writeback_reg;// From execute_stage of execute_stage.v
	wire [`STRANDS_PER_CORE-1:0] if_branch_predicted;// From instruction_fetch_stage of instruction_fetch_stage.v
	wire [`STRANDS_PER_CORE*32-1:0] if_instruction;// From instruction_fetch_stage of instruction_fetch_stage.v
	wire [`STRANDS_PER_CORE-1:0] if_instruction_valid;// From instruction_fetch_stage of instruction_fetch_stage.v
	wire [`STRANDS_PER_CORE-1:0] if_long_latency;// From instruction_fetch_stage of instruction_fetch_stage.v
	wire [`STRANDS_PER_CORE*32-1:0] if_pc;	// From instruction_fetch_stage of instruction_fetch_stage.v
	logic		ma_alignment_fault;	// From memory_access_stage of memory_access_stage.v
	logic [3:0]	ma_cache_lane_select;	// From memory_access_stage of memory_access_stage.v
	control_register_t ma_cr_index;		// From memory_access_stage of memory_access_stage.v
	wire		ma_cr_read_en;		// From memory_access_stage of memory_access_stage.v
	wire		ma_cr_write_en;		// From memory_access_stage of memory_access_stage.v
	wire [31:0]	ma_cr_write_value;	// From memory_access_stage of memory_access_stage.v
	logic		ma_enable_scalar_writeback;// From memory_access_stage of memory_access_stage.v
	logic		ma_enable_vector_writeback;// From memory_access_stage of memory_access_stage.v
	logic [31:0]	ma_instruction;		// From memory_access_stage of memory_access_stage.v
	logic [31:0]	ma_io_response;		// From memory_access_stage of memory_access_stage.v
	logic [`VECTOR_LANES-1:0] ma_mask;	// From memory_access_stage of memory_access_stage.v
	logic [31:0]	ma_pc;			// From memory_access_stage of memory_access_stage.v
	logic [3:0]	ma_reg_lane_select;	// From memory_access_stage of memory_access_stage.v
	logic [`VECTOR_BITS-1:0] ma_result;	// From memory_access_stage of memory_access_stage.v
	logic [`STRAND_INDEX_WIDTH-1:0] ma_strand;// From memory_access_stage of memory_access_stage.v
	logic [31:0]	ma_strided_offset;	// From memory_access_stage of memory_access_stage.v
	logic		ma_was_io;		// From memory_access_stage of memory_access_stage.v
	logic		ma_was_load;		// From memory_access_stage of memory_access_stage.v
	logic [`REG_IDX_WIDTH-1:0] ma_writeback_reg;// From memory_access_stage of memory_access_stage.v
	wire [`STRANDS_PER_CORE-1:0] rb_retry_strand;// From rollback_controller of rollback_controller.v
	wire [`STRANDS_PER_CORE*32-1:0] rb_rollback_pc;// From rollback_controller of rollback_controller.v
	wire [`STRANDS_PER_CORE*4-1:0] rb_rollback_reg_lane;// From rollback_controller of rollback_controller.v
	wire [`STRANDS_PER_CORE-1:0] rb_rollback_strand;// From rollback_controller of rollback_controller.v
	wire [`STRANDS_PER_CORE*32-1:0] rb_rollback_strided_offset;// From rollback_controller of rollback_controller.v
	logic		rb_squash_ds;		// From rollback_controller of rollback_controller.v
	logic		rb_squash_ex0;		// From rollback_controller of rollback_controller.v
	logic		rb_squash_ex1;		// From rollback_controller of rollback_controller.v
	logic		rb_squash_ex2;		// From rollback_controller of rollback_controller.v
	logic		rb_squash_ex3;		// From rollback_controller of rollback_controller.v
	logic		rb_squash_ma;		// From rollback_controller of rollback_controller.v
	wire [`STRANDS_PER_CORE-1:0] rb_suspend_strand;// From rollback_controller of rollback_controller.v
	logic [31:0]	scalar_value1;		// From scalar_register_file of scalar_register_file.v
	logic [31:0]	scalar_value2;		// From scalar_register_file of scalar_register_file.v
	logic		ss_branch_predicted;	// From strand_select_stage of strand_select_stage.v
	logic [31:0]	ss_instruction;		// From strand_select_stage of strand_select_stage.v
	wire [`STRANDS_PER_CORE-1:0] ss_instruction_req;// From strand_select_stage of strand_select_stage.v
	logic		ss_long_latency;	// From strand_select_stage of strand_select_stage.v
	logic [31:0]	ss_pc;			// From strand_select_stage of strand_select_stage.v
	logic [3:0]	ss_reg_lane_select;	// From strand_select_stage of strand_select_stage.v
	logic [`STRAND_INDEX_WIDTH-1:0] ss_strand;// From strand_select_stage of strand_select_stage.v
	logic [31:0]	ss_strided_offset;	// From strand_select_stage of strand_select_stage.v
	wire [`VECTOR_BITS-1:0] vector_value1;	// From vector_register_file of vector_register_file.v
	wire [`VECTOR_BITS-1:0] vector_value2;	// From vector_register_file of vector_register_file.v
	logic		wb_enable_scalar_writeback;// From writeback_stage of writeback_stage.v
	logic		wb_enable_vector_writeback;// From writeback_stage of writeback_stage.v
	wire [31:0]	wb_fault_pc;		// From writeback_stage of writeback_stage.v
	wire [`STRAND_INDEX_WIDTH-1:0] wb_fault_strand;// From writeback_stage of writeback_stage.v
	wire		wb_latch_fault;		// From writeback_stage of writeback_stage.v
	wire		wb_retry;		// From writeback_stage of writeback_stage.v
	logic [31:0]	wb_rollback_pc;		// From writeback_stage of writeback_stage.v
	logic		wb_rollback_request;	// From writeback_stage of writeback_stage.v
	wire		wb_suspend_request;	// From writeback_stage of writeback_stage.v
	logic [`VECTOR_LANES-1:0] wb_writeback_mask;// From writeback_stage of writeback_stage.v
	logic [`REG_IDX_WIDTH-1:0] wb_writeback_reg;// From writeback_stage of writeback_stage.v
	logic [`VECTOR_BITS-1:0] wb_writeback_value;// From writeback_stage of writeback_stage.v
	// End of automatics

	assign halt_o = cr_strand_enable == 0;	// If all threads disabled, halt
	assign dcache_req_strand = ex_strand;

	instruction_fetch_stage instruction_fetch_stage(.*);
	strand_select_stage strand_select_stage(
		.resume_strand(dcache_resume_strands),
		.*);

	decode_stage decode_stage(.*);
	scalar_register_file scalar_register_file(
		.wb_writeback_value(wb_writeback_value[31:0]),
		.*);
	vector_register_file vector_register_file(.*);
	execute_stage execute_stage(.*);
	memory_access_stage memory_access_stage(.*);
	writeback_stage writeback_stage(.*);
	control_registers #(.CORE_ID(CORE_ID)) control_registers(.*);
	
	// Even though the results have already been committed to the
	// register file on this cycle, the new register values were
	// fetched a cycle before the bypass stage, so we may still
	// have stale results there.
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			rf_enable_scalar_writeback <= 1'h0;
			rf_enable_vector_writeback <= 1'h0;
			rf_writeback_mask <= {(1+(`VECTOR_LANES-1)){1'b0}};
			rf_writeback_reg <= {(1+(`REG_IDX_WIDTH-1)){1'b0}};
			rf_writeback_value <= {(1+(`VECTOR_BITS-1)){1'b0}};
			// End of automatics
		end
		else
		begin
			// simultaneous vector and scalar writeback
			assert($onehot0({wb_enable_scalar_writeback, wb_enable_vector_writeback}));

			rf_writeback_reg <= wb_writeback_reg;
			rf_writeback_value <= wb_writeback_value;
			rf_writeback_mask <= wb_writeback_mask;
			rf_enable_vector_writeback <= wb_enable_vector_writeback;
			rf_enable_scalar_writeback <= wb_enable_scalar_writeback;
		end
	end

	rollback_controller rollback_controller(.*);
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
