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
// Instruction Pipeline -  Instruction Fetch Tag Stage
// - Select a program counter to fetch a thread for
// - Query instruction cache tag memory to determine if the cache line is resident
//
module ifetch_tag_stage(
	input                               clk,
	input                               reset,
	
	// To instruction fetch data stage
	output logic                        ift_cache_hit,
	output scalar_t                     ift_pc,
	output thread_idx_t                 ift_thread_idx,

	// From rollback stage
	input                               wb_rollback_en,
	input thread_idx_t                  wb_rollback_thread_idx,
	input scalar_t                      wb_rollback_pc,

	// From thread select stage
	input [`THREADS_PER_CORE - 1:0]     ts_fetch_en);

	scalar_t program_counter_ff[`THREADS_PER_CORE];
	scalar_t program_counter_nxt[`THREADS_PER_CORE];
	thread_idx_t selected_thread_idx;
	scalar_t pc_to_fetch;
	scalar_t next_pc;
	logic[`THREADS_PER_CORE - 1:0] can_fetch_thread;
	logic[`THREADS_PER_CORE - 1:0] selected_thread_oh;
	logic[`THREADS_PER_CORE - 1:0] last_selected_thread_oh;

	//
	// Pick which thread to fetch next
	//
	assign can_fetch_thread = ts_fetch_en;	// XXX will also track if there are outstanding icache misses

	arbiter #(.NUM_ENTRIES(`THREADS_PER_CORE)) thread_select_arbiter(
		.request(can_fetch_thread),
		.update_lru(1'b1),
		.grant_oh(selected_thread_oh),
		.*);

	one_hot_to_index #(.NUM_SIGNALS(`THREADS_PER_CORE)) thread_oh_to_idx(
		.one_hot(selected_thread_oh),
		.index(selected_thread_idx));

	assign pc_to_fetch = program_counter_nxt[selected_thread_idx];
	
	//
	// Update program counters
	//
	genvar thread_idx;
	generate
		for (thread_idx = 0; thread_idx < `THREADS_PER_CORE; thread_idx++)
		begin : thread_logic
			always_comb
			begin
				if (wb_rollback_en && wb_rollback_thread_idx == thread_idx)
					program_counter_nxt[thread_idx] = wb_rollback_pc;
				else if (last_selected_thread_oh[thread_idx])	// Note: delayed one cycle
					program_counter_nxt[thread_idx] = program_counter_ff[thread_idx] + 4;
				else
					program_counter_nxt[thread_idx] = program_counter_ff[thread_idx];
			end
		end
	endgenerate

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			for (int i = 0; i < `THREADS_PER_CORE; i++)
				program_counter_ff[i] <= 0;
		
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			ift_cache_hit <= 1'h0;
			ift_pc <= 1'h0;
			ift_thread_idx <= 1'h0;
			last_selected_thread_oh <= {(1+(`THREADS_PER_CORE-1)){1'b0}};
			// End of automatics
		end
		else
		begin
			ift_pc <= pc_to_fetch;
			ift_thread_idx <= selected_thread_idx;
			for (int i = 0; i < `THREADS_PER_CORE; i++)
				program_counter_ff[i] <= program_counter_nxt[i];			

			ift_cache_hit <= can_fetch_thread[selected_thread_idx];	// XXX is any thread available...
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

