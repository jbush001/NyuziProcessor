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
// Detect cache miss or hit based on tag information. Perform alignment for
// various types of writes. This stage contains storage for the cache data
// and controls reading and writing it.
// 

module dcache_data_stage(
	input                                     clk,
	input                                     reset,
                                              
	// From dcache tag stage                  
	input                                     dt_instruction_valid,
	input decoded_instruction_t               dt_instruction,
	input [`VECTOR_LANES - 1:0]               dt_mask_value,
	input thread_idx_t                        dt_thread_idx,
	input l1d_addr_t                          dt_request_addr,
	input vector_t                            dt_store_value,
	input subcycle_t                          dt_subcycle,
	input cache_line_state_t                  dt_state[`L1D_WAYS],
	input l1d_tag_t                           dt_tag[`L1D_WAYS],
	input [2:0]                               dt_lru_flags,
	
	// To dcache_tag_stage
	output logic                              dd_update_lru_en,
	output logic[2:0]                         dd_update_lru_flags,
	output l1d_set_idx_t                      dd_update_lru_set,
                                              
	// To writeback stage                     
	output                                    dd_instruction_valid,
	output decoded_instruction_t              dd_instruction,
	output [`VECTOR_LANES - 1:0]              dd_mask_value,
	output thread_idx_t                       dd_thread_idx,
	output l1d_addr_t                         dd_request_addr,
	output subcycle_t                         dd_subcycle,
	output logic                              dd_rollback_en,
	output scalar_t                           dd_rollback_pc,
	output logic                              dd_sync_store_success,
	output [`CACHE_LINE_BITS - 1:0]           dd_read_data,

	// To control registers (these signals are unregistered)
	output                                    dd_creg_write_en,
	output                                    dd_creg_read_en,
	output control_register_t                 dd_creg_index,
	output scalar_t                           dd_creg_write_val,
	
	// To thread select stage
	output logic[`THREADS_PER_CORE - 1:0]     dd_dcache_wait_oh,

	// From ring controller/L2 interconnect
	input                                     rc_ddata_update_en,
	input l1d_way_idx_t                       rc_ddata_update_way,
	input l1d_set_idx_t                       rc_ddata_update_set,
	input [`CACHE_LINE_BITS - 1:0]            rc_ddata_update_data,
	input                                     rc_ddata_read_en,
	input l1d_set_idx_t                       rc_ddata_read_set,
 	input l1d_way_idx_t                       rc_ddata_read_way,
	input [`L1D_WAYS - 1:0]                   rc_dtag_update_en_oh,
	input l1d_set_idx_t                       rc_dtag_update_set,
	input l1d_tag_t                           rc_dtag_update_tag,
 
 	// To ring controller
	output logic                              dd_cache_miss,
	output scalar_t                           dd_cache_miss_addr,
	output logic                              dd_cache_miss_store,
	output thread_idx_t                       dd_cache_miss_thread_idx,
	output logic[`CACHE_LINE_BITS - 1:0]      dd_ddata_read_data,

	// From writeback stage                   
	input logic                               wb_rollback_en,
	input thread_idx_t                        wb_rollback_thread_idx,
	input pipeline_sel_t                      wb_rollback_pipeline);

	logic dcache_access_req;
	logic[`VECTOR_LANES - 1:0] word_store_mask;
	logic[3:0] byte_store_mask;
	logic[$clog2(`CACHE_LINE_WORDS) - 1:0] cache_lane_idx;
	logic[`CACHE_LINE_BITS - 1:0] endian_twiddled_data;
	scalar_t lane_store_value;
	logic is_io_address;
	scalar_t scatter_gather_ptr;
	logic[`CACHE_LINE_WORDS - 1:0] cache_lane_mask;
	logic[`CACHE_LINE_WORDS - 1:0] subcycle_mask;
	logic sync_store_success;
	scalar_t latched_atomic_address[`THREADS_PER_CORE];
	logic[`L1D_WAYS - 1:0] way_hit_oh;
	l1d_way_idx_t way_hit_idx;
	logic cache_hit;
	logic dcache_read_req;
	logic dcache_store_req;
	logic[`CACHE_LINE_BITS - 1:0] dcache_store_data;
	logic[`CACHE_LINE_BYTES - 1:0] dcache_store_mask;
	scalar_t dcache_request_addr;
	logic[`THREADS_PER_CORE - 1:0] thread_oh;
	logic cache_data_store_en;
	logic rollback_this_stage;
	logic cache_near_miss;
	logic[2:0] new_lru_flags;
	
	assign rollback_this_stage = wb_rollback_en && wb_rollback_thread_idx == dt_thread_idx
		 && wb_rollback_pipeline == PIPE_MEM;
	assign is_io_address = dt_request_addr[31:16] == 16'hffff;
	assign dcache_access_req = dt_instruction_valid && dt_instruction.is_memory_access 
		&& dt_instruction.memory_access_type != MEM_CONTROL_REG && !is_io_address
		&& !rollback_this_stage;
	assign dcache_read_req = dcache_access_req && dt_instruction.is_load;
	assign dcache_store_req = dcache_access_req && !dt_instruction.is_load 
		&& dcache_store_mask != 0;
	assign dd_creg_write_en = dt_instruction_valid && dt_instruction.is_memory_access 
		&& !dt_instruction.is_load && dt_instruction.memory_access_type == MEM_CONTROL_REG;
	assign dd_creg_read_en = dt_instruction_valid && dt_instruction.is_memory_access 
		&& dt_instruction.is_load && dt_instruction.memory_access_type == MEM_CONTROL_REG;
	assign dd_creg_write_val = dt_store_value[0];
	assign dd_creg_index = dt_instruction.creg_index;
	assign sync_store_success = latched_atomic_address[dt_thread_idx] == dcache_request_addr;
	assign dcache_request_addr = { dt_request_addr[31:`CACHE_LINE_OFFSET_WIDTH], 
		{`CACHE_LINE_OFFSET_WIDTH{1'b0}} };
	assign cache_lane_idx = dt_request_addr.offset[`CACHE_LINE_OFFSET_WIDTH - 1:2];
	
	// 
	// Check for cache hit
	//
	genvar way_idx;
	generate
		for (way_idx = 0; way_idx < `L1D_WAYS; way_idx++)
		begin : hit_check_logic
			logic tag_match;
			
			assign tag_match = dt_request_addr.tag == dt_tag[way_idx];
		
			always_comb
			begin
				if (dt_instruction.is_load)
					way_hit_oh[way_idx] = tag_match && dt_state[way_idx] != CL_STATE_INVALID; 
				else
					way_hit_oh[way_idx] = tag_match && dt_state[way_idx] == CL_STATE_MODIFIED;
			end
		end
	endgenerate

	assign cache_hit = |way_hit_oh;

	//
	// Write alignment
	//
	index_to_one_hot #(.NUM_SIGNALS(`THREADS_PER_CORE), .DIRECTION("LSB0")) thread_oh_gen(
		.one_hot(thread_oh),
		.index(dt_thread_idx));
	
	index_to_one_hot #(.NUM_SIGNALS(`CACHE_LINE_WORDS), .DIRECTION("MSB0")) subcycle_mask_gen(
		.one_hot(subcycle_mask),
		.index(dt_subcycle));
	
	index_to_one_hot #(.NUM_SIGNALS(`CACHE_LINE_WORDS), .DIRECTION("MSB0")) cache_lane_mask_gen(
		.one_hot(cache_lane_mask),
		.index(cache_lane_idx));
	
	always_comb
	begin
		word_store_mask = 0;
		unique case (dt_instruction.memory_access_type)
			MEM_BLOCK, MEM_BLOCK_M, MEM_BLOCK_IM:	// Block vector access
				word_store_mask = dt_mask_value;
			
			MEM_STRIDED, MEM_STRIDED_M, MEM_STRIDED_IM,	// Strided vector access 
			MEM_SCGATH, MEM_SCGATH_M, MEM_SCGATH_IM:	// Scatter/Gather access
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
		begin : swapper
			assign endian_twiddled_data[swap_word * 32+:8] = dt_store_value[swap_word][24+:8];
			assign endian_twiddled_data[swap_word * 32 + 8+:8] = dt_store_value[swap_word][16+:8];
			assign endian_twiddled_data[swap_word * 32 + 16+:8] = dt_store_value[swap_word][8+:8];
			assign endian_twiddled_data[swap_word * 32 + 24+:8] = dt_store_value[swap_word][0+:8];
		end
	endgenerate

	assign lane_store_value = dt_store_value[`CACHE_LINE_WORDS - 1 - dt_subcycle];

	// byte_store_mask and dcache_store_data.
	always_comb
	begin
		unique case (dt_instruction.memory_access_type)
			MEM_B, MEM_BX: // Byte
			begin
				unique case (dt_request_addr.offset[1:0])
					2'b00:
					begin
						byte_store_mask = 4'b1000;
						dcache_store_data = {`CACHE_LINE_WORDS{dt_store_value[0][7:0], 24'd0}};
					end

					2'b01:
					begin
						byte_store_mask = 4'b0100;
						dcache_store_data = {`CACHE_LINE_WORDS{8'd0, dt_store_value[0][7:0], 16'd0}};
					end

					2'b10:
					begin
						byte_store_mask = 4'b0010;
						dcache_store_data = {`CACHE_LINE_WORDS{16'd0, dt_store_value[0][7:0], 8'd0}};
					end

					2'b11:
					begin
						byte_store_mask = 4'b0001;
						dcache_store_data = {`CACHE_LINE_WORDS{24'd0, dt_store_value[0][7:0]}};
					end
				endcase
			end

			MEM_S, MEM_SX: // 16 bits
			begin
				if (dt_request_addr.offset[1] == 1'b0)
				begin
					byte_store_mask = 4'b1100;
					dcache_store_data = {`CACHE_LINE_WORDS{dt_store_value[0][7:0], dt_store_value[0][15:8], 16'd0}};
				end
				else
				begin
					byte_store_mask = 4'b0011;
					dcache_store_data = {`CACHE_LINE_WORDS{16'd0, dt_store_value[0][7:0], dt_store_value[0][15:8]}};
				end
			end

			MEM_L, MEM_SYNC: // 32 bits
			begin
				byte_store_mask = 4'b1111;
				dcache_store_data = {`CACHE_LINE_WORDS{dt_store_value[0][7:0], dt_store_value[0][15:8], 
					dt_store_value[0][23:16], dt_store_value[0][31:24] }};
			end

			MEM_SCGATH, MEM_SCGATH_M, MEM_SCGATH_IM,	
			MEM_STRIDED, MEM_STRIDED_M, MEM_STRIDED_IM:
			begin
				byte_store_mask = 4'b1111;
				dcache_store_data = {`CACHE_LINE_WORDS{lane_store_value[7:0], lane_store_value[15:8], lane_store_value[23:16], 
					lane_store_value[31:24] }};
			end

			default: // Vector
			begin
				byte_store_mask = 4'b1111;
				dcache_store_data = endian_twiddled_data;
			end
		endcase
	end

	// Generate store mask signals.  word_store_mask corresponds to lanes, byte_store_mask
	// corresponds to bytes within a word.  Note that byte_store_mask will always
	// have all bits set if word_store_mask has more than one bit set. That is:
	// we are either selecting some number of words within the cache line for
	// a vector transfer or some bytes within a specific word for a scalar transfer.
	genvar mask_idx;
	generate
		for (mask_idx = 0; mask_idx < `CACHE_LINE_BYTES; mask_idx++)
		begin : genmask
			assign dcache_store_mask[mask_idx] = word_store_mask[mask_idx / 4]
				& byte_store_mask[mask_idx & 3];
		end
	endgenerate

	one_hot_to_index #(.NUM_SIGNALS(`L1D_WAYS)) encode_hit_way(
		.one_hot(way_hit_oh),
		.index(way_hit_idx));
		
	assign cache_data_store_en = rc_ddata_update_en || (dcache_access_req && cache_hit 
		&& dcache_store_req && (dt_instruction.memory_access_type != MEM_SYNC || sync_store_success));
	sram_2r1w #(
		.DATA_WIDTH(`CACHE_LINE_BITS), 
		.SIZE(`L1D_WAYS * `L1D_SETS),
		.ENABLE_BYTE_LANES(1)
	) l1d_data(
		// From interconnect
		.read1_en(rc_ddata_read_en),
		.read1_addr({rc_ddata_read_way, rc_ddata_read_set}),
		.read1_data(dd_ddata_read_data),

		// Instruction pipeline access.  Note that there is only one store port that is shared by the
		// interconnect.  If there is contention, the interconnect will will and the thread will be
		// rolled back.
		.read2_en(cache_hit && dcache_read_req),
		.read2_addr({way_hit_idx, dt_request_addr.set_idx}),
		.read2_data(dd_read_data),
		.write_en(cache_data_store_en),	
		.write_addr(rc_ddata_update_en ? {rc_ddata_update_way, rc_ddata_update_set} : {way_hit_idx, dt_request_addr.set_idx}),
		.write_data(rc_ddata_update_en ? rc_ddata_update_data : dcache_store_data),
		.write_byte_en(rc_ddata_update_en ? 64'hffffffff_ffffffff : dcache_store_mask),
		.*);

	// Cache miss occured in the cycle the same line is being filled. If we suspend the thread here,
	// it will never receive a wakeup. Instead, just roll the thread back and let it retry.
	assign cache_near_miss = !cache_hit && dcache_access_req && |rc_dtag_update_en_oh
		&& rc_dtag_update_set == dt_request_addr.set_idx && rc_dtag_update_tag == dt_request_addr.tag; 

	assign dd_cache_miss = !cache_hit && dcache_access_req && !cache_near_miss;
	assign dd_cache_miss_addr = dcache_request_addr;
	assign dd_cache_miss_store = dcache_store_req;
	assign dd_cache_miss_thread_idx = dt_thread_idx;

	// Update pseudo-LRU bits so bits along the path to this leaf point in the
	// opposite direction. Explanation of this algorithm in dcache_tag_stage.
	assign dd_update_lru_en = cache_hit && dcache_access_req;
	assign dd_update_lru_set = dt_request_addr.set_idx;
	always_comb
	begin
		unique case (way_hit_idx)
			2'd0: dd_update_lru_flags = { 2'b11, dt_lru_flags[0] };
			2'd1: dd_update_lru_flags = { 2'b01, dt_lru_flags[0] };
			2'd2: dd_update_lru_flags = { dt_lru_flags[2], 2'b01 };
			2'd3: dd_update_lru_flags = { dt_lru_flags[2], 2'b00 };
		endcase
	end

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			for (int i = 0; i < `THREADS_PER_CORE; i++)
				latched_atomic_address[i] <= 32'hffffffff;	// Invalid address
		
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			dd_dcache_wait_oh <= {(1+(`THREADS_PER_CORE-1)){1'b0}};
			dd_instruction <= 1'h0;
			dd_instruction_valid <= 1'h0;
			dd_mask_value <= {(1+(`VECTOR_LANES-1)){1'b0}};
			dd_request_addr <= 1'h0;
			dd_rollback_en <= 1'h0;
			dd_rollback_pc <= 1'h0;
			dd_subcycle <= 1'h0;
			dd_sync_store_success <= 1'h0;
			dd_thread_idx <= 1'h0;
			// End of automatics
		end
		else
		begin
			dd_instruction_valid <= dt_instruction_valid && !rollback_this_stage;
			dd_instruction <= dt_instruction;
			dd_mask_value <= dt_mask_value;
			dd_thread_idx <= dt_thread_idx;
			dd_request_addr <= dt_request_addr;
			dd_subcycle <= dt_subcycle;
			dd_rollback_pc <= dt_instruction.pc;

			assert(!dcache_access_req || $onehot0(way_hit_oh));
			
			// Suspend the thread if there is a cache miss.
			// In the near miss case (described above), don't suspend thread.
			dd_dcache_wait_oh <= (dcache_access_req && !cache_hit && !cache_near_miss) ? thread_oh : 0;
			
			// Roll back if there is a cache miss or if the interconnect is writing to memory
			// If there is only contention, the thread will be rolled back, but not suspended.
			// It will try again when the thread is restarted.
			dd_rollback_en <= dcache_access_req && (!cache_hit || (rc_ddata_update_en && dcache_store_req));
			
			if (is_io_address && dt_instruction_valid && dt_instruction.is_memory_access && !dt_instruction.is_load)
				$write("%c", dt_store_value[0][7:0]);
				
			// Handling for atomic memory operations
			dd_sync_store_success <= sync_store_success;

			// XXX This should not check sync_store_success if this is not a synchronized store.
			// It needs to invalidate the address for normal writes. 
			// XXX It should also invalidate the address if the cache line is evicted or if a write 
			// invalidate from another core is received.
			if (dcache_store_req && sync_store_success)
			begin
				// Invalidate latched addresses
				for (int i = 0; i < `THREADS_PER_CORE; i++)
					if (latched_atomic_address[i] == dcache_request_addr)
						latched_atomic_address[i] <= 32'hffffffff;
			end

			if (dcache_read_req && dt_instruction.memory_access_type == MEM_SYNC)
				latched_atomic_address[dt_thread_idx] <= dcache_request_addr;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
