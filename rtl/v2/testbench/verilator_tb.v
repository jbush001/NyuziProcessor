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

`include "../core/defines.v"

module top(input clk, input reset);

	scalar_t SIM_icache_request_addr;
	scalar_t SIM_icache_data;

	int mem_dump_start;
	int mem_dump_length;
	logic processor_halt;
	reg[31:0] mem_dat;
	integer dump_fp;
	logic [`L1D_WAYS - 1:0] rc_dtag_update_en_oh;
	logic [`L1D_SET_INDEX_WIDTH - 1:0] rc_dtag_update_set;
	logic [`L1D_TAG_WIDTH - 1:0] rc_dtag_update_tag;
	cache_line_state_t rc_dtag_update_state;
	logic rc_ddata_update_en;
	logic [`L1D_WAY_INDEX_WIDTH - 1:0] rc_ddata_update_way;
	logic [`L1D_SET_INDEX_WIDTH - 1:0] rc_ddata_update_set;
	logic [`CACHE_LINE_BITS - 1:0] rc_ddata_update_data;
	logic [`THREADS_PER_CORE - 1:0] rc_dcache_wake_oh;
	logic dd_cache_miss;
	logic dd_cache_miss_store;
	logic rc_snoop_en;
	logic [`L1D_SET_INDEX_WIDTH - 1:0] rc_snoop_set;
	logic rc_ddata_read_en;
	logic [`L1D_SET_INDEX_WIDTH - 1:0] rc_ddata_read_set;
 	logic [`L1D_WAY_INDEX_WIDTH - 1:0] rc_ddata_read_way;
	logic [`CACHE_LINE_BITS - 1:0] dd_ddata_read_data;
	cache_line_state_t dt_snoop_state[`L1D_WAYS];
	logic [`L1D_TAG_WIDTH - 1:0] dt_snoop_tag[`L1D_WAYS];
	scalar_t dd_cache_miss_addr;
	thread_idx_t dd_cache_miss_thread_idx;

	instruction_pipeline instruction_pipeline(.*);

	typedef enum logic [1:0] {
		TE_INVALID = 0,
		TE_SWRITEBACK,
		TE_VWRITEBACK,
		TE_STORE
	} trace_event_type_t;
	
	typedef struct packed {
		trace_event_type_t event_type;
		scalar_t pc;
		thread_idx_t thread_idx;
		register_idx_t writeback_reg;
		scalar_t addr;
		logic[`CACHE_LINE_BYTES - 1:0] mask;
		vector_t data;
	} trace_event_t;
	
	// Used to simulate the L2 interconnect
	typedef struct packed {
		logic valid;
		logic [`L1D_TAG_WIDTH - 1:0] old_tag;
		logic [`L1D_TAG_WIDTH - 1:0] new_tag;
		logic [`L1D_SET_INDEX_WIDTH - 1:0] set_idx;
		logic [`L1D_WAY_INDEX_WIDTH - 1:0] way_idx;
		cache_line_state_t new_state;
		thread_idx_t thread;
		logic do_writeback;
	} cache_request_t;

	localparam MEM_SIZE = 'h500000;
	scalar_t sim_memory[MEM_SIZE];
	int total_cycles = 0;
	reg[1000:0] filename;
	int do_register_trace = 0;
	int finish_cycles = 0;
	cache_request_t cache_pipeline[3];
	int snoop_hit_way;
	int cache_load_way;

	localparam TRACE_REORDER_QUEUE_LEN = 7;
	trace_event_t trace_reorder_queue[TRACE_REORDER_QUEUE_LEN];
	
	initial
	begin
		for (int i = 0; i < TRACE_REORDER_QUEUE_LEN; i++)
			trace_reorder_queue[i] = 0;

		for (int i = 0; i < MEM_SIZE; i++)
			sim_memory[i] = 0;
			
		for (int i = 0; i < 3; i++)
			cache_pipeline[i] = 0;

		rc_dcache_wake_oh = 0;
	end

	task start_simulation;
	begin
		if ($value$plusargs("bin=%s", filename))
			$readmemh(filename, sim_memory);
		else
		begin
			$display("error opening file");
			$finish;
		end
	end
	endtask

