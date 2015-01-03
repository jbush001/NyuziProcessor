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
// Instruction Pipeline Thread Select Stage
// - Contains an instruction FIFO for each thread
// - Each cycle, picks a thread to issue using a round robin scheduling algorithm,
//   avoid various types of conflicts:
//   * inter-instruction register dependencies, tracked using a per-thread scoreboard 
//   * writeback hazards between the pipelines of different lengths
// - Tracks dcache misses and suspends threads until they are resolved.
//

module thread_select_stage(
	input                              clk,
	input                              reset,
	
	// From instruction decode stage
	input decoded_instruction_t        id_instruction,
	input                              id_instruction_valid,
	input thread_idx_t                 id_thread_idx,

	// To ifetch tag stage
	output thread_bitmap_t             ts_fetch_en,

	// To operand fetch stage
	output logic                       ts_instruction_valid,
	output decoded_instruction_t       ts_instruction,
	output thread_idx_t                ts_thread_idx,
	output subcycle_t                  ts_subcycle,
	
	// From writeback stage
	input                              wb_writeback_en,
	input thread_idx_t                 wb_writeback_thread_idx,
	input                              wb_writeback_is_vector,
	input register_idx_t               wb_writeback_reg,
	input                              wb_writeback_is_last_subcycle,
	input thread_idx_t                 wb_rollback_thread_idx,
	input                              wb_rollback_en,
	input pipeline_sel_t               wb_rollback_pipeline,
	input subcycle_t                   wb_rollback_subcycle,

	// From control registers
	input thread_bitmap_t              cr_thread_enable,
	
	// From dcache data stage
	input thread_bitmap_t              wb_suspend_thread_oh,
	input thread_bitmap_t              l2i_dcache_wake_bitmap,
	input thread_bitmap_t              ior_wake_bitmap,
	
	// Performace counters
	output logic                       perf_instruction_issue);

	localparam THREAD_FIFO_SIZE = 8;
	
	// Number of stages in longest pipeline
	localparam ROLLBACK_STAGES = 5;

	// Difference between longest and shortest execution pipeline
	localparam WRITEBACK_ALLOC_STAGES = 4;	

	decoded_instruction_t thread_instr[`THREADS_PER_CORE];
	decoded_instruction_t issue_instr;
	thread_bitmap_t thread_blocked;
	thread_bitmap_t can_issue_thread;
	thread_bitmap_t thread_issue_oh;
	thread_idx_t issue_thread_idx;
	logic[WRITEBACK_ALLOC_STAGES - 1:0] writeback_allocate;
	logic[WRITEBACK_ALLOC_STAGES - 1:0] writeback_allocate_nxt;
	subcycle_t current_subcycle[`THREADS_PER_CORE];
	logic instruction_complete[`THREADS_PER_CORE];
	
	// The scoreboard tracks registers that are busy (have a result pending), with one bit
	// per register.  Bits 0-31 are scalar registers and 32-63 are vector registers.
	logic[`NUM_REGISTERS * 2 - 1:0] scoreboard[`THREADS_PER_CORE];
	logic[`NUM_REGISTERS * 2 - 1:0] scoreboard_nxt[`THREADS_PER_CORE];
	logic[`NUM_REGISTERS * 2 - 1:0] scoreboard_dest_bitmap[`THREADS_PER_CORE];

	// Track issued instructions so we can clear scoreboard entries on a rollback
	struct packed {
		logic valid;
		thread_idx_t thread_idx;
		logic[`NUM_REGISTERS * 2 - 1:0] scoreboard_bitmap;
	} rollback_dest[ROLLBACK_STAGES];

`ifdef SIMULATION
	// Used for visualizer app
	enum logic[2:0] {
		TS_WAIT_ICACHE = 0,
		TS_WAIT_DCACHE = 1,
		TS_WAIT_RAW = 2,
		TS_WAIT_WRITEBACK_CONFLICT = 3,
		TS_READY = 4
	} thread_state[`THREADS_PER_CORE];
