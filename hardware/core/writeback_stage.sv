// 
// Copyright 2011-2015 Jeff Bush
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

`include "defines.sv"

// 
// Instruction Pipeline Writeback Stage
// - Controls signals to write results back to register file
// - Selects result from appropriate pipeline.
// - Aligns memory read results
// - Flag rollbacks. They are generally detected earlier in the pipeline, 
//   but we wait to handle them here to avoid having to reconcile multiple 
//   rollbacks in the same cycle.
//   * Branch
//   * Data cache miss
//   * Exception
//
// Exceptions and interrupts are precise in this architecture.
// Instructions may retire out of order because the execution pipelines have 
// different lengths. It's also possible, after a rollback, for earlier 
// instructions from the same thread to arrive at this stage (because they were 
// in the longer floating point pipeline). The rollback signal does not flush 
// later stages of the multicycle pipeline for this reason. This can be 
// challenging to visualize.
//

module writeback_stage(
	input                                 clk,
	input                                 reset,

	// From fp_execute_stage5
	input                                 fx5_instruction_valid,
	input decoded_instruction_t           fx5_instruction,
	input vector_t                        fx5_result,
	input vector_lane_mask_t              fx5_mask_value,
	input thread_idx_t                    fx5_thread_idx,
	input subcycle_t                      fx5_subcycle,

	// From int_execute_stage
	input                                 ix_instruction_valid,
	input decoded_instruction_t           ix_instruction,
	input vector_t                        ix_result,
	input thread_idx_t                    ix_thread_idx,
	input vector_lane_mask_t              ix_mask_value,
	input logic                           ix_rollback_en,
	input scalar_t                        ix_rollback_pc,
	input subcycle_t                      ix_subcycle,
	                               
	// From dcache_data_stage      
	input                                 dd_instruction_valid,
	input decoded_instruction_t           dd_instruction,
	input vector_lane_mask_t              dd_lane_mask,
	input thread_idx_t                    dd_thread_idx,
	input l1d_addr_t                      dd_request_vaddr,
	input subcycle_t                      dd_subcycle,
	input                                 dd_rollback_en,
	input scalar_t                        dd_rollback_pc,
	input cache_line_data_t               dd_load_data,
	input                                 dd_suspend_thread,
	input                                 dd_is_io_address,
	input                                 dd_access_fault,
	input                                 dd_tlb_miss,
	
	// From l1_store_queue
	input [`CACHE_LINE_BYTES - 1:0]       sq_store_bypass_mask,
	input cache_line_data_t               sq_store_bypass_data,
	input                                 sq_store_sync_success,
	input                                 sq_rollback_en,

	// From io_request_queue
	input scalar_t                        ior_read_value,
	input logic                           ior_rollback_en,
	
	// From control_registers
	input scalar_t                        cr_creg_read_val,
	input thread_bitmap_t                 cr_interrupt_en,
	input scalar_t                        cr_fault_handler,
	input scalar_t                        cr_tlb_miss_handler,
	input subcycle_t                      cr_eret_subcycle[`THREADS_PER_CORE],

	// To control_registers
	output logic                          wb_fault,
	output fault_reason_t                 wb_fault_reason,
	output scalar_t                       wb_fault_pc,
	output thread_idx_t                   wb_fault_thread_idx,
	output scalar_t                       wb_fault_access_vaddr,
	output subcycle_t                     wb_fault_subcycle,

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

	// To operand_fetch_stage/thread_select_stage
	output logic                          wb_writeback_en,
	output thread_idx_t                   wb_writeback_thread_idx,
	output logic                          wb_writeback_is_vector,
	output vector_t                       wb_writeback_value,
	output vector_lane_mask_t             wb_writeback_mask,
	output register_idx_t                 wb_writeback_reg,
	output logic                          wb_writeback_is_last_subcycle,

	// To thread_select_stage
	output thread_bitmap_t                wb_suspend_thread_oh,
	
	// Performance counters
	output logic                          perf_instruction_retire,
	output logic                          perf_store_rollback);

	scalar_t mem_load_lane;
	logic[$clog2(`CACHE_LINE_WORDS) - 1:0] mem_load_lane_idx;
	logic[7:0] byte_aligned;
	logic[15:0] half_aligned;
	logic[31:0] swapped_word_value;
	memory_op_t memory_op;
	cache_line_data_t endian_twiddled_data;