// For fputw function, needed to write memory dumps
`systemc_header
#include "../testbench/verilator_include.h"	
`verilog

	task finish_simulation;
	begin
		$display("ran for %d cycles", total_cycles);
		flush_dcache;
		if ($value$plusargs("memdumpbase=%x", mem_dump_start)
			&& $value$plusargs("memdumplen=%x", mem_dump_length)
			&& $value$plusargs("memdumpfile=%s", filename))
		begin
			dump_fp = $fopen(filename, "wb");
			for (int i = 0; i < mem_dump_length; i += 4)
			begin
				mem_dat = sim_memory[(mem_dump_start + i) / 4];
				
				// fputw is defined in verilator_main.cpp and writes the
				// entire word out to the file.
				$c("fputw(", dump_fp, ",", mem_dat, ");");
			end

			$fclose(dump_fp);
		end	
	end
	endtask
	
	task flush_cache_line;
		input[31:0] address;
		input[`CACHE_LINE_BITS - 1:0] data;
	begin
		$display("flushing cache line @%x %x", address, data);
		for (int i = 0; i < `CACHE_LINE_WORDS; i++)
			sim_memory[address * `CACHE_LINE_WORDS + i] = data[(`CACHE_LINE_WORDS - 1 - i) * 32+:32];
	end
	endtask
	
	task flush_dcache;
	begin
		scalar_t address;
		logic[`L1D_SET_INDEX_WIDTH - 1:0] set_idx;
	
		for (int _set = 0; _set < `L1D_SETS; _set++)
		begin
			set_idx = _set;

			// XXX unfortunately, SystemVerilog does not allow non-constant references to generate
			// blocks, so this code is repeated with different way indices.hex
			if (instruction_pipeline.dcache_tag_stage.way_tags[0].line_states[set_idx] == STATE_MODIFIED)
			begin
				flush_cache_line({instruction_pipeline.dcache_tag_stage.way_tags[0].tag_ram.data[set_idx],
					set_idx}, instruction_pipeline.dcache_data_stage.l1d_data.data[{2'd0, set_idx}]);
			end

			if (instruction_pipeline.dcache_tag_stage.way_tags[1].line_states[set_idx] == STATE_MODIFIED)
			begin
				flush_cache_line({instruction_pipeline.dcache_tag_stage.way_tags[1].tag_ram.data[set_idx],
					set_idx}, instruction_pipeline.dcache_data_stage.l1d_data.data[{2'd1, set_idx}]);
			end

			if (instruction_pipeline.dcache_tag_stage.way_tags[2].line_states[set_idx] == STATE_MODIFIED)
			begin
				flush_cache_line({instruction_pipeline.dcache_tag_stage.way_tags[2].tag_ram.data[set_idx],
					set_idx}, instruction_pipeline.dcache_data_stage.l1d_data.data[{2'd2, set_idx}]);
			end

			if (instruction_pipeline.dcache_tag_stage.way_tags[3].line_states[set_idx] == STATE_MODIFIED)
			begin
				flush_cache_line({instruction_pipeline.dcache_tag_stage.way_tags[3].tag_ram.data[set_idx],
					set_idx}, instruction_pipeline.dcache_data_stage.l1d_data.data[{2'd3, set_idx}]);
			end
		end		
	end
	endtask
	
	function [31:0] mask_data;
		input[31:0] new_value;
		input[31:0] old_value;
		input[3:0] mask_in;
	begin	
		mask_data = { 
			mask_in[3] ? new_value[31:24] : old_value[31:24],
			mask_in[2] ? new_value[23:16] : old_value[23:16],
			mask_in[1] ? new_value[15:8] : old_value[15:8],
			mask_in[0] ? new_value[7:0] : old_value[7:0]
		};
	end
	endfunction
	
	initial
	begin
		if (!$value$plusargs("regtrace=%d", do_register_trace))
			do_register_trace = 0;
	end

	//
	// L2 cache miss pipeline
	//
	
	// Stage 1: Request existing tag
	assign rc_snoop_en = cache_pipeline[0].valid;
	assign rc_snoop_set = cache_pipeline[0].set_idx;

	// Stage 2: Update tag memory
	always_comb
	begin
		snoop_hit_way = -1;
		for (int way = 0; way < `L1D_WAYS; way++)
		begin
			if (dt_snoop_tag[way] == cache_pipeline[1].new_tag && dt_snoop_state[way] != STATE_INVALID)
			begin
				snoop_hit_way = way;
				break;
			end
		end

		if (snoop_hit_way != -1)
			cache_load_way = snoop_hit_way;
		else
			cache_load_way = $random() & 3;
	end

	always_comb
	begin
		for (int i = 0; i < `L1D_WAYS; i++)
			rc_dtag_update_en_oh[i] = cache_pipeline[1].valid && cache_load_way == i;
	end

	assign rc_dtag_update_set = cache_pipeline[1].set_idx;
	assign rc_dtag_update_tag = cache_pipeline[1].new_tag;
	assign rc_dtag_update_state = cache_pipeline[1].new_state;

	// Request old cache line (for writeback)
	assign rc_ddata_read_en = cache_pipeline[1].valid;
	assign rc_ddata_read_set = cache_pipeline[1].set_idx;
	assign rc_ddata_read_way = cache_load_way;

	// Stage 3: Update L1 cache line
	assign rc_ddata_update_en = cache_pipeline[2].valid;
	assign rc_ddata_update_way = cache_pipeline[2].way_idx;
	assign rc_ddata_update_set = cache_pipeline[2].set_idx;
	always_comb
	begin
		// Read data from main memory and push to L1 cache
		if (rc_ddata_update_en)
		begin
			for (int i = 0; i < `CACHE_LINE_WORDS; i++)
			begin
				rc_ddata_update_data[32 * (`CACHE_LINE_WORDS - 1 - i)+:32] = sim_memory[{cache_pipeline[2].new_tag, 
					cache_pipeline[2].set_idx, 4'd0} + i];
			end
		end
	end
	
	always_ff @(posedge clk, posedge reset)
	begin : update
		int mem_index;
	
		total_cycles <= total_cycles + 1;
		if (total_cycles == 0)
			start_simulation;
		else if (processor_halt)
		begin
			// Flush instructino pipeline and reorder queue
			if (finish_cycles == 0)
				finish_cycles = 20;
			else if (finish_cycles == 1)
			begin
				$display("***HALTED***");
				finish_simulation;
				$finish;
			end
			else
				finish_cycles--;
		end

		// Instruction cache request
		SIM_icache_data <= sim_memory[SIM_icache_request_addr[31:2]];

		//
		// Data cache miss pipeline (emulates ring interface)
		//
		cache_pipeline[0].valid <= dd_cache_miss;
		cache_pipeline[0].set_idx <= dd_cache_miss_addr[`CACHE_LINE_OFFSET_WIDTH+:`L1D_SET_INDEX_WIDTH];
		cache_pipeline[0].new_tag <= dd_cache_miss_addr[`CACHE_LINE_OFFSET_WIDTH + `L1D_SET_INDEX_WIDTH+:`L1D_TAG_WIDTH];
		cache_pipeline[0].new_state <= dd_cache_miss_store ? STATE_MODIFIED : STATE_SHARED;
		cache_pipeline[0].thread <= dd_cache_miss_thread_idx;
		cache_pipeline[1] <= cache_pipeline[0];
		cache_pipeline[2] <= cache_pipeline[1];
		cache_pipeline[2].way_idx <= cache_load_way;
		if (snoop_hit_way != -1)
		begin
			cache_pipeline[2].do_writeback <= 0;
			if (dt_snoop_state[snoop_hit_way] == STATE_MODIFIED)
				cache_pipeline[2].new_state <= STATE_MODIFIED;	// Don't clear modified state
		end
		else
		begin
			// Find a line to replace
			cache_pipeline[2].old_tag <= dt_snoop_tag[cache_load_way];
			cache_pipeline[2].do_writeback <= dt_snoop_state[cache_load_way] == STATE_MODIFIED;
		end

		rc_dcache_wake_oh <= cache_pipeline[2].valid ? (1 << cache_pipeline[2].thread) : 0;

		// Writeback old data to memory
		if (cache_pipeline[2].valid && cache_pipeline[2].do_writeback)
		begin
			for (int i = 0; i < `CACHE_LINE_WORDS; i++)
			begin
				sim_memory[{cache_pipeline[2].old_tag, cache_pipeline[2].set_idx, 4'd0} + i] = 
					dd_ddata_read_data[(`CACHE_LINE_WORDS - 1 - i) * 32+:32];
			end
		end

		//
		// Output cosimulation event dump. Instructions don't retire in the order they are issued.
		// This makes it hard to correlate with the functional simulator. To remedy this, we reorder
		// completed instructions so the events are emitted in issue order.
		//
		if (do_register_trace && !reset)
		begin
			case (trace_reorder_queue[0].event_type)
				TE_VWRITEBACK:
				begin
					$display("vwriteback %x %x %x %x %x",
						trace_reorder_queue[0].pc,
						trace_reorder_queue[0].thread_idx,
						trace_reorder_queue[0].writeback_reg,
						trace_reorder_queue[0].mask,
						trace_reorder_queue[0].data);
				end
				
				TE_SWRITEBACK:
				begin
					$display("swriteback %x %x %x %x",
						trace_reorder_queue[0].pc,
						trace_reorder_queue[0].thread_idx,
						trace_reorder_queue[0].writeback_reg,
						trace_reorder_queue[0].data[0]);
				end
				
				TE_STORE:
				begin
					$display("store %x %x %x %x %x",
						trace_reorder_queue[0].pc,
						trace_reorder_queue[0].thread_idx,
						trace_reorder_queue[0].addr,
						trace_reorder_queue[0].mask,
						trace_reorder_queue[0].data);
				end

				default:
					; // Do nothing
			endcase

			for (int i = 0; i < TRACE_REORDER_QUEUE_LEN - 1; i++)
				trace_reorder_queue[i] = trace_reorder_queue[i + 1];
				
			trace_reorder_queue[TRACE_REORDER_QUEUE_LEN - 1] = 0;

			// Note that we only record the memory event for a synchronized store, not the register
			// success value.
			if (instruction_pipeline.wb_writeback_en && !instruction_pipeline.writeback_stage.__debug_is_sync_store)
			begin : dumpwb
				int tindex;
		
				if (instruction_pipeline.writeback_stage.__debug_wb_pipeline == PIPE_SCYCLE_ARITH)
					tindex = 4;
				else if (instruction_pipeline.writeback_stage.__debug_wb_pipeline == PIPE_MEM)
					tindex = 3;
				else // Multicycle arithmetic
					tindex = 0;

				assert(trace_reorder_queue[tindex].event_type == TE_INVALID);
				if (instruction_pipeline.wb_writeback_is_vector)
					trace_reorder_queue[tindex].event_type = TE_VWRITEBACK;
				else
					trace_reorder_queue[tindex].event_type = TE_SWRITEBACK;

				trace_reorder_queue[tindex].pc = instruction_pipeline.writeback_stage.__debug_wb_pc - 4;
				trace_reorder_queue[tindex].thread_idx = instruction_pipeline.wb_writeback_thread_idx;
				trace_reorder_queue[tindex].writeback_reg = instruction_pipeline.wb_writeback_reg;
				trace_reorder_queue[tindex].mask = instruction_pipeline.wb_writeback_mask;
				trace_reorder_queue[tindex].data = instruction_pipeline.wb_writeback_value;
			end

			// Handle PC destination.
			if (instruction_pipeline.sx_instruction_valid 
				&& instruction_pipeline.sx_instruction.has_dest 
				&& instruction_pipeline.sx_instruction.dest_reg == `REG_PC
				&& !instruction_pipeline.sx_instruction.dest_is_vector)
			begin
				assert(trace_reorder_queue[5].event_type == TE_INVALID);
				trace_reorder_queue[5].event_type = TE_SWRITEBACK;
				trace_reorder_queue[5].pc = instruction_pipeline.sx_instruction.pc - 4;
				trace_reorder_queue[5].thread_idx = instruction_pipeline.wb_rollback_thread_idx;
				trace_reorder_queue[5].writeback_reg = 31;
				trace_reorder_queue[5].data[0] = instruction_pipeline.wb_rollback_pc;
			end
			else if (instruction_pipeline.dd_instruction_valid 
				&& instruction_pipeline.dd_instruction.has_dest 
				&& instruction_pipeline.dd_instruction.dest_reg == `REG_PC
				&& !instruction_pipeline.dd_instruction.dest_is_vector
				&& !instruction_pipeline.dd_rollback_en)
			begin
				assert(trace_reorder_queue[4].event_type == TE_INVALID);
				trace_reorder_queue[4].event_type = TE_SWRITEBACK;
				trace_reorder_queue[4].pc = instruction_pipeline.dd_instruction.pc - 4;
				trace_reorder_queue[4].thread_idx = instruction_pipeline.wb_rollback_thread_idx;
				trace_reorder_queue[4].writeback_reg = 31;
				trace_reorder_queue[4].data[0] = instruction_pipeline.wb_rollback_pc;
			end

			if (instruction_pipeline.dcache_data_stage.cache_data_store_en
				&& !rc_ddata_update_en)
			begin
				// This occurs one cycle before writeback, so put in zeroth entry
				assert(trace_reorder_queue[5].event_type == TE_INVALID);
				trace_reorder_queue[5].event_type = TE_STORE;
				trace_reorder_queue[5].pc = instruction_pipeline.dt_instruction.pc - 4;
				trace_reorder_queue[5].thread_idx = instruction_pipeline.dt_thread_idx;
				trace_reorder_queue[5].addr = {
					instruction_pipeline.dt_request_addr[31:`CACHE_LINE_OFFSET_WIDTH],
					{`CACHE_LINE_OFFSET_WIDTH{1'b0}}
				};
				trace_reorder_queue[5].mask = instruction_pipeline.dcache_data_stage.dcache_store_mask;
				trace_reorder_queue[5].data = instruction_pipeline.dcache_data_stage.dcache_store_data;
			end
		end
	end
		
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core")
// End:
