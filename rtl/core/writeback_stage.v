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
// - Controls signals to write results back to register file
// - Selects result from appropriate pipeline.
// - Aligns memory read results
// - Flag rolbacks.  They are generally detected earlier in the pipeline, 
//   but we wait to handle them here because there is logic earlier in the
//   pipeline to ensure only one instruction arrives per cycle.  Because
//   there are pipelines of different lengths, multiple rollbacks can be
//   flagged in the same cycle, and the logic would be slower to resolve them.
//   * Branch
//   * Data cache miss
//   * Exception
//
// Exceptions and interrupts are precise in this architecture.
// Instructions may be retired out of order because the execution pipelines have different
// lengths. Also, it's possible, after a rollback, for earlier instructions from the same
// thread to arrive at this stage for several cycles (because they were in the longer floating
// point pipeline). The rollback signal does not flush later stages of the multicycle
// pipeline for this reason. This can be challenging to visualize.
//

module writeback_stage(
	input                                 clk,
	input                                 reset,

	// From last multi-cycle execute stage
	input                                 mx5_instruction_valid,
	input decoded_instruction_t           mx5_instruction,
	input vector_t                        mx5_result,
	input vector_lane_mask_t              mx5_mask_value,
	input thread_idx_t                    mx5_thread_idx,
	input subcycle_t                      mx5_subcycle,

	// From single-cycle execute stage
	input                                 sx_instruction_valid,
	input decoded_instruction_t           sx_instruction,
	input vector_t                        sx_result,
	input thread_idx_t                    sx_thread_idx,
	input vector_lane_mask_t              sx_mask_value,
	input logic                           sx_rollback_en,
	input scalar_t                        sx_rollback_pc,
	input subcycle_t                      sx_subcycle,
	                               
	// From dcache data stage      
	input                                 dd_instruction_valid,
	input decoded_instruction_t           dd_instruction,
	input vector_lane_mask_t              dd_lane_mask,
	input thread_idx_t                    dd_thread_idx,
	input l1d_addr_t                      dd_request_addr,
	input subcycle_t                      dd_subcycle,
	input                                 dd_rollback_en,
	input scalar_t                        dd_rollback_pc,
	input cache_line_data_t               dd_load_data,
	input                                 dd_suspend_thread,
	input                                 dd_is_io_address,
	input                                 dd_access_fault,
	
	// From store queue
	input [`CACHE_LINE_BYTES - 1:0]       sq_store_bypass_mask,
	input cache_line_data_t               sq_store_bypass_data,
	input                                 sq_store_sync_success,
	input                                 sq_rollback_en,

	// From io_request_queue
	input scalar_t                        ior_read_value,
	input logic                           ior_rollback_en,
	
	// From control registers
	input scalar_t                        cr_creg_read_val,
	input thread_bitmap_t                 cr_interrupt_en,
	input scalar_t                        cr_fault_handler,
	
	// To control registers
	output                                wb_fault,
	output fault_reason_t                 wb_fault_reason,
	output scalar_t                       wb_fault_pc,
	output thread_idx_t                   wb_fault_thread_idx,
	output scalar_t                       wb_fault_access_addr,

	// Interrupt input
	input                                 interrupt_pending,
	input thread_idx_t                    interrupt_thread_idx,
	output logic                          wb_interrupt_ack,

	// Rollback signals to all stages
	output logic                          wb_rollback_en,
	output thread_idx_t                   wb_rollback_thread_idx,
	output scalar_t                       wb_rollback_pc,
	output pipeline_sel_t                 wb_rollback_pipeline,
	output subcycle_t                     wb_rollback_subcycle,

	// To operand fetch/thread select stages
	output logic                          wb_writeback_en,
	output thread_idx_t                   wb_writeback_thread_idx,
	output logic                          wb_writeback_is_vector,
	output vector_t                       wb_writeback_value,
	output vector_lane_mask_t             wb_writeback_mask,
	output register_idx_t                 wb_writeback_reg,
	output logic                          wb_writeback_is_last_subcycle,

	// To thread select
	output thread_bitmap_t                wb_suspend_thread_oh,
	
	// Performance counters
	output logic                          perf_instruction_retire,
	output logic                          perf_store_rollback);

	vector_t mem_load_result;
	scalar_t mem_load_lane;
	logic[7:0] byte_aligned;
	logic[15:0] half_aligned;
	fmtc_op_t memory_op;
	cache_line_data_t endian_twiddled_data;
	scalar_t aligned_read_value;
	scalar_t __debug_wb_pc;	// Used by testbench
	pipeline_sel_t __debug_wb_pipeline;
	logic __debug_is_sync_store;
	logic[`VECTOR_LANES - 1:0] scycle_vcompare_result;
	logic[`VECTOR_LANES - 1:0] mcycle_vcompare_result;
	vector_lane_mask_t dd_vector_lane_oh;
	cache_line_data_t bypassed_read_data;
	thread_bitmap_t thread_oh;
	scalar_t last_retire_pc[`THREADS_PER_CORE];
	logic multi_issue_pending[`THREADS_PER_CORE];
 	logic is_last_subcycle_dd;
	logic is_last_subcycle_sx;
	logic is_last_subcycle_mx;
	logic[4:0] writeback_counter;
 	
	assign perf_instruction_retire = mx5_instruction_valid || sx_instruction_valid || dd_instruction_valid;
	assign perf_store_rollback = sq_rollback_en;

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
		wb_fault_reason = FR_RESET;
		wb_fault_pc = 0;
		wb_fault_thread_idx = 0;
		wb_interrupt_ack = 0;
		wb_fault_access_addr = 0;

		if (sx_instruction_valid && sx_instruction.illegal)
		begin
			// Illegal instruction fault
			wb_rollback_en = 1'b1;
			wb_rollback_pc = cr_fault_handler;
			wb_rollback_thread_idx = sx_thread_idx;
			wb_rollback_pipeline = PIPE_SCYCLE_ARITH;
			wb_fault = 1;
			wb_fault_reason = FR_ILLEGAL_INSTRUCTION;
			wb_fault_pc = sx_instruction.pc;
			wb_fault_thread_idx = sx_thread_idx;
		end
		else if (dd_instruction_valid && dd_access_fault)
		begin
			// Memory access fault
			wb_rollback_en = 1'b1;
			wb_rollback_pc = cr_fault_handler;
			wb_rollback_thread_idx = dd_thread_idx;
			wb_rollback_pipeline = PIPE_MEM;
			wb_fault = 1;
			wb_fault_reason = FR_INVALID_ACCESS;
			wb_fault_pc = dd_instruction.pc;
			wb_fault_thread_idx = dd_thread_idx;
			wb_fault_access_addr = dd_request_addr;
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
			
			// Cannot have multi-cycle load with a PC load.
			assert(dd_subcycle == dd_instruction.last_subcycle);
		end
		else if (sx_instruction_valid && sx_rollback_en)
		begin
			// Check for rollback from single cycle pipeline.  This happens
			// because of a branch.
			wb_rollback_en = 1;
			wb_rollback_thread_idx = sx_thread_idx;
			wb_rollback_pc = sx_rollback_pc;
			wb_rollback_pipeline = PIPE_SCYCLE_ARITH;
			wb_rollback_subcycle = sx_subcycle;
		end
		else if (dd_instruction_valid && (dd_rollback_en || sq_rollback_en || ior_rollback_en))
		begin
			// Check for rollback from memory pipeline.  This happens because
			// of a data cache miss, store queue full, or when an IO request
			// is sent.
			wb_rollback_en = 1;
			wb_rollback_thread_idx = dd_thread_idx;
			wb_rollback_pc = dd_rollback_pc;
			wb_rollback_pipeline = PIPE_MEM;
			wb_rollback_subcycle = dd_subcycle;
		end
		else if (interrupt_pending 
			&& cr_interrupt_en[interrupt_thread_idx] 
			&& !multi_issue_pending[interrupt_thread_idx]
			&& !(dd_instruction_valid || dd_thread_idx == interrupt_thread_idx)
			&& !(sx_instruction_valid || sx_thread_idx == interrupt_thread_idx)
			&& !(mx5_instruction_valid || mx5_thread_idx == interrupt_thread_idx))
		begin	
			// Note that we don't flag an interrupt in the same cycle as another type of rollback.
			// We also won't interrupt in the middle of a multi-issue instruction (like gather load)
			// because that will cause incorrect behavior if the destination register is also one of the
			// source operands.
			wb_rollback_en = 1;
			wb_rollback_thread_idx = interrupt_thread_idx;
			wb_rollback_pc = cr_fault_handler;	
			wb_rollback_pipeline = PIPE_MEM; 
			wb_rollback_subcycle = 0;
			wb_fault = 1;
			wb_fault_pc = last_retire_pc[interrupt_thread_idx] + 4;
			wb_fault_reason = FR_INTERRUPT;
			wb_fault_thread_idx = interrupt_thread_idx;
			wb_interrupt_ack = 1;
		end
	end

	idx_to_oh #(.NUM_SIGNALS(`THREADS_PER_CORE), .DIRECTION("LSB0")) idx_to_oh_thread(
		.one_hot(thread_oh),
		.index(dd_thread_idx));

	// Suspend thread if necessary
	assign wb_suspend_thread_oh = (dd_suspend_thread || sq_rollback_en || ior_rollback_en) 
		? thread_oh : 0;

	// If there are pending stores that have not yet been acknowledged and been updated
	// to the L1 cache, apply those now.
	genvar byte_lane;
	generate
		for (byte_lane = 0; byte_lane < `CACHE_LINE_BYTES; byte_lane++)
		begin : lane_bypass_gen
			assign bypassed_read_data[byte_lane * 8+:8] = sq_store_bypass_mask[byte_lane]
				? sq_store_bypass_data[byte_lane * 8+:8] : dd_load_data[byte_lane * 8+:8];
		end
	endgenerate

	assign memory_op = dd_instruction.memory_access_type;
	assign mem_load_lane = bypassed_read_data[~dd_request_addr.offset[2+:`CACHE_LINE_OFFSET_WIDTH - 2] * 32+:32];

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

 	assign is_last_subcycle_dd = dd_subcycle == dd_instruction.last_subcycle;
	assign is_last_subcycle_sx = sx_subcycle == sx_instruction.last_subcycle;
	assign is_last_subcycle_mx = mx5_subcycle == mx5_instruction.last_subcycle;

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			__debug_wb_pipeline <= PIPE_MEM;
			for (int i = 0; i < `THREADS_PER_CORE; i++)
			begin
				last_retire_pc[i] <= 0;
				multi_issue_pending[i] <= 0;
			end
			
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			__debug_is_sync_store <= 1'h0;
			__debug_wb_pc <= 1'h0;
			__debug_wb_pipeline <= 1'h0;
			wb_writeback_en <= 1'h0;
			wb_writeback_is_last_subcycle <= 1'h0;
			wb_writeback_is_vector <= 1'h0;
			wb_writeback_mask <= 1'h0;
			wb_writeback_reg <= 1'h0;
			wb_writeback_thread_idx <= 1'h0;
			wb_writeback_value <= 1'h0;
			writeback_counter <= 5'h0;
			// End of automatics
		end
		else
		begin
			// Don't cause rollback if there isn't an instruction
			assert(!(sq_rollback_en && !dd_instruction_valid));
			
			// Only one pipeline should attempt to retire an instruction per cycle
			assert($onehot0({sx_instruction_valid, dd_instruction_valid, mx5_instruction_valid}));
		
			__debug_is_sync_store <= dd_instruction_valid && !dd_instruction.is_load
				&& memory_op == MEM_SYNC;

			// Latch the last fetched instruction to save for interrupt handling.
			// Because instructions are retired out of order, we need to ensure we
			// don't incorrect latch an earlier instruction., 
			if (wb_rollback_en)
				writeback_counter <= { 1'b0, writeback_counter[4:1] };
			else if (mx5_instruction_valid)
			begin
				if (writeback_counter == 0)
					last_retire_pc[mx5_thread_idx] <= mx5_instruction.pc;
			end
			else if (dd_instruction_valid)
			begin
				writeback_counter <= 5'b01111;
				if (!writeback_counter[4])
					last_retire_pc[dd_thread_idx] <= dd_instruction.pc;
			end
			else if (sx_instruction_valid)
			begin
				writeback_counter <= 5'b11111;
				last_retire_pc[sx_thread_idx] <= sx_instruction.pc;
			end
			else
				writeback_counter <= { 1'b0, writeback_counter[4:1] };
		
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
					wb_writeback_is_last_subcycle <= is_last_subcycle_mx;
					multi_issue_pending[mx5_thread_idx] <= !is_last_subcycle_mx;

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
					wb_writeback_is_last_subcycle <= is_last_subcycle_sx;
					multi_issue_pending[sx_thread_idx] <= !is_last_subcycle_sx;

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
					wb_writeback_is_last_subcycle <= is_last_subcycle_dd;
					multi_issue_pending[dd_thread_idx] <= !is_last_subcycle_dd;
				
					if (dd_instruction.is_load)
					begin
						// Loads should always have a destination register.
						// XXX there appears to be a case where something is a load, but not
						// a memory access.  That doesn't seem right.
						assert(dd_instruction.has_dest || !dd_instruction.is_memory_access);
						
						if (dd_is_io_address)
						begin
							wb_writeback_value <= {`VECTOR_LANES{ior_read_value}}; 
							wb_writeback_mask <= {`VECTOR_LANES{1'b1}};
						end
						else
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
					end
					else if (dd_instruction.memory_access_type == MEM_SYNC)
					begin
						// Synchronized stores are special in that they write back (whether they
						// were successful).
						assert(dd_instruction.has_dest && !dd_instruction.dest_is_vector);
						wb_writeback_value[0] <= sq_store_sync_success;
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
