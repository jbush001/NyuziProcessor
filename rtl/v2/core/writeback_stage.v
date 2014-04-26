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

	// From single cycle execute stage
	input                         sc_instruction_valid,
	input decoded_instruction_t   sc_instruction,
	input vector_t                sc_result,
	input thread_idx_t            sc_thread_idx,
	input [`VECTOR_LANES - 1:0]   sc_mask_value,
	input logic                   sc_rollback_en,
	input thread_idx_t            sc_rollback_thread_idx,
	input scalar_t                sc_rollback_pc,
	input subcycle_t              sc_subcycle,
	
	// From dcache data stage 
	input                         dd_instruction_valid,
	input decoded_instruction_t   dd_instruction,
	input [`VECTOR_LANES - 1:0]   dd_mask_value,
	input thread_idx_t            dd_thread_idx,
	input scalar_t                dd_request_addr,
	input subcycle_t              dd_subcycle,
	
	// From control registers
	input scalar_t                cr_creg_read_val,

	// Rollback signals to all stages
	output logic                  wb_rollback_en,
	output thread_idx_t           wb_rollback_thread_idx,
	output scalar_t               wb_rollback_pc,
	output pipeline_sel_t         wb_rollback_pipeline,
	output subcycle_t             wb_rollback_subcycle,
	output logic                  wb_rollback_is_last_subcycle,

	// To operand fetch/thread select stages
	output logic                  wb_writeback_en,
	output thread_idx_t           wb_writeback_thread_idx,
	output logic                  wb_is_vector,
	output vector_t               wb_writeback_value,
	output [`VECTOR_LANES - 1:0]  wb_writeback_mask,
	output register_idx_t         wb_writeback_reg,
	
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
		wb_rollback_subcycle = 0;
		wb_rollback_is_last_subcycle = 0;

		if (sc_instruction_valid && sc_instruction.has_dest && sc_instruction.dest_reg == `REG_PC)
		begin
			// Special case: instruction with PC destination (this can also come from memory stage)
			wb_rollback_en = 1'b1;
			wb_rollback_pc = sc_result[0];	
			wb_rollback_thread_idx = sc_rollback_thread_idx;
			wb_rollback_pipeline = PIPE_SCYCLE_ARITH;
			wb_rollback_is_last_subcycle = sc_subcycle == sc_instruction.last_subcycle;
		end
		else if (sc_instruction_valid)
		begin
			wb_rollback_en = sc_rollback_en;
			wb_rollback_thread_idx = sc_rollback_thread_idx;
			wb_rollback_pc = sc_rollback_pc;
			wb_rollback_pipeline = PIPE_SCYCLE_ARITH;
			wb_rollback_subcycle = dd_subcycle;
			wb_rollback_is_last_subcycle = dd_subcycle == dd_instruction.last_subcycle;
		end
		
		// XXX memory pipeline rollback goes here.
		
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
			wb_is_vector <= 1'h0;
			wb_writeback_en <= 1'h0;
			wb_writeback_mask <= {(1+(`VECTOR_LANES-1)){1'b0}};
			wb_writeback_reg <= 1'h0;
			wb_writeback_thread_idx <= 1'h0;
			wb_writeback_value <= 1'h0;
			// End of automatics
		end
		else
		begin
			assert($onehot0({(sc_instruction_valid && sc_instruction.has_dest), (dd_instruction_valid
				&& dd_instruction.has_dest)}));
		
			if (sc_instruction_valid)
			begin
				//
				// Single cycle pipeline result
				//
				if (sc_instruction.is_branch && (sc_instruction.branch_type == BRANCH_CALL_OFFSET
					|| sc_instruction.branch_type == BRANCH_CALL_REGISTER))
					wb_writeback_en <= 1;	// Call is a special case: it both rolls back and writes back a register (link)
				else if (sc_instruction.has_dest && !wb_rollback_en)
					wb_writeback_en <= 1;	// This is a normal, non-rolled-back instruction
				else
					wb_writeback_en <= 0;

				wb_writeback_thread_idx <= sc_thread_idx;
				wb_is_vector <= sc_instruction.dest_is_vector;
				if (sc_instruction.is_compare)
					wb_writeback_value <= int_vcompare_result;
				else
					wb_writeback_value <= sc_result;
					
				wb_writeback_mask <= sc_mask_value;
				wb_writeback_reg <= sc_instruction.dest_reg;
				debug_wb_pc <= sc_instruction.pc;
			end
			else if (dd_instruction_valid)
			begin
				//
				// Memory pipeline result
				//
				wb_writeback_en <= dd_instruction.has_dest && !wb_rollback_en;
				wb_writeback_thread_idx <= dd_thread_idx;
				wb_is_vector <= dd_instruction.dest_is_vector;
				wb_writeback_reg <= dd_instruction.dest_reg;
				
				// Loads should always have a destination register.
				assert(dd_instruction.has_dest || !(dd_instruction.is_memory_access && dd_instruction.is_load));

				if (dd_instruction.is_load)
				begin
					unique case (memory_op)
						MEM_B,
						MEM_BX,
						MEM_S,
						MEM_SX,
						MEM_SYNC,
						MEM_L:
						begin
							// Scalar Load
							wb_writeback_value <= {`VECTOR_LANES{aligned_read_value}}; 
							wb_writeback_mask <= {`VECTOR_LANES{1'b1}};
							assert(!dd_instruction.dest_is_vector);
						end
						
						MEM_CONTROL_REG:
						begin
							wb_writeback_value <= {`VECTOR_LANES{cr_creg_read_val}}; 
							wb_writeback_mask <= {`VECTOR_LANES{1'b1}};
							assert(!dd_instruction.dest_is_vector);
						end
						
						MEM_BLOCK,
						MEM_BLOCK_M,
						MEM_BLOCK_IM:
						begin
							// Block load
							wb_writeback_mask <= dd_mask_value;	
							wb_writeback_value <= endian_twiddled_data;
							assert(dd_instruction.dest_is_vector);
						end
						
						default:
						begin
							// Strided or gather load
							// Grab the appropriate lane.
							wb_writeback_value <= {`VECTOR_LANES{aligned_read_value}};
							wb_writeback_mask <= (16'h8000 >> dd_subcycle) & dd_mask_value;	
						end
					endcase
				end
				
				// XXX strided load not supported yet

				debug_wb_pc <= dd_instruction.pc;
			end
			else
				wb_writeback_en <= 0;
		end
	end	
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
