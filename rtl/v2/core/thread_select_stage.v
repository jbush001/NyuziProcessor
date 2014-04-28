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

module thread_select_stage(
	input                              clk,
	input                              reset,
	
	// From instruction decode stage
	input decoded_instruction_t        id_instruction,
	input                              id_instruction_valid,
	input thread_idx_t                 id_thread_idx,

	// To ifetch tag stage
	output [`THREADS_PER_CORE - 1:0]   ts_fetch_en,

	// To operand fetch stage
	output logic                       ts_instruction_valid,
	output decoded_instruction_t       ts_instruction,
	output thread_idx_t                ts_thread_idx,
	output subcycle_t                  ts_subcycle,
	
	// From writeback stage
	input logic                        wb_writeback_en,
	input thread_idx_t                 wb_writeback_thread_idx,
	input logic                        wb_writeback_is_vector,
	input register_idx_t               wb_writeback_reg,
	input logic                        wb_writeback_is_last_subcycle,

	// From control registers
	input logic[`THREADS_PER_CORE - 1:0] cr_thread_enable,
	
	// From rollback controller
	input thread_idx_t                 wb_rollback_thread_idx,
	input                              wb_rollback_en,
	input pipeline_sel_t               wb_rollback_pipeline,
	input subcycle_t                   wb_rollback_subcycle);

	localparam THREAD_FIFO_SIZE = 5;
	localparam ROLLBACK_STAGES = 4;	
	localparam WRITEBACK_ALLOC_STAGES = 4;

	decoded_instruction_t thread_instr_nxt[`THREADS_PER_CORE];
	decoded_instruction_t issue_instr;
	logic[`THREADS_PER_CORE - 1:0] can_issue_thread;
	logic[`THREADS_PER_CORE - 1:0] thread_issue_oh;
	thread_idx_t issue_thread_idx;
	logic[WRITEBACK_ALLOC_STAGES - 1:0] writeback_allocate;
	logic[WRITEBACK_ALLOC_STAGES - 1:0] writeback_allocate_nxt;
	subcycle_t current_subcycle[`THREADS_PER_CORE];
	logic instruction_complete[`THREADS_PER_CORE];
	
	// The scoreboard tracks registers that are busy (have a result pending), with one bit
	// per register.  Bits 0-31 are scalar registers and 32-63 are vector registers.
	logic[63:0] scoreboard[`THREADS_PER_CORE];
	logic[63:0] scoreboard_nxt[`THREADS_PER_CORE];
	logic[63:0] scoreboard_dest_bitmap[`THREADS_PER_CORE];

	// Track issued instructions so we can clear scoreboard entries on a rollback
	struct packed {
		logic valid;
		thread_idx_t thread_idx;
		logic[63:0] scoreboard_bitmap;
	} rollback_dest[ROLLBACK_STAGES];

	//
	// Per-thread instruction FIFOs & scoreboards
	//
	genvar thread_idx;
	generate
		for (thread_idx = 0; thread_idx < `THREADS_PER_CORE; thread_idx++)
		begin : thread_logic 
			logic ififo_almost_full;
			logic ififo_empty;
			logic[63:0] scoreboard_clear_bitmap;
			logic[63:0] scoreboard_dep_bitmap;
			logic[63:0] scoreboard_rollback_bitmap;
			decoded_instruction_t instr_nxt;
			logic writeback_conflict;
			logic[31:0] writeback_reg_oh;
			logic[31:0] dest_reg_oh;
			logic[31:0] vector1_oh;
			logic[31:0] vector2_oh;
			logic[31:0] scalar1_oh;
			logic[31:0] scalar2_oh;
			
			sync_fifo #(
				.DATA_WIDTH($bits(id_instruction)), 
				.NUM_ENTRIES(THREAD_FIFO_SIZE), 
				.ALMOST_FULL_THRESHOLD(3) 
			) instruction_fifo(
				.flush_en(wb_rollback_en && wb_rollback_thread_idx == thread_idx),
				.full(),
				.almost_full(ififo_almost_full),
				.enqueue_en(id_instruction_valid && id_thread_idx == thread_idx),
				.value_i(id_instruction),
				.empty(ififo_empty),
				.almost_empty(),
				.dequeue_en(instruction_complete[thread_idx]),
				.value_o(thread_instr_nxt[thread_idx]),
				.*);

			assign instruction_complete[thread_idx] = thread_issue_oh[thread_idx] 
				&& current_subcycle[thread_idx] == thread_instr_nxt[thread_idx].last_subcycle;
			assign instr_nxt = thread_instr_nxt[thread_idx];

			// This signal goes back to the thread fetch stage to enable fetching more
			// instructions. We need to deassert fetch enable a few cycles before the FIFO 
			// fills up becausee there are several stages in-between.
			assign ts_fetch_en[thread_idx] = !ififo_almost_full && cr_thread_enable[thread_idx];

			/// XXX PC needs to be treated specially for scoreboard...

			index_to_one_hot #(.NUM_SIGNALS(32)) convert_vec_writeback(
				.one_hot(writeback_reg_oh),
				.index(wb_writeback_reg));

			// Determine which bits to clear
			always_comb
			begin
				// Clear scoreboard entries to completed instructions. We only do this on the
				// last subcycle of an instruction (since we don't wait on the scoreboard to 
				// issue intermediate subcycles, we must do this for correctness)
				scoreboard_clear_bitmap = 0;
				if (wb_writeback_en && wb_writeback_thread_idx == thread_idx && wb_writeback_is_last_subcycle)
				begin
					if (wb_writeback_is_vector)
						scoreboard_clear_bitmap = { writeback_reg_oh, 32'd0 };
					else
						scoreboard_clear_bitmap = { 32'd0, writeback_reg_oh };
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

			// Set bitmap for destination register.
			index_to_one_hot #(.NUM_SIGNALS(32)) convert_dest(
				.one_hot(dest_reg_oh),
				.index(instr_nxt.dest_reg));

			always_comb
			begin
				scoreboard_dest_bitmap[thread_idx] = 0;
				
				// Clear scoreboard entries for retired instructions
				if (instr_nxt.has_dest)
				begin
					if (instr_nxt.dest_is_vector)
						scoreboard_dest_bitmap[thread_idx] = { dest_reg_oh, 32'd0 };
					else
						scoreboard_dest_bitmap[thread_idx] = { 32'd0, dest_reg_oh };
				end
			end

			// Generate scoreboard dependency bitmap for next instruction to be issued.
			// This includes both source registers (to detect RAW dependencies) and
			// the destination register (to handle WAW and WAR dependencies)
			index_to_one_hot #(.NUM_SIGNALS(32)) convert_scalar1(
				.one_hot(scalar1_oh),
				.index(instr_nxt.scalar_sel1));

			index_to_one_hot #(.NUM_SIGNALS(32)) convert_scalar2(
				.one_hot(scalar2_oh),
				.index(instr_nxt.scalar_sel2));

			index_to_one_hot #(.NUM_SIGNALS(32)) convert_vector1(
				.one_hot(vector1_oh),
				.index(instr_nxt.vector_sel1));

			index_to_one_hot #(.NUM_SIGNALS(32)) convert_vector2(
				.one_hot(vector2_oh),
				.index(instr_nxt.vector_sel2));


			always_comb
			begin
				scoreboard_dep_bitmap = scoreboard_dest_bitmap[thread_idx];
				if (instr_nxt.has_scalar1)
					scoreboard_dep_bitmap[31:0] |= scalar1_oh;
					
				if (instr_nxt.has_scalar2)
					scoreboard_dep_bitmap[31:0] |= scalar2_oh;
					
				if (instr_nxt.has_vector1)
					scoreboard_dep_bitmap[63:32] |= vector1_oh;

				if (instr_nxt.has_vector2)
					scoreboard_dep_bitmap[63:32] |= vector2_oh;
			end

			always_comb
			begin
				// Note that there is a writeback conflict even if the instruction doesn't 
				// write back to a register (it cause a rollback, for example)
				writeback_conflict = 0;
				case (instr_nxt.pipeline_sel)
					PIPE_SCYCLE_ARITH: writeback_conflict = writeback_allocate[0];
					PIPE_MEM: writeback_conflict = writeback_allocate[1];
				endcase
			end

			// Note that we only check the scoreboard on the first subcycle. The scoreboard only checks
			// on the register granularity, not individual vector lanes. In most cases, this is fine, but
			// with a multi-cycle operation (like a gather load), which writes back to the same register
			// multiple times, this would delay the load.  
			assign can_issue_thread[thread_idx] = !ififo_empty
				&& ((scoreboard[thread_idx] & scoreboard_dep_bitmap) == 0 || current_subcycle[thread_idx] != 0)
				&& cr_thread_enable[thread_idx]
				&& (!wb_rollback_en || wb_rollback_thread_idx != thread_idx)
				&& !writeback_conflict;

			// Update scoreboard.
			assign scoreboard_nxt[thread_idx] = (scoreboard[thread_idx] & ~scoreboard_clear_bitmap)
				| (thread_issue_oh[thread_idx] ? scoreboard_dest_bitmap[thread_idx]  : 0);
		end
	endgenerate
	
	// At the writeback stage, pipelines of different lengths merge.  This causes a structural
	// hazard, because two instructions issued in different cycles can arrive in the same cycle.
	// We manage this by never scheduling instructions that can conflict.  Track instruction 
	// arrival here for that purpose (note that instructions have other side effects than 
	// just updating registers, so we set the bit even if the instruction doesn't have a 
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

	one_hot_to_index #(.NUM_SIGNALS(`THREADS_PER_CORE)) thread_oh_to_idx(
		.one_hot(thread_issue_oh),
		.index(issue_thread_idx));

	assign issue_instr = thread_instr_nxt[issue_thread_idx];

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			ts_instruction <= 0;
			for (int i = 0; i < `THREADS_PER_CORE; i++)
			begin
				scoreboard[i] <= 0;
				current_subcycle[i] <= 0;
			end
				
			for (int i = 0; i < ROLLBACK_STAGES; i++)
				rollback_dest[i].valid <= 0;

			ts_instruction_valid <= 0;
			ts_thread_idx <= 0;
			writeback_allocate <= 0;
		end
		else
		begin
			ts_instruction <= issue_instr;
			ts_instruction_valid <= |thread_issue_oh;
			ts_thread_idx <= issue_thread_idx;
			ts_subcycle <= current_subcycle[issue_thread_idx];
			for (int thread_idx = 0; thread_idx < `THREADS_PER_CORE; thread_idx++)
			begin
				scoreboard[thread_idx] <= scoreboard_nxt[thread_idx];
				if (wb_rollback_en && wb_rollback_thread_idx == thread_idx)
					current_subcycle[thread_idx] <= wb_rollback_subcycle;
				else if (instruction_complete[thread_idx])
					current_subcycle[thread_idx] <= 0;
				else if (thread_issue_oh[thread_idx])
					current_subcycle[thread_idx] <= current_subcycle[thread_idx] + 1;
					
				assert(current_subcycle[thread_idx] <= thread_instr_nxt[thread_idx].last_subcycle);
			end

			// Track issued instructions for scoreboard clearing
			for (int i = 1; i < ROLLBACK_STAGES; i++)
			begin
				if (rollback_dest[i - 1].thread_idx == wb_rollback_thread_idx
					&& wb_rollback_en)
					rollback_dest[i].valid <= 0;	// Clear rolled back instruction
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
