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
// Instruction Pipeline - Instruction Fetch Tag Stage
// - Select a program counter to fetch a thread for
// - Query instruction cache tag memory to determine if the cache line is resident
//

module ifetch_tag_stage(
	input                               clk,
	input                               reset,
	
	// To instruction fetch data stage
	output logic                        ift_instruction_requested,
	output l1i_addr_t                   ift_pc,
	output thread_idx_t                 ift_thread_idx,
	output l1i_tag_t                    ift_tag[`L1I_WAYS],
	output logic                        ift_valid[`L1I_WAYS],

	// from instruction fetch data stage
	input                               ifd_update_lru_en,
	input l1i_way_idx_t                 ifd_update_lru_way,
	input                               ifd_cache_miss,
	input                               ifd_near_miss,
	input thread_idx_t                  ifd_cache_miss_thread_idx,

	// From l2_interface
	input                               l2i_icache_lru_fill_en,
	input l1i_set_idx_t                 l2i_icache_lru_fill_set,
	input [`L1I_WAYS - 1:0]             l2i_itag_update_en_oh,
	input l1i_set_idx_t                 l2i_itag_update_set,
	input l1i_tag_t                     l2i_itag_update_tag,
	input                               l2i_itag_update_valid,
	input [`THREADS_PER_CORE - 1:0]     l2i_icache_wake_bitmap,
	output l1i_way_idx_t                ift_fill_lru,

	// From writeback stage
	input                               wb_rollback_en,
	input thread_idx_t                  wb_rollback_thread_idx,
	input scalar_t                      wb_rollback_pc,

	// From thread select stage
	input [`THREADS_PER_CORE - 1:0]     ts_fetch_en);

	scalar_t program_counter_ff[`THREADS_PER_CORE];
	scalar_t program_counter_nxt[`THREADS_PER_CORE];
	thread_idx_t selected_thread_idx;
	l1i_addr_t pc_to_fetch;
	scalar_t next_pc;
	logic[`THREADS_PER_CORE - 1:0] can_fetch_thread_bitmap;
	logic[`THREADS_PER_CORE - 1:0] selected_thread_oh;
	logic[`THREADS_PER_CORE - 1:0] last_selected_thread_oh;
	logic[`THREADS_PER_CORE - 1:0] icache_wait_threads;
	logic[`THREADS_PER_CORE - 1:0] icache_wait_threads_nxt;
	logic[`THREADS_PER_CORE - 1:0] cache_miss_thread_oh;
	logic[`THREADS_PER_CORE - 1:0] thread_sleep_mask_oh;

	//
	// Pick which thread to fetch next.
	//
	assign can_fetch_thread_bitmap = ts_fetch_en & ~icache_wait_threads & ~thread_sleep_mask_oh;

	arbiter #(.NUM_ENTRIES(`THREADS_PER_CORE)) arbiter_thread_select(
		.request(can_fetch_thread_bitmap),
		.update_lru(1'b1),
		.grant_oh(selected_thread_oh),
		.*);

	oh_to_idx #(.NUM_SIGNALS(`THREADS_PER_CORE)) oh_to_idx_selected_thread(
		.one_hot(selected_thread_oh),
		.index(selected_thread_idx));

	//
	// Update program counters
	// This is a bit subtle. If the last cycle was a cache hit, program_counter_ff points 
	// to the instruction that was just fetched.  If a cache miss occurred, it points to 
	// the next instruction that should be fetched. The next instruction address--be it a 
	// branch or the next sequential instruction--is always resolved in the next cycle after 
	// the address is issued, regardless of whether a cache hit or miss occurred.
	//
	genvar thread_idx;
	generate
		for (thread_idx = 0; thread_idx < `THREADS_PER_CORE; thread_idx++)
		begin : pc_logic_gen
			always_comb
			begin
				if (wb_rollback_en && wb_rollback_thread_idx == thread_idx)
					program_counter_nxt[thread_idx] = wb_rollback_pc;
				else if (ift_instruction_requested && !ifd_cache_miss && !ifd_near_miss 
					&& last_selected_thread_oh[thread_idx])
					program_counter_nxt[thread_idx] = program_counter_ff[thread_idx] + 4;
				else
					program_counter_nxt[thread_idx] = program_counter_ff[thread_idx];
			end
		end
	endgenerate

	assign pc_to_fetch = program_counter_nxt[selected_thread_idx];

	//
	// Cache way metadata
	//
	genvar way_idx;
	generate
		for (way_idx = 0; way_idx < `L1I_WAYS; way_idx++)
		begin : way_tag_gen
			logic line_valid[`L1I_SETS];

			sram_1r1w #(.DATA_WIDTH($bits(l1i_tag_t)), .SIZE(`L1I_SETS)) sram_tags(
				.read_en(|can_fetch_thread_bitmap),
				.read_addr(pc_to_fetch.set_idx),
				.read_data(ift_tag[way_idx]),
				.write_en(l2i_itag_update_en_oh[way_idx]),
				.write_addr(l2i_itag_update_set),
				.write_data(l2i_itag_update_tag),
				.*);

			always_ff @(posedge clk, posedge reset)
			begin
				if (reset)
				begin
					for (int set_idx = 0; set_idx < `L1I_SETS; set_idx++)
						line_valid[set_idx] <= 0;
				end
				else 
				begin
					if (l2i_itag_update_en_oh[way_idx])
						line_valid[l2i_itag_update_set] <= l2i_itag_update_valid;
					
					// Fetch cache line state for pipeline
					if (can_fetch_thread_bitmap != 0)
					begin
						if (l2i_itag_update_en_oh[way_idx] && l2i_itag_update_set == pc_to_fetch.set_idx)
							ift_valid[way_idx] <= l2i_itag_update_valid;	// Bypass
						else
							ift_valid[way_idx] <= line_valid[pc_to_fetch.set_idx];
					end
				end
			end
		end
	endgenerate

	cache_lru #(.NUM_WAYS(`L1D_WAYS), .NUM_SETS(`L1I_SETS)) cache_lru(
		.fill_en(l2i_icache_lru_fill_en),
		.fill_set(l2i_icache_lru_fill_set),
		.fill_way(ift_fill_lru),
		.access_en(|can_fetch_thread_bitmap),
		.access_set(pc_to_fetch.set_idx),
		.access_update_en(ifd_update_lru_en),
		.access_update_way(ifd_update_lru_way),
		.*);

	// 
	// Track which threads are waiting on instruction cache misses.  Avoid trying to 
	// fetch them from the instruction cache until their misses are fulfilled.
	// Note that there is no cancelling pending instruction cache misses.  If a thread 
	// faults on a miss and then is rolled back, it must still wait for that miss to be 
	// filled before restarting (othewise a race condition could exist when the response
	// came in for the original request)
	//
	idx_to_oh #(.NUM_SIGNALS(`THREADS_PER_CORE)) idx_to_oh_miss_thread(
		.one_hot(cache_miss_thread_oh),
		.index(ifd_cache_miss_thread_idx));

	assign thread_sleep_mask_oh = cache_miss_thread_oh & {`THREADS_PER_CORE{ifd_cache_miss}};
	assign icache_wait_threads_nxt = (icache_wait_threads | thread_sleep_mask_oh) & ~l2i_icache_wake_bitmap;

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			for (int i = 0; i < `THREADS_PER_CORE; i++)
				program_counter_ff[i] <= 0;
		
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			icache_wait_threads <= {(1+(`THREADS_PER_CORE-1)){1'b0}};
			ift_instruction_requested <= 1'h0;
			ift_pc <= 1'h0;
			ift_thread_idx <= 1'h0;
			last_selected_thread_oh <= {(1+(`THREADS_PER_CORE-1)){1'b0}};
			// End of automatics
		end
		else
		begin
			icache_wait_threads <= icache_wait_threads_nxt;
			ift_pc <= pc_to_fetch;
			ift_thread_idx <= selected_thread_idx;
			for (int i = 0; i < `THREADS_PER_CORE; i++)
				program_counter_ff[i] <= program_counter_nxt[i];			

			ift_instruction_requested <= |can_fetch_thread_bitmap;	
			last_selected_thread_oh <= selected_thread_oh;
			if (wb_rollback_en && (wb_rollback_pc == 0 || wb_rollback_pc[1:0] != 0))
			begin
				$display("thread %d rolled back to bad address %x", wb_rollback_thread_idx,
					wb_rollback_pc);
				$finish;
			end
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

