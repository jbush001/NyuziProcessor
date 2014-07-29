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
// Instruction Pipeline Writeback Stage
// Controls signals to write results back to register file
// - Selects result from appropriate pipeline.
// - Aligns memory read results
// - Detects and flags rollbacks, which can occur as a result of:
//   * Branch
//   * Data cache miss
//   * Exception
//

module writeback_stage(
	input                            clk,
	input                            reset,

	// From last multi-cycle execute stage
	input                            mx5_instruction_valid,
	input decoded_instruction_t      mx5_instruction,
	input vector_t                   mx5_result,
	input [`VECTOR_LANES - 1:0]      mx5_mask_value,
	input thread_idx_t               mx5_thread_idx,
	input subcycle_t                 mx5_subcycle,

	// From single-cycle execute stage
	input                            sx_instruction_valid,
	input decoded_instruction_t      sx_instruction,
	input vector_t                   sx_result,
	input thread_idx_t               sx_thread_idx,
	input [`VECTOR_LANES - 1:0]      sx_mask_value,
	input logic                      sx_rollback_en,
	input scalar_t                   sx_rollback_pc,
	input subcycle_t                 sx_subcycle,
	                               
	// From dcache data stage      
	input                            dd_instruction_valid,
	input decoded_instruction_t      dd_instruction,
	input [`VECTOR_LANES - 1:0]      dd_lane_mask,
	input thread_idx_t               dd_thread_idx,
	input l1d_addr_t                 dd_request_addr,
	input subcycle_t                 dd_subcycle,
	input                            dd_rollback_en,
	input scalar_t                   dd_rollback_pc,
	input [`CACHE_LINE_BITS - 1:0]   dd_load_data,
	
	// From store buffer
	input [`CACHE_LINE_BYTES - 1:0]  sb_store_bypass_mask,
	input [`CACHE_LINE_BITS - 1:0]   sb_store_bypass_data,
	input                            sb_store_sync_success,
	input                            sb_full_rollback,
	
	// From control registers
	input scalar_t                   cr_creg_read_val,
	
	// To control registers
	output                           wb_fault,
	output fault_reason_t            wb_fault_reason,
	output scalar_t                  wb_fault_address,

	// Rollback signals to all stages
	output logic                     wb_rollback_en,
	output thread_idx_t              wb_rollback_thread_idx,
	output scalar_t                  wb_rollback_pc,
	output pipeline_sel_t            wb_rollback_pipeline,
	output subcycle_t                wb_rollback_subcycle,

	// To operand fetch/thread select stages
	output logic                     wb_writeback_en,
	output thread_idx_t              wb_writeback_thread_idx,
	output logic                     wb_writeback_is_vector,
	output vector_t                  wb_writeback_value,
	output [`VECTOR_LANES - 1:0]     wb_writeback_mask,
	output register_idx_t            wb_writeback_reg,
	output logic                     wb_writeback_is_last_subcycle,
	
	// Performance counters
	output logic                     perf_instruction_retire,
	output logic                     perf_store_rollback);

	vector_t mem_load_result;
	scalar_t mem_load_lane;
	logic[7:0] byte_aligned;
	logic[15:0] half_aligned;
	fmtc_op_t memory_op;
	logic[`CACHE_LINE_BITS - 1:0] endian_twiddled_data;
	scalar_t aligned_read_value;
	scalar_t __debug_wb_pc;	// Used by testbench
	pipeline_sel_t __debug_wb_pipeline;
	logic __debug_is_sync_store;
	logic[`VECTOR_LANES - 1:0] scycle_vcompare_result;
	logic[`VECTOR_LANES - 1:0] mcycle_vcompare_result;
	logic[`VECTOR_LANES - 1:0] dd_vector_lane_oh;
	logic[`CACHE_LINE_BITS - 1:0] bypassed_read_data;
 	
	assign perf_instruction_retire = mx5_instruction_valid || sx_instruction_valid || dd_instruction_valid;
	assign perf_store_rollback = sb_full_rollback;
	
	//
	// Rollback control logic
	//
	// These signals are not registered because the next instruction may be a memory store 
	// and we must squash it before it applies its side effects. All rollbacks are handled 
	// here so there can be only one asserted at a time.
	//
	always_comb
	begin
		wb_rollback_en = 0;
		wb_rollback_thread_idx = 0;
		wb_rollback_pc = 0;
		wb_rollback_pipeline = PIPE_SCYCLE_ARITH;
		wb_rollback_subcycle = 0;
		wb_fault = 0;
		wb_fault_reason = FR_NONE;
		wb_fault_address = 0;

		if (sx_instruction_valid && sx_instruction.illegal)
		begin
			// Illegal instruction fault
			wb_rollback_en = 1'b1;
			wb_rollback_pc = 32'd4;
			wb_rollback_thread_idx = sx_thread_idx;
			wb_rollback_pipeline = PIPE_SCYCLE_ARITH;
			wb_fault = 1;
			wb_fault_reason = FR_ILLEGAL_INSTRUCTION;
			wb_fault_address = sx_instruction.pc;
		end
		else if (sx_instruction_valid && sx_instruction.has_dest && sx_instruction.dest_reg == `REG_PC
			&& !sx_instruction.dest_is_vector)
		begin
			// Special case: arithmetic with PC destination 
			wb_rollback_en = 1'b1;
			wb_rollback_pc = sx_result[0];	
			wb_rollback_thread_idx = sx_thread_idx;
			wb_rollback_pipeline = PIPE_SCYCLE_ARITH;
		end
		else if (dd_instruction_valid && dd_instruction.has_dest && dd_instruction.dest_reg == `REG_PC
			&& !dd_instruction.dest_is_vector && !dd_rollback_en)
		begin
			// Special case: memory load with PC destination.  Note that we check dd_rollback_en to
			// ensure this wasn't a cache miss (if it was, we handle it in a case below)
			wb_rollback_en = 1'b1;
			wb_rollback_pc = aligned_read_value;	
			wb_rollback_thread_idx = dd_thread_idx;
			wb_rollback_pipeline = PIPE_MEM;
			assert(dd_subcycle == dd_instruction.last_subcycle);
		end
		else if (sx_instruction_valid)
		begin
			wb_rollback_en = sx_rollback_en;
			wb_rollback_thread_idx = sx_thread_idx;
			wb_rollback_pc = sx_rollback_pc;
			wb_rollback_pipeline = PIPE_SCYCLE_ARITH;
			wb_rollback_subcycle = sx_subcycle;
		end
		else if (dd_instruction_valid)
		begin
			wb_rollback_en = dd_rollback_en || sb_full_rollback;
			wb_rollback_thread_idx = dd_thread_idx;
			wb_rollback_pc = dd_rollback_pc;
			wb_rollback_pipeline = PIPE_MEM;
			wb_rollback_subcycle = dd_subcycle;
		end
	end

	// If there are pending stores that have not yet been acknowledged and been updated
	// to the L1 cache, apply those now.
	genvar byte_lane;
	generate
		for (byte_lane = 0; byte_lane < `CACHE_LINE_BYTES; byte_lane++)
		begin : lane_bypass_gen
			assign bypassed_read_data[byte_lane * 8+:8] = sb_store_bypass_mask[byte_lane]
				? sb_store_bypass_data[byte_lane * 8+:8] : dd_load_data[byte_lane * 8+:8];
		end
	endgenerate

	assign memory_op = dd_instruction.memory_access_type;
	assign mem_load_lane = bypassed_read_data[(`CACHE_LINE_WORDS - 1 - dd_request_addr.offset[2+:`CACHE_LINE_OFFSET_WIDTH - 2]) * 32+:32];

	// Byte aligner.
	always_comb
	begin
		case (dd_request_addr.offset[1:0])
			2'b00: byte_aligned = mem_load_lane[31:24];
			2'b01: byte_aligned = mem_load_lane[23:16];
			2'b10: byte_aligned = mem_load_lane[15:8];
			2'b11: byte_aligned = mem_load_lane[7:0];
		endcase
	end

	// Halfword aligner.
	always_comb
	begin
		case (dd_request_addr.offset[1])
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
		begin : swap_word_gen
			assign endian_twiddled_data[swap_word * 32+:8] = bypassed_read_data[swap_word * 32 + 24+:8];
			assign endian_twiddled_data[swap_word * 32 + 8+:8] = bypassed_read_data[swap_word * 32 + 16+:8];
			assign endian_twiddled_data[swap_word * 32 + 16+:8] = bypassed_read_data[swap_word * 32 + 8+:8];
			assign endian_twiddled_data[swap_word * 32 + 24+:8] = bypassed_read_data[swap_word * 32+:8];
		end
	endgenerate

	// Compress vector comparisons to one bit per lane.
	genvar mask_lane;
	generate
		for (mask_lane = 0; mask_lane < `VECTOR_LANES; mask_lane++)
		begin : compare_result_gen
			assign scycle_vcompare_result[mask_lane] = sx_result[mask_lane][0];
			assign mcycle_vcompare_result[mask_lane] = mx5_result[mask_lane][0];
		end
	endgenerate

	idx_to_oh #(.NUM_SIGNALS(`VECTOR_LANES), .DIRECTION("MSB0")) convert_dd_lane(
		.one_hot(dd_vector_lane_oh),
		.index(dd_subcycle));

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			__debug_wb_pipeline <= PIPE_MEM;

			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			__debug_is_sync_store <= 1'h0;
			__debug_wb_pc <= 1'h0;
			wb_writeback_en <= 1'h0;
			wb_writeback_is_last_subcycle <= 1'h0;
			wb_writeback_is_vector <= 1'h0;
			wb_writeback_mask <= {(1+(`VECTOR_LANES-1)){1'b0}};
			wb_writeback_reg <= 1'h0;
			wb_writeback_thread_idx <= 1'h0;
			wb_writeback_value <= 1'h0;
			// End of automatics
		end
		else
		begin
			assert($onehot0({sx_instruction_valid, dd_instruction_valid, mx5_instruction_valid}));
		
			__debug_is_sync_store <= dd_instruction_valid && !dd_instruction.is_load
				&& memory_op == MEM_SYNC;
		
			// Note about usage of wb_rollback_en here: it is derived combinatorially
			// from the instruction that is about to be retired, so wb_rollback_thread_idx
			// doesn't need to be checked like in other places.
			unique case ({ mx5_instruction_valid, sx_instruction_valid, dd_instruction_valid })
				//
				// Multi-cycle pipeline result
				//
				3'b100:
				begin
					if (mx5_instruction.has_dest && !wb_rollback_en)
						wb_writeback_en <= 1;
					else
						wb_writeback_en <= 0;

					wb_writeback_thread_idx <= mx5_thread_idx;
					wb_writeback_is_vector <= mx5_instruction.dest_is_vector;
					if (mx5_instruction.is_compare)
						wb_writeback_value <= mcycle_vcompare_result;	// XXX need to combine compare values
					else
						wb_writeback_value <= mx5_result;
					
					wb_writeback_mask <= mx5_mask_value;
					wb_writeback_reg <= mx5_instruction.dest_reg;
					wb_writeback_is_last_subcycle <= mx5_subcycle == mx5_instruction.last_subcycle;

					// Used by testbench for cosimulation output
					__debug_wb_pc <= mx5_instruction.pc;
					__debug_wb_pipeline <= PIPE_MCYCLE_ARITH;
				end

				//
				// Single cycle pipeline result
				//
				3'b010:
				begin
					if (sx_instruction.is_branch && (sx_instruction.branch_type == BRANCH_CALL_OFFSET
						|| sx_instruction.branch_type == BRANCH_CALL_REGISTER))
					begin
						// Call is a special case: it both rolls back and writes back a register (link)
						wb_writeback_en <= 1;	
					end
					else if (sx_instruction.has_dest && !wb_rollback_en)
						wb_writeback_en <= 1;	// This is a normal, non-rolled-back instruction
					else
						wb_writeback_en <= 0;

					wb_writeback_thread_idx <= sx_thread_idx;
					wb_writeback_is_vector <= sx_instruction.dest_is_vector;
					if (sx_instruction.is_compare)
						wb_writeback_value <= scycle_vcompare_result;
					else
						wb_writeback_value <= sx_result;
					
					wb_writeback_mask <= sx_mask_value;
					wb_writeback_reg <= sx_instruction.dest_reg;
					wb_writeback_is_last_subcycle <= sx_subcycle == sx_instruction.last_subcycle;

					// Used by testbench for cosimulation output
					__debug_wb_pc <= sx_instruction.pc;
					__debug_wb_pipeline <= PIPE_SCYCLE_ARITH;
				end
				
				//
				// Memory pipeline result
				//
				3'b001:
				begin
					wb_writeback_en <= dd_instruction.has_dest && !wb_rollback_en;
					wb_writeback_thread_idx <= dd_thread_idx;
					wb_writeback_is_vector <= dd_instruction.dest_is_vector;
					wb_writeback_reg <= dd_instruction.dest_reg;
					wb_writeback_is_last_subcycle <= dd_subcycle == dd_instruction.last_subcycle;
				
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
							MEM_BLOCK_M:
							begin
								// Block load
								wb_writeback_mask <= dd_lane_mask;	
								wb_writeback_value <= endian_twiddled_data;
								assert(dd_instruction.dest_is_vector);
							end
						
							default:
							begin
								// gather load
								// Grab the appropriate lane.
								wb_writeback_value <= {`VECTOR_LANES{aligned_read_value}};
								wb_writeback_mask <= dd_vector_lane_oh & dd_lane_mask;	
							end
						endcase
					end
					else if (dd_instruction.memory_access_type == MEM_SYNC)
					begin
						// Synchronized stores are special in that they write back (whether they
						// were successful).
						assert(dd_instruction.has_dest && !dd_instruction.dest_is_vector)
						wb_writeback_value[0] <= sb_store_sync_success;
					end

					// Used by testbench for cosimulation output
					__debug_wb_pc <= dd_instruction.pc;
					__debug_wb_pipeline <= PIPE_MEM;
				end
				
				3'b000: wb_writeback_en <= 0;
			endcase
		end
	end	
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
