// 
// Copyright 2011-2013 Jeff Bush
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
// Instruction pipeline writeback stage
//  - Control signals to control writeback of values back to the register file
//  - Handle properly aligning/selecting results of memory loads
//  - Determine what the source of the register writeback should be
//  - PC loads from memory are handled here.
//  - Detect and dispatch exceptions.  We defer processing exceptions from earlier
//    stages until here to ensure the exceptions are precise. Specifically, 
//    we want to make sure they won't be rolled back because of a PC load branch
//    or cache miss.
//

module writeback_stage(
	input                                clk,
	input                                reset,

	// From data cache
	input                                dcache_hit,
	input [`CACHE_LINE_BITS - 1:0]       data_from_dcache,
	input                                dcache_load_collision,
	input                                stbuf_rollback,

	// From memory access stage
	input [31:0]                         ma_instruction,
	input [31:0]                         ma_pc,
	input [`REG_IDX_WIDTH - 1:0]         ma_writeback_reg,
	input                                ma_enable_scalar_writeback,	
	input                                ma_enable_vector_writeback,	
	input [`VECTOR_LANES - 1:0]          ma_mask,
	input                                ma_was_load,
	input                                ma_alignment_fault,
	input [`VECTOR_BITS - 1:0]           ma_result,
	input [3:0]                          ma_reg_lane_select,
	input [3:0]                          ma_cache_lane_select,
	input [`STRAND_INDEX_WIDTH - 1:0]    ma_strand,
	input                                ma_was_io,
	input [31:0]                         ma_io_response,

	// To register file	
	output logic                         wb_enable_scalar_writeback,	
	output logic                         wb_enable_vector_writeback,	
	output logic[`REG_IDX_WIDTH - 1:0]   wb_writeback_reg,
	output logic[`VECTOR_BITS - 1:0]     wb_writeback_value,
	output logic[`VECTOR_LANES - 1:0]    wb_writeback_mask,
	
	// To/From control registers
	input [31:0]                         cr_exception_handler_address,
	output                               wb_latch_fault,
	output [31:0]                        wb_fault_pc,
	output [`STRAND_INDEX_WIDTH - 1:0]   wb_fault_strand,
	
	// To rollback controller
	output logic                         wb_rollback_request,
	output logic[31:0]                   wb_rollback_pc,
	output                               wb_suspend_request,
	output                               wb_retry,
	
	// Performance counter events
	output                               pc_event_instruction_retire);

	logic[`VECTOR_BITS - 1:0] writeback_value_nxt;
	logic[`VECTOR_LANES - 1:0] mask_nxt;
	logic[31:0] aligned_read_value;
	logic[`VECTOR_LANES - 1:0] half_aligned;
	logic[7:0] byte_aligned;
	logic[31:0] lane_value;

	wire is_fmt_c = ma_instruction[31:30] == 2'b10;
	wire is_load = is_fmt_c && ma_instruction[29];
	fmtc_op_t fmtc_op = fmtc_op_t'(ma_instruction[28:25]);
	wire is_control_register_transfer = is_fmt_c
		&& fmtc_op == MEM_CONTROL_REG;
	wire cache_miss = !dcache_hit && ma_was_load && !dcache_load_collision;

	//
	// Detect and signal various rollback conditions
	//
	always_comb
	begin
		if (ma_alignment_fault)
		begin
			wb_rollback_pc = cr_exception_handler_address;
			wb_rollback_request = 1;
		end
		else if (ma_was_io)
		begin
			// Ignore cache hit/miss signals if this was a device IO transaction
			wb_rollback_pc = 0;
			wb_rollback_request = 0;
		end
		else if (dcache_load_collision)
		begin
			// Data came in one cycle too late.  Roll back and retry.
			wb_rollback_pc = ma_pc - 4;
			wb_rollback_request = 1;
		end
		else if (cache_miss || stbuf_rollback)
		begin
			// Data cache read miss or store buffer rollback (full or synchronized store)
			wb_rollback_pc = ma_pc - 4;
			wb_rollback_request = 1;
		end
		else if (ma_enable_scalar_writeback && ma_writeback_reg[4:0] == 31 && is_load)
		begin
			// A load has occurred to PC, branch to that address
			// Note that we checked for a cache miss *before* we checked
			// this case (if we missed the cache, then the read value is 
			// invalid).
			wb_rollback_pc = aligned_read_value;
			wb_rollback_request = 1;
		end
		else
		begin
			wb_rollback_pc = 0;
			wb_rollback_request = 0;
		end
	end
	
	assign wb_latch_fault = ma_alignment_fault;
	assign wb_fault_pc = ma_pc;
	assign wb_fault_strand = ma_strand;
	
`ifdef SIMULATION
	always_ff @(posedge clk)
	begin
		if (ma_alignment_fault && !reset)
			$display("Alignment fault pc %08x memory address %08x", ma_pc, ma_result[31:0]);
	end
`endif	
	
	assign wb_suspend_request = cache_miss || stbuf_rollback;
	assign wb_retry = dcache_load_collision; 

	multiplexer #(.WIDTH(32), .NUM_INPUTS(`VECTOR_LANES), .ASCENDING_INDEX(1)) lane_select_mux(
		.in(data_from_dcache),
		.out(lane_value),
		.select(ma_cache_lane_select));
	
	logic[`CACHE_LINE_BITS - 1:0] endian_twiddled_data;
	endian_swapper dcache_endian_swapper[`CACHE_LINE_WORDS - 1:0](
		.inval(data_from_dcache),
		.endian_twiddled_data(endian_twiddled_data));

	// Byte aligner.  ma_result still contains the effective address,
	// so use that to determine where the data will appear.
	always_comb
	begin
		case (ma_result[1:0])
			2'b00: byte_aligned = lane_value[31:24];
			2'b01: byte_aligned = lane_value[23:16];
			2'b10: byte_aligned = lane_value[15:8];
			2'b11: byte_aligned = lane_value[7:0];
		endcase
	end

	// Halfword aligner.  Same as above.
	always_comb
	begin
		case (ma_result[1])
			1'b0: half_aligned = { lane_value[23:16], lane_value[31:24] };
			1'b1: half_aligned = { lane_value[7:0], lane_value[15:8] };
		endcase
	end

	// Pick the proper aligned result and sign extend as requested.
	always_comb
	begin
		case (fmtc_op)		// Load width
			// Unsigned byte
			MEM_B: aligned_read_value = { 24'b0, byte_aligned };	

			// Signed byte
			MEM_BX: aligned_read_value = { {24{byte_aligned[7]}}, byte_aligned }; 

			// Unsigned half-word
			MEM_S: aligned_read_value = { 16'b0, half_aligned };

			// Signed half-word
			MEM_SX: aligned_read_value = { {16{half_aligned[15]}}, half_aligned };

			// Word (100) and others
			default: aligned_read_value = { lane_value[7:0], lane_value[15:8],
				lane_value[23:16], lane_value[31:24] };	
		endcase
	end

	//
	// Select the value to be written back to the register and the mask if this 
	// is a vector writeback.
	//
	always_comb
	begin
		if (ma_instruction[31:25] == 7'b1000101)
		begin
			// Synchronized store.  Success value comes back from cache
			writeback_value_nxt = data_from_dcache;
			mask_nxt = {`VECTOR_LANES{1'b1}};
		end
		else if (is_load && !is_control_register_transfer)
		begin
			// Load result
			if (ma_was_io)
			begin
				// Non-cache load
				writeback_value_nxt = {`VECTOR_LANES{ma_io_response}}; 
				mask_nxt = {`VECTOR_LANES{1'b1}};
			end
			else if (fmtc_op == MEM_B || fmtc_op == MEM_BX || fmtc_op == MEM_S
				|| fmtc_op == MEM_SX || fmtc_op == MEM_SYNC || fmtc_op == MEM_CONTROL_REG)
			begin
				// Scalar Load
				writeback_value_nxt = {`VECTOR_LANES{aligned_read_value}}; 
				mask_nxt = {`VECTOR_LANES{1'b1}};
			end
			else if (fmtc_op == MEM_BLOCK || fmtc_op == MEM_BLOCK_M
					|| fmtc_op == MEM_BLOCK_IM)
			begin
				// Block load
				mask_nxt = ma_mask;	
				writeback_value_nxt = endian_twiddled_data;	// Vector Load
			end
			else 
			begin
				// Strided or gather load
				// Grab the appropriate lane.
				writeback_value_nxt = {`VECTOR_LANES{aligned_read_value}};
				mask_nxt = (1 << ma_reg_lane_select) & ma_mask;	// sg or strided
			end
		end
		else
		begin
			// Arithmetic operation or control register read.
			writeback_value_nxt = ma_result;
			mask_nxt = ma_mask;
		end
	end
	
	assign pc_event_instruction_retire = !wb_rollback_request && ma_instruction != `NOP;

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			wb_enable_scalar_writeback <= 1'h0;
			wb_enable_vector_writeback <= 1'h0;
			wb_writeback_mask <= {(1+(`VECTOR_LANES-1)){1'b0}};
			wb_writeback_reg <= {(1+(`REG_IDX_WIDTH-1)){1'b0}};
			wb_writeback_value <= {(1+(`VECTOR_BITS-1)){1'b0}};
			// End of automatics
		end
		else
		begin
			wb_writeback_value 			<= writeback_value_nxt;
			wb_writeback_mask 			<= mask_nxt;
			wb_writeback_reg 			<= ma_writeback_reg;
			wb_enable_scalar_writeback 	<= ma_enable_scalar_writeback && !wb_rollback_request;	
			wb_enable_vector_writeback 	<= ma_enable_vector_writeback && !wb_rollback_request;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