`endif

	//
	// Per-thread instruction FIFOs & scoreboards
	//
	genvar thread_idx;
	generate
		for (thread_idx = 0; thread_idx < `THREADS_PER_CORE; thread_idx++)
		begin : thread_logic_gen
			logic ififo_almost_full;
			logic ififo_empty;
			logic[`NUM_REGISTERS * 2 - 1:0] scoreboard_clear_bitmap;
			logic[`NUM_REGISTERS * 2 - 1:0] scoreboard_dep_bitmap;
			logic[`NUM_REGISTERS * 2 - 1:0] scoreboard_rollback_bitmap;
			logic[`NUM_REGISTERS * 2 - 1:0] scoreboard_dep_bitmap_nxt;
			logic[`NUM_REGISTERS * 2 - 1:0] scoreboard_dest_bitmap_nxt;
			decoded_instruction_t thread_instr_nxt;
			logic instruction_latched;
			logic writeback_conflict;
			logic rollback_this_thread;
			logic instruction_latch_en;
			
			assign rollback_this_thread = wb_rollback_en && wb_rollback_thread_idx == thread_idx;
			
			sync_fifo #(
				.WIDTH($bits(id_instruction)), 
				.SIZE(THREAD_FIFO_SIZE), 
				.ALMOST_FULL_THRESHOLD(THREAD_FIFO_SIZE - 3) 
			) instruction_fifo(
				.flush_en(rollback_this_thread),
				.full(),
				.almost_full(ififo_almost_full),
				.enqueue_en(id_instruction_valid && id_thread_idx == thread_idx),
				.value_i(id_instruction),
				.empty(ififo_empty),
				.almost_empty(),
				.dequeue_en(instruction_latch_en),
				.value_o(thread_instr_nxt),
				.*);

			assign instruction_complete[thread_idx] = thread_issue_oh[thread_idx] 
				&& current_subcycle[thread_idx] == thread_instr[thread_idx].last_subcycle;

			// This signal goes back to the thread fetch stage to enable fetching more
			// instructions. We need to deassert fetch enable a few cycles before the FIFO 
			// fills up becausee there are several stages in-between.
			assign ts_fetch_en[thread_idx] = !ififo_almost_full && cr_thread_enable[thread_idx];

			/// XXX PC needs to be treated specially for scoreboard?

			// Generate destination bitmap for the next instruction to be issued.
			always_comb
			begin
				scoreboard_dest_bitmap_nxt = 0;
				if (thread_instr_nxt.has_dest)
				begin
					if (thread_instr_nxt.dest_is_vector)
						scoreboard_dest_bitmap_nxt[thread_instr_nxt.dest_reg + 32] = 1;
					else
						scoreboard_dest_bitmap_nxt[thread_instr_nxt.dest_reg] = 1;
				end
			end

			// Generate scoreboard dependency bitmap for next instruction to be issued.
			// This includes both source registers (to detect RAW dependencies) and
			// the destination register (to handle WAW and WAR dependencies)
			always_comb
			begin
				scoreboard_dep_bitmap_nxt = 0;
				if (thread_instr_nxt.has_dest)
				begin
					if (thread_instr_nxt.dest_is_vector)
						scoreboard_dep_bitmap_nxt[thread_instr_nxt.dest_reg + 32] = 1;
					else
						scoreboard_dep_bitmap_nxt[thread_instr_nxt.dest_reg] = 1;
				end

				if (thread_instr_nxt.has_scalar1)
					scoreboard_dep_bitmap_nxt[thread_instr_nxt.scalar_sel1] = 1;
					
				if (thread_instr_nxt.has_scalar2)
					scoreboard_dep_bitmap_nxt[thread_instr_nxt.scalar_sel2] = 1;
					
				if (thread_instr_nxt.has_vector1)
					scoreboard_dep_bitmap_nxt[thread_instr_nxt.vector_sel1 + 32] = 1;

				if (thread_instr_nxt.has_vector2)
					scoreboard_dep_bitmap_nxt[thread_instr_nxt.vector_sel2 + 32] = 1;
			end
			
			// There is one cycle of latency after the instruction comes out of the
			// instruction FIFO to determine the scoreboard values.  They are
			// registered here.
			assign instruction_latch_en = !ififo_empty && (!instruction_latched 
				|| instruction_complete[thread_idx]);
			
			always_ff @(posedge clk, posedge reset)
			begin
				if (reset)
				begin
					instruction_latched <= 0;
					thread_instr[thread_idx] <= 0;
					scoreboard_dep_bitmap <= 0;
					scoreboard_dest_bitmap[thread_idx] <= 0;
				end
				else
				begin
					if (rollback_this_thread)
						instruction_latched <= 0;
					else if (instruction_latch_en)
					begin
						// Latch a new instruction
						instruction_latched <= 1;
						thread_instr[thread_idx] <= thread_instr_nxt;
						scoreboard_dep_bitmap <= scoreboard_dep_bitmap_nxt;
						scoreboard_dest_bitmap[thread_idx] <= scoreboard_dest_bitmap_nxt;
					end
					else if (instruction_complete[thread_idx])
						instruction_latched <= 0;	// Clear instruction
				end
			end

			// Determine which scoreboard bits to clear
			always_comb
			begin
				// Clear scoreboard entries to completed instructions. We only do this on the
				// last subcycle of an instruction (since we don't wait on the scoreboard to 
				// issue intermediate subcycles, we must do this for correctness)
				scoreboard_clear_bitmap = 0;
				if (wb_writeback_en && wb_writeback_thread_idx == thread_idx 
					&& wb_writeback_is_last_subcycle)
				begin
					if (wb_writeback_is_vector)
						scoreboard_clear_bitmap[wb_writeback_reg + 32] = 1;
					else
						scoreboard_clear_bitmap[wb_writeback_reg] = 1;
				end
				
				// Clear scoreboard entries for rolled back threads. 
				if (wb_rollback_en && wb_rollback_thread_idx == thread_idx)
				begin
					for (int i = 0; i < ROLLBACK_STAGES - 1; i++)
					begin
						if (rollback_dest[i].valid && rollback_dest[i].thread_idx == thread_idx)
							scoreboard_clear_bitmap |= rollback_dest[i].scoreboard_bitmap;
					end
					
					// The memory pipeline is one stage longer than the single cycle arithmetic pipeline,
					// so only invalidate the last stage if this originated there.
					if (rollback_dest[ROLLBACK_STAGES - 1].valid 
						&& rollback_dest[ROLLBACK_STAGES - 1].thread_idx == thread_idx
						&& wb_rollback_pipeline == PIPE_MEM)
					begin
						scoreboard_clear_bitmap |= rollback_dest[ROLLBACK_STAGES - 1].scoreboard_bitmap;
					end
				end
			end

			always_comb
			begin
				// There can be a writeback conflict even if the instruction doesn't 
				// write back to a register (it cause a rollback, for example)
				unique case (thread_instr[thread_idx].pipeline_sel)
					PIPE_SCYCLE_ARITH: writeback_conflict = writeback_allocate[0];
					PIPE_MEM: writeback_conflict = writeback_allocate[1];
					default: writeback_conflict = 0;
				endcase
			end

			// We only check the scoreboard on the first subcycle. The scoreboard only checks
			// on the register granularity, not individual vector lanes. In most cases, this is fine, but
			// with a multi-cycle operation (like a gather load), which writes back to the same register
			// multiple times, this would delay the load.  
			assign can_issue_thread[thread_idx] = instruction_latched
				&& ((scoreboard[thread_idx] & scoreboard_dep_bitmap) == 0 || current_subcycle[thread_idx] != 0)
				&& cr_thread_enable[thread_idx]
				&& !rollback_this_thread
				&& !writeback_conflict
				&& !thread_blocked[thread_idx];

			// Update scoreboard.
			assign scoreboard_nxt[thread_idx] = (scoreboard[thread_idx] & ~scoreboard_clear_bitmap)
				| (thread_issue_oh[thread_idx] ? scoreboard_dest_bitmap[thread_idx]  : 0);

			always_ff @(posedge clk, posedge reset)
			begin
				if (reset)
				begin
					scoreboard[thread_idx] <= 0;
					current_subcycle[thread_idx] <= 0;
				end
				else
				begin
					scoreboard[thread_idx] <= scoreboard_nxt[thread_idx];
					if (wb_rollback_en && wb_rollback_thread_idx == thread_idx)
						current_subcycle[thread_idx] <= wb_rollback_subcycle;
					else if (instruction_complete[thread_idx])
						current_subcycle[thread_idx] <= 0;
					else if (thread_issue_oh[thread_idx])
						current_subcycle[thread_idx] <= current_subcycle[thread_idx] + 1;
				end
			end

`ifdef SIMULATION
			// Used for visualizer app. There can be multiple events that prevent
			// a thread from executing, but I picked a order that seemed logical
			// to prioritize them so there is only one "state."
			always_comb
			begin
				if (!instruction_latched)
					thread_state[thread_idx] = TS_WAIT_ICACHE;
				else if (thread_blocked[thread_idx])
					thread_state[thread_idx] = TS_WAIT_DCACHE;
				else if (can_issue_thread[thread_idx])
					thread_state[thread_idx] = TS_WAIT_RAW;
				else if (writeback_conflict)
					thread_state[thread_idx] = TS_WAIT_WRITEBACK_CONFLICT;
				else
					thread_state[thread_idx] = TS_READY;
			end
`endif
		end
	endgenerate
	
	// At the writeback stage, pipelines of different lengths merge.  This causes a structural
	// hazard, because two instructions issued in different cycles can arrive in the same cycle.
	// We manage this by never scheduling instructions that can conflict.  Track instruction 
	// arrival here for that purpose (instructions may have other side effects than 
	// updating registers, so we set the bit even if the instruction doesn't have a 
	// writeback register)
	always_comb
	begin
		writeback_allocate_nxt = {1'b0, writeback_allocate[WRITEBACK_ALLOC_STAGES - 1:1] };
		if (|thread_issue_oh)
		begin
			case (issue_instr.pipeline_sel)
				PIPE_MCYCLE_ARITH: writeback_allocate_nxt[3] = 1'b1;
				PIPE_MEM: writeback_allocate_nxt[0] = 1'b1;
			endcase
		end
	end

	// 
	// Choose which thread to issue
	//
	arbiter #(.NUM_ENTRIES(`THREADS_PER_CORE)) thread_select_arbiter(
		.request(can_issue_thread),
		.update_lru(1'b1),
		.grant_oh(thread_issue_oh),
		.*);

	oh_to_idx #(.NUM_SIGNALS(`THREADS_PER_CORE)) thread_oh_to_idx(
		.one_hot(thread_issue_oh),
		.index(issue_thread_idx));

	assign issue_instr = thread_instr[issue_thread_idx];
	assign perf_instruction_issue = |thread_issue_oh;

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			ts_instruction <= 0;
			for (int i = 0; i < ROLLBACK_STAGES; i++)
				rollback_dest[i].valid <= 0;
			
			`ifdef SUPPRESS_AUTORESET
			scoreboard_bitmap <= 64'h0;
			valid <= 1'h0;
			`endif

			thread_blocked <= 1'h0;
			ts_instruction_valid <= 1'h0;
			ts_subcycle <= 1'h0;
			ts_thread_idx <= 1'h0;
			writeback_allocate <= {WRITEBACK_ALLOC_STAGES{1'b0}};
		end
		else
		begin
			// Should not get a wake from l1 cache and io queue in the same cycle
			assert(!(l2i_dcache_wake_bitmap & ior_wake_bitmap));

			// Check for suspending a thread that isn't running
			assert((wb_suspend_thread_oh & thread_blocked) == 0);

			// Check for waking a thread that isn't suspended (or about to be suspended, see note below)
			assert(((l2i_dcache_wake_bitmap | ior_wake_bitmap) & ~(thread_blocked | wb_suspend_thread_oh)) == 0);

			// Don't issue blocked threads
			assert(!(thread_issue_oh & thread_blocked));

			// Only one thread should be blocked per cycle
			assert($onehot0(wb_suspend_thread_oh));

			ts_instruction <= issue_instr;
			ts_instruction_valid <= |thread_issue_oh;
			ts_thread_idx <= issue_thread_idx;
			ts_subcycle <= current_subcycle[issue_thread_idx];

			// The suspend signal is asserted a cycle after a dcache miss occurs.  It is possible
			// that that miss collides with a miss that was already pending, and in the next cycle,
			// that miss is fulfilled. In this case, suspend and wake will be asserted simultaneously 
			// and wake will win (because of the way this expression is ordered)
			thread_blocked <= (thread_blocked | wb_suspend_thread_oh) & ~(l2i_dcache_wake_bitmap
				| ior_wake_bitmap);

			// Track issued instructions for scoreboard clearing
			for (int i = 1; i < ROLLBACK_STAGES; i++)
			begin
				if (rollback_dest[i - 1].thread_idx == wb_rollback_thread_idx && wb_rollback_en)
					rollback_dest[i] <= 0;	// Clear rolled back instruction
				else
					rollback_dest[i] <= rollback_dest[i - 1]; // Shift down pipeline
			end

			rollback_dest[0].valid <= |thread_issue_oh && issue_instr.has_dest;
			rollback_dest[0].thread_idx <= issue_thread_idx;
			rollback_dest[0].scoreboard_bitmap <= scoreboard_dest_bitmap[issue_thread_idx];

			writeback_allocate <= writeback_allocate_nxt;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