`ifdef SIMULATION
	scalar_t __debug_wb_pc;	// Used by testbench
	pipeline_sel_t __debug_wb_pipeline;
	logic __debug_is_sync_store;
`endif
	logic[`VECTOR_LANES - 1:0] scycle_vcompare_result;
	logic[`VECTOR_LANES - 1:0] mcycle_vcompare_result;
	vector_lane_mask_t dd_vector_lane_oh;
	cache_line_data_t bypassed_read_data;
	thread_bitmap_t thread_oh;
	scalar_t last_retire_pc[`THREADS_PER_CORE];
 	logic is_last_subcycle_dd;
	logic is_last_subcycle_sx;
	logic is_last_subcycle_mx;
	logic[4:0] writeback_counter;
 	
	assign perf_instruction_retire = fx5_instruction_valid || ix_instruction_valid || dd_instruction_valid;
	assign perf_store_rollback = sq_rollback_en;

	//
	// Rollback control logic
	//
	// These signals are not registered because the next instruction may be a memory store 
	// and we must squash it before it applies its side effects. This stage handles all rollbacks,
	// so there can be only one asserted at a time.
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
		wb_fault_access_vaddr = 0;
		wb_fault_subcycle = dd_subcycle;

		if (ix_instruction_valid && (ix_instruction.illegal || ix_instruction.ifetch_fault
			|| ix_instruction.tlb_miss))
		begin
			// Illegal instruction/ifetch fault
			wb_rollback_en = 1'b1;
			if (ix_instruction.tlb_miss)
				wb_rollback_pc = cr_tlb_miss_handler;
			else
				wb_rollback_pc = cr_fault_handler;
			
			wb_rollback_thread_idx = ix_thread_idx;
			wb_rollback_pipeline = PIPE_SCYCLE_ARITH;
			wb_fault = 1;
			if (ix_instruction.tlb_miss)
				wb_fault_reason = FR_ITLB_MISS;
			else if (ix_instruction.ifetch_fault)
				wb_fault_reason = FR_IFETCH_FAULT;
			else
				wb_fault_reason = FR_ILLEGAL_INSTRUCTION;

			wb_fault_pc = ix_instruction.pc;
			wb_fault_access_vaddr = ix_instruction.pc;
			wb_fault_thread_idx = ix_thread_idx;
		end
		else if (dd_instruction_valid && (dd_access_fault || dd_tlb_miss))
		begin
			// Memory access fault
			wb_rollback_en = 1'b1;
			wb_rollback_thread_idx = dd_thread_idx;
			wb_rollback_pipeline = PIPE_MEM;
			wb_fault = 1;
			if (dd_tlb_miss)
			begin
				wb_fault_reason = FR_DTLB_MISS;
				wb_rollback_pc = cr_tlb_miss_handler;
			end
			else
			begin
				wb_fault_reason = FR_INVALID_ACCESS;
				wb_rollback_pc = cr_fault_handler;
			end
			
			wb_fault_pc = dd_instruction.pc;
			wb_fault_thread_idx = dd_thread_idx;
			wb_fault_access_vaddr = dd_request_vaddr;
		end
		else if (ix_instruction_valid && ix_instruction.has_dest && ix_instruction.dest_reg == `REG_PC
			&& !ix_instruction.dest_is_vector)
		begin
			// Arithmetic with PC destination 
			wb_rollback_en = 1'b1;
			wb_rollback_pc = ix_result[0];	
			wb_rollback_thread_idx = ix_thread_idx;
			wb_rollback_pipeline = PIPE_SCYCLE_ARITH;
		end
		else if (dd_instruction_valid && dd_instruction.has_dest && dd_instruction.dest_reg == `REG_PC
			&& !dd_instruction.dest_is_vector && !dd_rollback_en)
		begin
			// Memory load with PC destination. Check dd_rollback_en to ensure this 
			// isn't a cache miss (if it was, handle it in below)
			wb_rollback_en = 1'b1;
			wb_rollback_pc = swapped_word_value;	
			wb_rollback_thread_idx = dd_thread_idx;
			wb_rollback_pipeline = PIPE_MEM;
		end
		else if (ix_instruction_valid && ix_rollback_en)
		begin
			// Check for rollback from single cycle pipeline. This happens
			// because of a branch.
			wb_rollback_en = 1;
			wb_rollback_thread_idx = ix_thread_idx;
			wb_rollback_pc = ix_rollback_pc;
			wb_rollback_pipeline = PIPE_SCYCLE_ARITH;
			if (ix_instruction.branch_type == BRANCH_ERET)
				wb_rollback_subcycle = cr_eret_subcycle[ix_thread_idx];
			else
				wb_rollback_subcycle = ix_subcycle;
		end
		else if (dd_instruction_valid && (dd_rollback_en || sq_rollback_en || ior_rollback_en))
		begin
			// Check for rollback from memory pipeline. This happens because
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
			&& !dd_instruction_valid
			&& (!ix_instruction_valid || ix_thread_idx == interrupt_thread_idx)
			&& !fx5_instruction_valid)
		begin	
			// We cannot flag an interrupt in the following cases:
			// - In the same cycle as another type of rollback.
			// - For a long latency (floating point) instruction because there isn't logic in 
			//   the thread select stage to invalidate the scoreboard entries.
			// - For a memory operation, because a device IO read/write may have already 
			//   occured in the last stage and rolling back here will cause them to happen
			//   again.
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
			if (ix_instruction_valid)
				wb_fault_subcycle = ix_subcycle;
			// else dd_subcycle by default
		end
	end

	idx_to_oh #(.NUM_SIGNALS(`THREADS_PER_CORE), .DIRECTION("LSB0")) idx_to_oh_thread(
		.one_hot(thread_oh),
		.index(dd_thread_idx));

	// Suspend thread if necessary
	assign wb_suspend_thread_oh = (dd_suspend_thread || sq_rollback_en || ior_rollback_en) 
		? thread_oh : thread_bitmap_t'(0);

	// If there are pending stores that have not yet been acknowledged and been updated
	// to the L1 cache, apply them now.
	genvar byte_lane;
	generate
		for (byte_lane = 0; byte_lane < `CACHE_LINE_BYTES; byte_lane++)
		begin : lane_bypass_gen
			assign bypassed_read_data[byte_lane * 8+:8] = sq_store_bypass_mask[byte_lane]
				? sq_store_bypass_data[byte_lane * 8+:8] : dd_load_data[byte_lane * 8+:8];
		end
	endgenerate

	assign memory_op = dd_instruction.memory_access_type;
	assign mem_load_lane_idx = ~dd_request_vaddr.offset[2+:$clog2(`CACHE_LINE_WORDS)];
	assign mem_load_lane = bypassed_read_data[mem_load_lane_idx * 32+:32];

	// Memory load byte aligner.
	always_comb
	begin
		case (dd_request_vaddr.offset[1:0])
			2'd0: byte_aligned = mem_load_lane[31:24];
			2'd1: byte_aligned = mem_load_lane[23:16];
			2'd2: byte_aligned = mem_load_lane[15:8];
			2'd3: byte_aligned = mem_load_lane[7:0];
			default: byte_aligned = '0;
		endcase
	end

	// Memory load halfword aligner.
	always_comb
	begin
		case (dd_request_vaddr.offset[1])
			1'd0: half_aligned = { mem_load_lane[23:16], mem_load_lane[31:24] };
			1'd1: half_aligned = { mem_load_lane[7:0], mem_load_lane[15:8] };
			default: half_aligned = '0;
		endcase
	end
	
	assign swapped_word_value = { mem_load_lane[7:0], mem_load_lane[15:8], mem_load_lane[23:16],
		 mem_load_lane[31:24] };
	
	// Endian swap memory load
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
			assign scycle_vcompare_result[mask_lane] = ix_result[mask_lane][0];
			assign mcycle_vcompare_result[mask_lane] = fx5_result[mask_lane][0];
		end
	endgenerate

	idx_to_oh #(.NUM_SIGNALS(`VECTOR_LANES), .DIRECTION("MSB0")) convert_dd_lane(
		.one_hot(dd_vector_lane_oh),
		.index(dd_subcycle));

 	assign is_last_subcycle_dd = dd_subcycle == dd_instruction.last_subcycle;
	assign is_last_subcycle_sx = ix_subcycle == ix_instruction.last_subcycle;
	assign is_last_subcycle_mx = fx5_subcycle == fx5_instruction.last_subcycle;

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			for (int i = 0; i < `THREADS_PER_CORE; i++)
			begin
				last_retire_pc[i] <= 0;
			end

`ifdef SIMULATION
			__debug_wb_pipeline <= PIPE_MEM;
			__debug_is_sync_store <= '0;
			__debug_wb_pc <= '0;
`endif
			
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			wb_writeback_en <= '0;
			wb_writeback_is_last_subcycle <= '0;
			wb_writeback_is_vector <= '0;
			wb_writeback_mask <= '0;
			wb_writeback_reg <= '0;
			wb_writeback_thread_idx <= '0;
			wb_writeback_value <= '0;
			writeback_counter <= '0;
			// End of automatics
		end
		else
		begin
			// Don't cause rollback if there isn't an instruction
			assert(!(sq_rollback_en && !dd_instruction_valid));
			
			// Only one pipeline should attempt to retire an instruction per cycle
			assert($onehot0({ix_instruction_valid, dd_instruction_valid, fx5_instruction_valid}));
		
`ifdef SIMULATION
			// Used by testbench for cosimulation output
			__debug_is_sync_store <= dd_instruction_valid && !dd_instruction.is_load
				&& memory_op == MEM_SYNC;
`endif
			// Latch the last *issued* instruction to save for interrupt handling.
			// Because instructions can retire out of order, we need to ensure we
			// don't incorrectly latch an instruction that issued earlier but
			// retired later.
			if (wb_rollback_en)
			begin
				writeback_counter <= { 1'b0, writeback_counter[4:1] };
				if (ix_instruction_valid && ix_rollback_en)
					last_retire_pc[ix_thread_idx] <= ix_rollback_pc;
					
				// XXX pc load from memory?
			end
			else if (fx5_instruction_valid)
			begin
				if (writeback_counter == 0)
					last_retire_pc[fx5_thread_idx] <= fx5_instruction.pc;
			end
			else if (dd_instruction_valid)
			begin
				writeback_counter <= 5'b01111;
				if (!writeback_counter[4])
					last_retire_pc[dd_thread_idx] <= dd_instruction.pc;
			end
			else if (ix_instruction_valid)
			begin
				writeback_counter <= 5'b11111;
				last_retire_pc[ix_thread_idx] <= ix_instruction.pc;
			end
			else
				writeback_counter <= { 1'b0, writeback_counter[4:1] };

			// wb_rollback_en is derived combinatorially from the instruction 
			// that is about to retire, so this doesn't need to check 
			// wb_rollback_thread_idx like other places.
			case ({ fx5_instruction_valid, ix_instruction_valid, dd_instruction_valid })
				//
				// floating point pipeline result
				//
				3'b100:
				begin
					if (fx5_instruction.has_dest && !wb_rollback_en)
						wb_writeback_en <= 1;
					else
						wb_writeback_en <= 0;

					wb_writeback_thread_idx <= fx5_thread_idx;
					wb_writeback_is_vector <= fx5_instruction.dest_is_vector;
					if (fx5_instruction.is_compare)
						wb_writeback_value <= vector_t'(mcycle_vcompare_result);
					else
						wb_writeback_value <= fx5_result;
					
					wb_writeback_mask <= fx5_mask_value;
					wb_writeback_reg <= fx5_instruction.dest_reg;
					wb_writeback_is_last_subcycle <= is_last_subcycle_mx;

`ifdef SIMULATION
					// Used by testbench for cosimulation output
					__debug_wb_pc <= fx5_instruction.pc;
					__debug_wb_pipeline <= PIPE_MCYCLE_ARITH;
`endif
				end

				//
				// Single cycle pipeline result
				//
				3'b010:
				begin
					if (ix_instruction.is_branch && (ix_instruction.branch_type == BRANCH_CALL_OFFSET
						|| ix_instruction.branch_type == BRANCH_CALL_REGISTER))
					begin
						// Call is a special case: it both rolls back and writes back a register (ra)
						wb_writeback_en <= 1;	
					end
					else if (ix_instruction.has_dest && !wb_rollback_en)
						wb_writeback_en <= 1;	// This is a normal, non-rolled-back instruction
					else
						wb_writeback_en <= 0;

					wb_writeback_thread_idx <= ix_thread_idx;
					wb_writeback_is_vector <= ix_instruction.dest_is_vector;
					if (ix_instruction.is_compare)
						wb_writeback_value <= vector_t'(scycle_vcompare_result);
					else
						wb_writeback_value <= ix_result;
					
					wb_writeback_mask <= ix_mask_value;
					wb_writeback_reg <= ix_instruction.dest_reg;
					wb_writeback_is_last_subcycle <= is_last_subcycle_sx;

`ifdef SIMULATION
					// Used by testbench for cosimulation output
					__debug_wb_pc <= ix_instruction.pc;
					__debug_wb_pipeline <= PIPE_SCYCLE_ARITH;
`endif
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
				
					if (dd_instruction.is_load)
					begin
						// Loads should always have a destination register.
						// XXX there appears to be a case where something is a load, but not
						// a memory access. That doesn't seem right.
						assert(dd_instruction.has_dest || !dd_instruction.is_memory_access);
						
						unique case (memory_op)
							MEM_B:  wb_writeback_value[0] <= { 24'b0, byte_aligned };
							MEM_BX: wb_writeback_value[0] <= { {24{byte_aligned[7]}}, byte_aligned };
							MEM_S:  wb_writeback_value[0] <= { 16'b0, half_aligned };
							MEM_SX: wb_writeback_value[0] <= { {16{half_aligned[15]}}, half_aligned };
							MEM_SYNC: wb_writeback_value[0] <= swapped_word_value;
							MEM_L:
							begin
								// Scalar Load
								assert(!dd_instruction.dest_is_vector);

								if (dd_is_io_address)
								begin
									wb_writeback_value[0] <= ior_read_value; 
									wb_writeback_mask <= {`VECTOR_LANES{1'b1}};
								end
								else
								begin
									wb_writeback_value[0] <= swapped_word_value; 
									wb_writeback_mask <= {`VECTOR_LANES{1'b1}};
								end
							end
					
							MEM_CONTROL_REG:
							begin
								wb_writeback_value[0] <= cr_creg_read_val; 
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
								wb_writeback_value <= {`VECTOR_LANES{swapped_word_value}};
								wb_writeback_mask <= dd_vector_lane_oh & dd_lane_mask;	
							end
						endcase
					end
					else if (dd_instruction.memory_access_type == MEM_SYNC)
					begin
						// Synchronized stores are special because they write back (whether they
						// were successful).
						assert(dd_instruction.has_dest && !dd_instruction.dest_is_vector);
						wb_writeback_value[0] <= scalar_t'(sq_store_sync_success);
					end

`ifdef SIMULATION
					// Used by testbench for cosimulation output
					__debug_wb_pc <= dd_instruction.pc;
					__debug_wb_pipeline <= PIPE_MEM;
`endif
				end
				
				3'b000: wb_writeback_en <= 0;
				default: wb_writeback_en <= 0;
			endcase
		end
	end	
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// verilog-auto-reset-widths:unbased
// End:
