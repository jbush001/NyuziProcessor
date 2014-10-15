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

`include "defines.sv"

//
// Instruction pipeline L1 data cache data stage.
// - Detect cache miss or hit based on tag information fetched from last stage. 
// - Align store data to proper location in cache line.
// - Read from cache data storage.
// - Drive signals to previous stage to update LRU
// 

module dcache_data_stage(
	input                                     clk,
	input                                     reset,
                                              
	// From dcache tag stage                  
	input                                     dt_instruction_valid,
	input decoded_instruction_t               dt_instruction,
	input vector_lane_mask_t                  dt_mask_value,
	input thread_idx_t                        dt_thread_idx,
	input l1d_addr_t                          dt_request_addr,
	input vector_t                            dt_store_value,
	input subcycle_t                          dt_subcycle,
	input                                     dt_valid[`L1D_WAYS],
	input l1d_tag_t                           dt_tag[`L1D_WAYS],
	
	// To dcache_tag_stage
	output logic                              dd_update_lru_en,
	output l1d_way_idx_t                      dd_update_lru_way,

	// To io_request_queue
	output                                    dd_io_write_en,
	output                                    dd_io_read_en,
	output thread_idx_t                       dd_io_thread_idx,
	output scalar_t                           dd_io_addr,
	output scalar_t                           dd_io_write_value,
                                              
	// To writeback stage                     
	output                                    dd_instruction_valid,
	output decoded_instruction_t              dd_instruction,
	output vector_lane_mask_t                 dd_lane_mask,
	output thread_idx_t                       dd_thread_idx,
	output l1d_addr_t                         dd_request_addr,
	output subcycle_t                         dd_subcycle,
	output logic                              dd_rollback_en,
	output scalar_t                           dd_rollback_pc,
	output cache_line_data_t                  dd_load_data,
	output logic                              dd_suspend_thread,
	output logic                              dd_is_io_address,
	output logic                              dd_access_fault,

	// To control registers (these signals are unregistered)
	output                                    dd_creg_write_en,
	output                                    dd_creg_read_en,
	output control_register_t                 dd_creg_index,
	output scalar_t                           dd_creg_write_val,

	// From l2_interface
	input                                     l2i_ddata_update_en,
	input l1d_way_idx_t                       l2i_ddata_update_way,
	input l1d_set_idx_t                       l2i_ddata_update_set,
	input cache_line_data_t                   l2i_ddata_update_data,
	input [`L1D_WAYS - 1:0]                   l2i_dtag_update_en_oh,
	input l1d_set_idx_t                       l2i_dtag_update_set,
	input l1d_tag_t                           l2i_dtag_update_tag,
 
 	// To l2_interface
	output logic                              dd_cache_miss,
	output scalar_t                           dd_cache_miss_addr,
	output thread_idx_t                       dd_cache_miss_thread_idx,
	output logic                              dd_cache_miss_synchronized,
	output logic                              dd_store_en,
	output logic                              dd_flush_en,
	output logic                              dd_membar_en,
	output [`CACHE_LINE_BYTES - 1:0]          dd_store_mask,
	output scalar_t                           dd_store_addr,
	output cache_line_data_t                  dd_store_data,
	output thread_idx_t                       dd_store_thread_idx,
	output logic                              dd_store_synchronized,
	output scalar_t                           dd_store_bypass_addr,              
	output thread_idx_t                       dd_store_bypass_thread_idx,

	// Interrupt input
	input                                     interrupt_pending,
	input thread_idx_t                        interrupt_thread_idx,
	input                                     wb_interrupt_ack,

	// From writeback stage                   
	input logic                               wb_rollback_en,
	input thread_idx_t                        wb_rollback_thread_idx,
	input pipeline_sel_t                      wb_rollback_pipeline,
	
	// Performance counters
	output logic                              perf_dcache_hit,
	output logic                              perf_dcache_miss,
	output logic                              perf_store_count);

	logic dcache_access_req;
	logic creg_access_req;
	vector_lane_mask_t word_store_mask;
	logic[3:0] byte_store_mask;
	logic[$clog2(`CACHE_LINE_WORDS) - 1:0] cache_lane_idx;
	cache_line_data_t endian_twiddled_data;
	scalar_t lane_store_value;
	logic is_io_address;
	scalar_t scatter_gather_ptr;
	logic[`CACHE_LINE_WORDS - 1:0] cache_lane_mask;
	logic[`CACHE_LINE_WORDS - 1:0] subcycle_mask;
	logic[`L1D_WAYS - 1:0] way_hit_oh;
	l1d_way_idx_t way_hit_idx;
	logic cache_hit;
	logic dcache_load_req;
	scalar_t dcache_request_addr;
	logic rollback_this_stage;
	logic cache_near_miss;
	logic dcache_store_req;
	thread_bitmap_t sync_load_pending;
	logic io_access_req;
	logic is_unaligned_access;
	logic is_synchronized;
	
	// rollback_this_stage indicates a rollback was requested from an earlier issued
	// instruction, but it does not get set when this stage is triggering a rollback.
	assign rollback_this_stage = wb_rollback_en 
		&& wb_rollback_thread_idx == dt_thread_idx
		&& wb_rollback_pipeline == PIPE_MEM;
	assign is_io_address = dt_request_addr[31:16] == 16'hffff;
	assign is_synchronized = dt_instruction.memory_access_type == MEM_SYNC;
	assign dcache_access_req = dt_instruction_valid 
		&& dt_instruction.is_memory_access 
		&& dt_instruction.memory_access_type != MEM_CONTROL_REG 
		&& !is_io_address
		&& !rollback_this_stage
		&& (dt_instruction.is_load || dd_store_mask != 0); // Skip store if mask is clear
	assign dcache_load_req = dcache_access_req && dt_instruction.is_load;
	assign dcache_store_req = dcache_access_req && !dt_instruction.is_load;
	assign dcache_request_addr = { dt_request_addr[31:`CACHE_LINE_OFFSET_WIDTH], 
		{`CACHE_LINE_OFFSET_WIDTH{1'b0}} };
	assign cache_lane_idx = dt_request_addr.offset[`CACHE_LINE_OFFSET_WIDTH - 1:2];
	assign dd_flush_en = dt_instruction_valid
		&& dt_instruction.is_cache_control 
		&& dt_instruction.cache_control_op == CACHE_DFLUSH 
		&& !rollback_this_stage
		&& !is_io_address;
	assign dd_membar_en = dt_instruction_valid
		&& dt_instruction.is_cache_control 
		&& dt_instruction.cache_control_op == CACHE_MEMBAR 
		&& !rollback_this_stage
		&& !is_io_address;

	assign creg_access_req = dt_instruction_valid 
		&& dt_instruction.is_memory_access 
		&& dt_instruction.memory_access_type == MEM_CONTROL_REG
		&& !rollback_this_stage;
	assign dd_creg_write_en = creg_access_req && !dt_instruction.is_load;
	assign dd_creg_read_en = creg_access_req && dt_instruction.is_load;
	assign dd_creg_write_val = dt_store_value[0];
	assign dd_creg_index = dt_instruction.creg_index;

	assign perf_dcache_hit = cache_hit && dcache_load_req;
	assign perf_dcache_miss = !cache_hit && dcache_load_req; 
	assign perf_store_count = dcache_store_req;

	assign dd_store_bypass_addr = dt_request_addr;
	assign dd_store_bypass_thread_idx = dt_thread_idx;
	assign dd_store_addr = dt_request_addr;
	assign dd_store_synchronized = is_synchronized;

	assign io_access_req = dt_instruction_valid 
		&& dt_instruction.is_memory_access 
		&& dt_instruction.memory_access_type != MEM_CONTROL_REG 
		&& is_io_address 
		&& !rollback_this_stage;
	assign dd_io_write_en = io_access_req && !dt_instruction.is_load;
	assign dd_io_read_en = io_access_req && dt_instruction.is_load;
	assign dd_io_write_value = dt_store_value[0];
	assign dd_io_thread_idx = dt_thread_idx;
	assign dd_io_addr = { 16'd0, dt_request_addr[15:0] };
	
	// 
	// Check for cache hit
	//
	genvar way_idx;
	generate
		for (way_idx = 0; way_idx < `L1D_WAYS; way_idx++)
		begin : hit_check_gen
			assign way_hit_oh[way_idx] = dt_request_addr.tag == dt_tag[way_idx] && dt_valid[way_idx]; 
		end
	endgenerate

	// A synchronized load is always treated as a load miss the first time it is issued, because
	// it needs to register itself with the L2 cache.
	assign cache_hit = |way_hit_oh && (!is_synchronized || sync_load_pending[dt_thread_idx]);

	//
	// Store alignment
	//
	idx_to_oh #(.NUM_SIGNALS(`CACHE_LINE_WORDS), .DIRECTION("MSB0")) idx_to_oh_subcycle(
		.one_hot(subcycle_mask),
		.index(dt_subcycle));
	
	idx_to_oh #(.NUM_SIGNALS(`CACHE_LINE_WORDS), .DIRECTION("MSB0")) idx_to_oh_cache_lane(
		.one_hot(cache_lane_mask),
		.index(cache_lane_idx));
	
	always_comb
	begin
		word_store_mask = 0;
		unique case (dt_instruction.memory_access_type)
			MEM_BLOCK, MEM_BLOCK_M:	// Block vector access
				word_store_mask = dt_mask_value;
			
			MEM_SCGATH, MEM_SCGATH_M:	// Scatter/Gather access
			begin
				if (dt_mask_value & subcycle_mask)
					word_store_mask = cache_lane_mask;
				else
					word_store_mask = 0;
			end

			default:	// Scalar access
				word_store_mask = cache_lane_mask;
		endcase
	end

	// Endian swap vector data
	genvar swap_word;
	generate
		for (swap_word = 0; swap_word < `CACHE_LINE_BYTES / 4; swap_word++)
		begin : swap_word_gen
			assign endian_twiddled_data[swap_word * 32+:8] = dt_store_value[swap_word][24+:8];
			assign endian_twiddled_data[swap_word * 32 + 8+:8] = dt_store_value[swap_word][16+:8];
			assign endian_twiddled_data[swap_word * 32 + 16+:8] = dt_store_value[swap_word][8+:8];
			assign endian_twiddled_data[swap_word * 32 + 24+:8] = dt_store_value[swap_word][0+:8];
		end
	endgenerate

	assign lane_store_value = dt_store_value[~dt_subcycle];

	// byte_store_mask and dd_store_data.
	always_comb
	begin
		unique case (dt_instruction.memory_access_type)
			MEM_B, MEM_BX: // Byte
			begin
				dd_store_data = {`CACHE_LINE_WORDS * 4{dt_store_value[0][7:0]}};
				unique case (dt_request_addr.offset[1:0])
					2'd0: byte_store_mask = 4'b1000;
					2'd1: byte_store_mask = 4'b0100;
					2'd2: byte_store_mask = 4'b0010;
					2'd3: byte_store_mask = 4'b0001;
				endcase
			end

			MEM_S, MEM_SX: // 16 bits
			begin
				dd_store_data = {`CACHE_LINE_WORDS * 2{dt_store_value[0][7:0], dt_store_value[0][15:8]}};
				if (dt_request_addr.offset[1] == 1'b0)
					byte_store_mask = 4'b1100;
				else
					byte_store_mask = 4'b0011;
			end

			MEM_L, MEM_SYNC: // 32 bits
			begin
				byte_store_mask = 4'b1111;
				dd_store_data = {`CACHE_LINE_WORDS{dt_store_value[0][7:0], dt_store_value[0][15:8], 
					dt_store_value[0][23:16], dt_store_value[0][31:24] }};
			end

			MEM_SCGATH, MEM_SCGATH_M:
			begin
				byte_store_mask = 4'b1111;
				dd_store_data = {`CACHE_LINE_WORDS{lane_store_value[7:0], lane_store_value[15:8], 
					lane_store_value[23:16], lane_store_value[31:24] }};
			end

			default: // Vector
			begin
				byte_store_mask = 4'b1111;
				dd_store_data = endian_twiddled_data;
			end
		endcase
	end

	// Check for unaligned access
	always_comb
	begin
		unique case (dt_instruction.memory_access_type)
			MEM_S, MEM_SX: is_unaligned_access = dt_request_addr.offset[0];
			MEM_L, MEM_SYNC, MEM_SCGATH, MEM_SCGATH_M: is_unaligned_access = |dt_request_addr.offset[1:0];
			MEM_BLOCK, MEM_BLOCK_M: is_unaligned_access = dt_request_addr.offset != 0;
			default: is_unaligned_access = 0;
		endcase
	end

	// Generate store mask signals.  word_store_mask corresponds to lanes, byte_store_mask
	// corresponds to bytes within a word.  byte_store_mask always
	// has all bits set if word_store_mask has more than one bit set. That is:
	// we are either selecting some number of words within the cache line for
	// a vector transfer or some bytes within a specific word for a scalar transfer.
	genvar mask_idx;
	generate
		for (mask_idx = 0; mask_idx < `CACHE_LINE_BYTES; mask_idx++)
		begin : store_mask_gen
			assign dd_store_mask[mask_idx] = word_store_mask[mask_idx / 4]
				& byte_store_mask[mask_idx & 3];
		end
	endgenerate

	oh_to_idx #(.NUM_SIGNALS(`L1D_WAYS)) encode_hit_way(
		.one_hot(way_hit_oh),
		.index(way_hit_idx));

	sram_1r1w #(
		.DATA_WIDTH(`CACHE_LINE_BITS), 
		.SIZE(`L1D_WAYS * `L1D_SETS),
		.READ_DURING_WRITE("NEW_DATA")
	) l1d_data(
		// Instruction pipeline access.  
		.read_en(cache_hit && dcache_load_req),
		.read_addr({way_hit_idx, dt_request_addr.set_idx}),
		.read_data(dd_load_data),
		
		// Update from L2 cache interface
		.write_en(l2i_ddata_update_en),	
		.write_addr({l2i_ddata_update_way, l2i_ddata_update_set}),
		.write_data(l2i_ddata_update_data),
		.*);

	// Cache miss occured in the cycle the same line is being filled. If we suspend the thread here,
	// it will never receive a wakeup. Instead roll the thread back and let it retry.
	// This must not be set if the load is synchronized: it must do a round trip to the L2 cache
	// to register the address regardless of whether the data is the cache.
	assign cache_near_miss = !cache_hit 
		&& dcache_load_req 
		&& |l2i_dtag_update_en_oh
		&& l2i_dtag_update_set == dt_request_addr.set_idx 
		&& l2i_dtag_update_tag == dt_request_addr.tag
		&& !is_synchronized; 

	assign dd_cache_miss = !cache_hit && dcache_load_req && !cache_near_miss && !is_unaligned_access;
	assign dd_cache_miss_addr = dcache_request_addr;
	assign dd_cache_miss_thread_idx = dt_thread_idx;
	assign dd_cache_miss_synchronized = is_synchronized;
	assign dd_store_en = dcache_store_req && !is_unaligned_access;
	assign dd_store_thread_idx = dt_thread_idx;

	assign dd_update_lru_en = cache_hit && dcache_access_req && !is_unaligned_access;
	assign dd_update_lru_way = way_hit_idx;

	// The first synchronized load is always a miss (even if data is 
	// present) in order to register request with L2 cache.  The second 
	// will not be a miss (if the data is cached).  sync_load_pending 
	// tracks this state. 
	genvar thread_idx;
	generate
		for (thread_idx = 0; thread_idx < `THREADS_PER_CORE; thread_idx++)
		begin : sync_pending_gen
			always @(posedge clk, posedge reset)
			begin
				if (reset)
					sync_load_pending[thread_idx] <= 0;
				else if (interrupt_pending && wb_interrupt_ack 
					&& interrupt_thread_idx == thread_idx)
				begin
					// If a thread is interrupted while waiting on a synchronized load, 
					// reset the sync load pending flag.
					sync_load_pending[thread_idx] <= 0;
				end 
				else if (dcache_load_req && is_synchronized && dt_thread_idx == thread_idx)
				begin
					// Track if this is the first or restarted request.
					sync_load_pending[thread_idx] <= !sync_load_pending[thread_idx];
				end
			end
		end
	endgenerate

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			dd_access_fault <= 1'h0;
			dd_instruction <= 1'h0;
			dd_instruction_valid <= 1'h0;
			dd_is_io_address <= 1'h0;
			dd_lane_mask <= 1'h0;
			dd_request_addr <= 1'h0;
			dd_rollback_en <= 1'h0;
			dd_rollback_pc <= 1'h0;
			dd_subcycle <= 1'h0;
			dd_suspend_thread <= 1'h0;
			dd_thread_idx <= 1'h0;
			// End of automatics
		end
		else
		begin
			// Make sure data is not present in more than one way.
			assert(!dcache_load_req || $onehot0(way_hit_oh));

			dd_instruction_valid <= dt_instruction_valid && !rollback_this_stage;
			dd_instruction <= dt_instruction;
			dd_lane_mask <= dt_mask_value;
			dd_thread_idx <= dt_thread_idx;
			dd_request_addr <= dt_request_addr;
			dd_subcycle <= dt_subcycle;
			dd_rollback_pc <= dt_instruction.pc;
			dd_is_io_address <= is_io_address;

			// Rollback on cache miss
			dd_rollback_en <= dcache_load_req && !cache_hit;

			// Suspend the thread if there is a cache miss.
			// In the near miss case (described above), don't suspend thread.
			dd_suspend_thread <= dcache_load_req && !cache_hit && !cache_near_miss
				&& !is_unaligned_access;
			
			dd_access_fault <= is_unaligned_access && dcache_access_req;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
