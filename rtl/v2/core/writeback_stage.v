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

module writeback_stage(
	input                          clk,
	input                          reset,

	// From single cycle execute stage...
	input                         sc_instruction_valid,
	input decoded_instruction_t   sc_instruction,
	input vector_t                sc_result,
	input thread_idx_t            sc_thread_idx,
	input [`VECTOR_LANES - 1:0]   sc_mask_value,
	input logic                   sc_rollback_en,
	input thread_idx_t            sc_rollback_thread_idx,
	input scalar_t                sc_rollback_pc,
	
	// From dcache data stage
	input                         dd_instruction_valid,
	input decoded_instruction_t   dd_instruction,
	input [`VECTOR_LANES - 1:0]   dd_mask_value,
	input thread_idx_t            dd_thread_idx,
	input scalar_t                dd_request_addr,

	// Rollback signals to all stages
	output logic                  wb_rollback_en,
	output thread_idx_t           wb_rollback_thread_idx,
	output scalar_t               wb_rollback_pc,
	output pipeline_sel_t         wb_rollback_pipeline,
	output subcycle_t             wb_rollback_subcycle,

	// To operand fetch/thread select stages
	output logic                  wb_en,
	output thread_idx_t           wb_thread_idx,
	output logic                  wb_is_vector,
	output vector_t               wb_value,
	output [`VECTOR_LANES - 1:0]  wb_mask,
	output register_idx_t         wb_reg,
	
	// XXX placeholder
	input [`CACHE_LINE_BITS - 1:0]  SIM_dcache_read_data);

	vector_t mem_load_result;
	scalar_t mem_load_lane;
	logic[7:0] byte_aligned;
	logic[15:0] half_aligned;
	fmtc_op_t memory_op;
	logic[`CACHE_LINE_BITS - 1:0] endian_twiddled_data;
	scalar_t aligned_read_value;
	scalar_t debug_wb_pc;	// Used by testbench
	logic[`VECTOR_LANES - 1:0] int_vcompare_result;
 	
	// This must not be registered because the next instruction may be a memory store
	// and we don't want it to apply its side effects. Rollbacks are asserted from
	// the writeback stage so there can only be one active at a time.
	always_comb
	begin
		wb_rollback_en = 0;
		wb_rollback_thread_idx = 0;
		wb_rollback_pc = 0;
		wb_rollback_pipeline = PIPE_SCYCLE_ARITH;
		wb_rollback_subcycle = 0;	// XXX this needs to come from execute units
	
		if (sc_instruction_valid && sc_instruction.has_dest && sc_instruction.dest_reg == `REG_PC)
		begin
			// Special case: instruction with PC destination (this can also come from memory stage)
			wb_rollback_en = 1'b1;
			wb_rollback_pc = sc_result[0];	
			wb_rollback_thread_idx = sc_rollback_thread_idx;
			wb_rollback_pipeline = PIPE_SCYCLE_ARITH;
		end
		else if (sc_instruction_valid)
		begin
			wb_rollback_en = sc_rollback_en;
			wb_rollback_thread_idx = sc_rollback_thread_idx;
			wb_rollback_pc = sc_rollback_pc;
			wb_rollback_pipeline = PIPE_SCYCLE_ARITH;
		end
	end

	localparam CACHE_LINE_WORDS = `CACHE_LINE_BYTES / 4;
	localparam CACHE_LINE_WORD_IDX_BITS = $clog2(CACHE_LINE_WORDS);

	assign memory_op = dd_instruction.memory_access_type;
	assign mem_load_lane = SIM_dcache_read_data[(CACHE_LINE_WORDS - 1 - dd_request_addr[2+:CACHE_LINE_WORD_IDX_BITS]) * 32+:32];

	// Byte aligner.
	always_comb
	begin
		case (dd_request_addr[1:0])
			2'b00: byte_aligned = mem_load_lane[31:24];
			2'b01: byte_aligned = mem_load_lane[23:16];
			2'b10: byte_aligned = mem_load_lane[15:8];
			2'b11: byte_aligned = mem_load_lane[7:0];
		endcase
	end

	// Halfword aligner.
	always_comb
	begin
		case (dd_request_addr[1])
			1'b0: half_aligned = { mem_load_lane[23:16], mem_load_lane[31:24] };
			1'b1: half_aligned = { mem_load_lane[7:0], mem_load_lane[15:8] };
		endcase
	end

	// Pick the proper aligned result and sign extend as requested.
	always_comb
	begin
		case (memory_op)		// Load width
			// Unsigned byte
			MEM_B: aligned_read_value = { 24'b0, byte_aligned };	

			// Signed byte
			MEM_BX: aligned_read_value = { {24{byte_aligned[7]}}, byte_aligned }; 

			// Unsigned half-word
			MEM_S: aligned_read_value = { 16'b0, half_aligned };

			// Signed half-word
			MEM_SX: aligned_read_value = { {16{half_aligned[15]}}, half_aligned };

			// Word (100) and others
			default: aligned_read_value = { mem_load_lane[7:0], mem_load_lane[15:8],
				mem_load_lane[23:16], mem_load_lane[31:24] };	
		endcase
	end

	// Endian swap vector data
	genvar swap_word;
	generate
		for (swap_word = 0; swap_word < `CACHE_LINE_BYTES / 4; swap_word++)
		begin : swapper
			assign endian_twiddled_data[swap_word * 32+:8] = SIM_dcache_read_data[swap_word * 32 + 24+:8];
			assign endian_twiddled_data[swap_word * 32 + 8+:8] = SIM_dcache_read_data[swap_word * 32 + 16+:8];
			assign endian_twiddled_data[swap_word * 32 + 16+:8] = SIM_dcache_read_data[swap_word * 32 + 8+:8];
			assign endian_twiddled_data[swap_word * 32 + 24+:8] = SIM_dcache_read_data[swap_word * 32+:8];
		end
	endgenerate

	// Hook up vector compare mask
	genvar mask_lane;
	generate
		for (mask_lane = 0; mask_lane < `VECTOR_LANES; mask_lane++)
		begin : collect_lane
			assign int_vcompare_result[mask_lane] = sc_result[mask_lane][0];
		end
	endgenerate

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			debug_wb_pc <= 1'h0;
			wb_en <= 1'h0;
			wb_is_vector <= 1'h0;
			wb_mask <= {(1+(`VECTOR_LANES-1)){1'b0}};
			wb_reg <= 1'h0;
			wb_thread_idx <= 1'h0;
			wb_value <= 1'h0;
			// End of automatics
		end
		else
		begin
			assert($onehot0({(sc_instruction_valid && sc_instruction.has_dest), (dd_instruction_valid
				&& dd_instruction.has_dest)}));
		
			// Writeback signals (currently hardcoded to only pull from single cycle execute stage)
			if (sc_instruction_valid)
			begin
				wb_en <= sc_instruction.has_dest && !wb_rollback_en;
				wb_thread_idx <= sc_thread_idx;
				wb_is_vector <= sc_instruction.dest_is_vector;
				if (sc_instruction.is_vector_compare)
					wb_value <= int_vcompare_result;
				else
					wb_value <= sc_result;
					
				wb_mask <= sc_mask_value;
				wb_reg <= sc_instruction.dest_reg;
				debug_wb_pc <= sc_instruction.pc;
			end
			else if (dd_instruction_valid)
			begin
				wb_en <= dd_instruction.has_dest && !wb_rollback_en;
				wb_thread_idx <= dd_thread_idx;
				wb_is_vector <= dd_instruction.dest_is_vector;
				wb_reg <= dd_instruction.dest_reg;
				
				// Loads should always have a destination register.
				assert(dd_instruction.has_dest || !(dd_instruction.is_memory_access && dd_instruction.is_load));

				if (dd_instruction.is_load)
				begin
					if (memory_op == MEM_B || memory_op == MEM_BX || memory_op == MEM_S
						|| memory_op == MEM_SX || memory_op == MEM_SYNC || memory_op == MEM_CONTROL_REG
						|| memory_op == MEM_L)
					begin
						// Scalar Load
						wb_value <= {`VECTOR_LANES{aligned_read_value}}; 
						wb_mask <= {`VECTOR_LANES{1'b1}};
						assert(!dd_instruction.dest_is_vector);
					end
					else if (memory_op == MEM_BLOCK || memory_op == MEM_BLOCK_M
							|| memory_op == MEM_BLOCK_IM)
					begin
						// Block load
						wb_mask <= dd_mask_value;	
						wb_value <= endian_twiddled_data;
						assert(dd_instruction.dest_is_vector);
					end
					else
						assert(0);	// Unknown transfer type
				end
				
				// XXX strided load not supported yet

				debug_wb_pc <= dd_instruction.pc;
`ifdef ENABLE_TRACE
				if (wb_rollback_en)
					$display("%08x thread %d roll back to %08x", dd_instruction.pc, wb_thread_idx, wb_rollback_pc);
`endif
			end
			else
				wb_en <= 0;

`ifdef ENABLE_TRACE
			if (wb_en)
			begin
				if (wb_is_vector)
					$display("%08x (%d) v%d{%b} <= %x", debug_wb_pc, wb_thread_idx, wb_mask, wb_reg, wb_value);
				else
					$display("%08x (%d) s%d <= %x", debug_wb_pc, wb_thread_idx, wb_reg, wb_value[0]);
			end
`endif
		end
	end	
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
