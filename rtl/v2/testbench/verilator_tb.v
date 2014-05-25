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

//`define WITH_MOCK_RING_CONTROLLER 1

//
// Testbench for CPU
//
module verilator_tb(
	input clk, 
	input reset);

	scalar_t SIM_icache_request_addr;
	scalar_t SIM_icache_data;

	int mem_dump_start;
	int mem_dump_length;
	logic processor_halt;
	reg[31:0] mem_dat;
	integer dump_fp;
	ring_packet_t packet0;
	ring_packet_t packet1;
	l1d_set_idx_t rc_dtag_update_set;
	l1d_tag_t rc_dtag_update_tag;
	l1d_way_idx_t rc_ddata_update_way;
	l1d_set_idx_t rc_ddata_update_set;
	l1d_set_idx_t rc_ddata_read_set;
 	l1d_way_idx_t rc_ddata_read_way;
	l1d_set_idx_t rc_snoop_set;
	l1i_set_idx_t rc_itag_update_set;
	l1i_tag_t rc_itag_update_tag;
	l1i_way_idx_t rc_idata_update_way;
	l1i_set_idx_t rc_idata_update_set;
	l1i_set_idx_t rc_ilru_read_set;
	cache_line_state_t rc_dtag_update_state;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire		dd_cache_miss;		// From instruction_pipeline of instruction_pipeline.v
	scalar_t	dd_cache_miss_addr;	// From instruction_pipeline of instruction_pipeline.v
	wire		dd_cache_miss_store;	// From instruction_pipeline of instruction_pipeline.v
	thread_idx_t	dd_cache_miss_thread_idx;// From instruction_pipeline of instruction_pipeline.v
	logic [`CACHE_LINE_BITS-1:0] dd_ddata_read_data;// From instruction_pipeline of instruction_pipeline.v
	l1d_way_idx_t	dt_snoop_lru;		// From instruction_pipeline of instruction_pipeline.v
	cache_line_state_t dt_snoop_state [`L1D_WAYS];// From instruction_pipeline of instruction_pipeline.v
	l1d_tag_t	dt_snoop_tag [`L1D_WAYS];// From instruction_pipeline of instruction_pipeline.v
	logic		ifd_cache_miss;		// From instruction_pipeline of instruction_pipeline.v
	scalar_t	ifd_cache_miss_addr;	// From instruction_pipeline of instruction_pipeline.v
	thread_idx_t	ifd_cache_miss_thread_idx;// From instruction_pipeline of instruction_pipeline.v
	l1i_way_idx_t	ift_lru;		// From instruction_pipeline of instruction_pipeline.v
	wire		perf_dcache_hit;	// From instruction_pipeline of instruction_pipeline.v
	wire		perf_dcache_miss;	// From instruction_pipeline of instruction_pipeline.v
	wire		perf_icache_hit;	// From instruction_pipeline of instruction_pipeline.v
	wire		perf_icache_miss;	// From instruction_pipeline of instruction_pipeline.v
	wire		perf_instruction_issue;	// From instruction_pipeline of instruction_pipeline.v
	wire		perf_instruction_retire;// From instruction_pipeline of instruction_pipeline.v
	wire [`THREADS_PER_CORE-1:0] rc_dcache_wake_oh;// From ring_controller_sim of ring_controller_sim.v
	logic		rc_ddata_read_en;	// From ring_controller_sim of ring_controller_sim.v
	wire [`CACHE_LINE_BITS-1:0] rc_ddata_update_data;// From ring_controller_sim of ring_controller_sim.v
	logic		rc_ddata_update_en;	// From ring_controller_sim of ring_controller_sim.v
	logic [`L1D_WAYS-1:0] rc_dtag_update_en_oh;// From ring_controller_sim of ring_controller_sim.v
	wire [`THREADS_PER_CORE-1:0] rc_icache_wake_oh;// From ring_controller_sim of ring_controller_sim.v
	wire [`CACHE_LINE_BITS-1:0] rc_idata_update_data;// From ring_controller_sim of ring_controller_sim.v
	logic		rc_idata_update_en;	// From ring_controller_sim of ring_controller_sim.v
	logic		rc_ilru_read_en;	// From ring_controller_sim of ring_controller_sim.v
	wire [`L1I_WAYS-1:0] rc_itag_update_en_oh;// From ring_controller_sim of ring_controller_sim.v
	logic		rc_itag_update_valid;	// From ring_controller_sim of ring_controller_sim.v
	logic		rc_snoop_en;		// From ring_controller_sim of ring_controller_sim.v
	// End of automatics

`ifdef WITH_MOCK_RING_CONTROLLER
	instruction_pipeline instruction_pipeline(.*);
	ring_controller_sim ring_controller_sim(.*);
	`define INST_PIPELINE instruction_pipeline
	`define MEMORY ring_controller_sim.memory
`else
	core core(
		.packet_in(packet1),
		.packet_out(packet0),
		.*);

	l2_cache_sim #(.MEM_SIZE('h500000)) l2_cache(
		.packet_in(packet0),
		.packet_out(packet1),
		.*);

	`define INST_PIPELINE core.instruction_pipeline
	`define MEMORY l2_cache.memory
`endif

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
	
	int total_cycles = 0;
	reg[1000:0] filename;
	int do_register_trace = 0;
	int finish_cycles = 0;

	localparam TRACE_REORDER_QUEUE_LEN = 7;
	trace_event_t trace_reorder_queue[TRACE_REORDER_QUEUE_LEN];
	
	initial
	begin
		for (int i = 0; i < TRACE_REORDER_QUEUE_LEN; i++)
			trace_reorder_queue[i] = 0;
	end

	task start_simulation;
	begin
		if ($value$plusargs("bin=%s", filename))
			$readmemh(filename, `MEMORY);
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
				mem_dat = `MEMORY[(mem_dump_start + i) / 4];
				
				// fputw is defined in verilator_main.cpp and writes the
				// entire word out to the file.
				$c("fputw(", dump_fp, ",", mem_dat, ");");
			end

			$fclose(dump_fp);
		end	

`ifndef WITH_MOCK_RING_CONTROLLER
		$display("performance counters:");
		$display(" l1d_miss              %d", core.performance_counters.event_counter[0]);
		$display(" l1d_hit               %d", core.performance_counters.event_counter[1]);
		$display(" l1i_miss              %d", core.performance_counters.event_counter[2]);
		$display(" l1i_hit               %d", core.performance_counters.event_counter[3]);
		$display(" instruction_issue     %d", core.performance_counters.event_counter[4]);
		$display(" instruction_retire    %d", core.performance_counters.event_counter[5]);
`endif
	end
	endtask
	
	task flush_cache_line;
		input[31:0] address;
		input[`CACHE_LINE_BITS - 1:0] data;
	begin
		for (int i = 0; i < `CACHE_LINE_WORDS; i++)
			`MEMORY[address * `CACHE_LINE_WORDS + i] = data[(`CACHE_LINE_WORDS - 1 - i) * 32+:32];
	end
	endtask
	
	//
	// Copy all dirty cache lines back to simulated memory. This is used for memory consistency 
	// checking in the cosimulation environment.
	//
	task flush_dcache;
	begin
		scalar_t address;
		l1d_set_idx_t set_idx;
	
		for (int _set = 0; _set < `L1D_SETS; _set++)
		begin
			set_idx = _set;

			// Unfortunately, SystemVerilog does not allow non-constant references to generate
			// blocks, so this code is repeated with different way indices.
			if (`INST_PIPELINE.dcache_tag_stage.way_tags[0].line_states[set_idx] == CL_STATE_MODIFIED)
			begin
				flush_cache_line({`INST_PIPELINE.dcache_tag_stage.way_tags[0].tag_ram.data[set_idx],
					set_idx}, `INST_PIPELINE.dcache_data_stage.l1d_data.data[{2'd0, set_idx}]);
			end

			if (`INST_PIPELINE.dcache_tag_stage.way_tags[1].line_states[set_idx] == CL_STATE_MODIFIED)
			begin
				flush_cache_line({`INST_PIPELINE.dcache_tag_stage.way_tags[1].tag_ram.data[set_idx],
					set_idx}, `INST_PIPELINE.dcache_data_stage.l1d_data.data[{2'd1, set_idx}]);
			end

			if (`INST_PIPELINE.dcache_tag_stage.way_tags[2].line_states[set_idx] == CL_STATE_MODIFIED)
			begin
				flush_cache_line({`INST_PIPELINE.dcache_tag_stage.way_tags[2].tag_ram.data[set_idx],
					set_idx}, `INST_PIPELINE.dcache_data_stage.l1d_data.data[{2'd2, set_idx}]);
			end

			if (`INST_PIPELINE.dcache_tag_stage.way_tags[3].line_states[set_idx] == CL_STATE_MODIFIED)
			begin
				flush_cache_line({`INST_PIPELINE.dcache_tag_stage.way_tags[3].tag_ram.data[set_idx],
					set_idx}, `INST_PIPELINE.dcache_data_stage.l1d_data.data[{2'd3, set_idx}]);
			end
		end		
	end
	endtask
	
	initial
	begin
		if (!$value$plusargs("regtrace=%d", do_register_trace))
			do_register_trace = 0;
	end

	always_ff @(posedge clk, posedge reset)
	begin : update
		int mem_index;
	
		total_cycles <= total_cycles + 1;
		if (total_cycles == 0)
			start_simulation;
		else if (processor_halt)
		begin
			// Run some number of cycles after halt is triggered to flush pending
			// instructions and the trace reorder queue.
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

		//
		// Output cosimulation event dump. Instructions don't retire in the order they are issued.
		// This makes it hard to correlate with the functional simulator. To remedy this, we reorder
		// completed instructions so the events are logged in issue order.
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
			if (`INST_PIPELINE.wb_writeback_en && !`INST_PIPELINE.writeback_stage.__debug_is_sync_store)
			begin : dumpwb
				int tindex;
		
				if (`INST_PIPELINE.writeback_stage.__debug_wb_pipeline == PIPE_SCYCLE_ARITH)
					tindex = 4;
				else if (`INST_PIPELINE.writeback_stage.__debug_wb_pipeline == PIPE_MEM)
					tindex = 3;
				else // Multicycle arithmetic
					tindex = 0;

				assert(trace_reorder_queue[tindex].event_type == TE_INVALID);
				if (`INST_PIPELINE.wb_writeback_is_vector)
					trace_reorder_queue[tindex].event_type = TE_VWRITEBACK;
				else
					trace_reorder_queue[tindex].event_type = TE_SWRITEBACK;

				trace_reorder_queue[tindex].pc = `INST_PIPELINE.writeback_stage.__debug_wb_pc;
				trace_reorder_queue[tindex].thread_idx = `INST_PIPELINE.wb_writeback_thread_idx;
				trace_reorder_queue[tindex].writeback_reg = `INST_PIPELINE.wb_writeback_reg;
				trace_reorder_queue[tindex].mask = `INST_PIPELINE.wb_writeback_mask;
				trace_reorder_queue[tindex].data = `INST_PIPELINE.wb_writeback_value;
			end

			// Handle PC destination.
			if (`INST_PIPELINE.sx_instruction_valid 
				&& `INST_PIPELINE.sx_instruction.has_dest 
				&& `INST_PIPELINE.sx_instruction.dest_reg == `REG_PC
				&& !`INST_PIPELINE.sx_instruction.dest_is_vector)
			begin
				assert(trace_reorder_queue[5].event_type == TE_INVALID);
				trace_reorder_queue[5].event_type = TE_SWRITEBACK;
				trace_reorder_queue[5].pc = `INST_PIPELINE.sx_instruction.pc;
				trace_reorder_queue[5].thread_idx = `INST_PIPELINE.wb_rollback_thread_idx;
				trace_reorder_queue[5].writeback_reg = 31;
				trace_reorder_queue[5].data[0] = `INST_PIPELINE.wb_rollback_pc;
			end
			else if (`INST_PIPELINE.dd_instruction_valid 
				&& `INST_PIPELINE.dd_instruction.has_dest 
				&& `INST_PIPELINE.dd_instruction.dest_reg == `REG_PC
				&& !`INST_PIPELINE.dd_instruction.dest_is_vector
				&& !`INST_PIPELINE.dd_rollback_en)
			begin
				assert(trace_reorder_queue[4].event_type == TE_INVALID);
				trace_reorder_queue[4].event_type = TE_SWRITEBACK;
				trace_reorder_queue[4].pc = `INST_PIPELINE.dd_instruction.pc;
				trace_reorder_queue[4].thread_idx = `INST_PIPELINE.wb_rollback_thread_idx;
				trace_reorder_queue[4].writeback_reg = 31;
				trace_reorder_queue[4].data[0] = `INST_PIPELINE.wb_rollback_pc;
			end

			if (`INST_PIPELINE.dcache_data_stage.cache_data_store_en
				&& !`INST_PIPELINE.dcache_data_stage.rc_ddata_update_en)
			begin
				// This occurs one cycle before writeback, so put in zeroth entry
				assert(trace_reorder_queue[5].event_type == TE_INVALID);
				trace_reorder_queue[5].event_type = TE_STORE;
				trace_reorder_queue[5].pc = `INST_PIPELINE.dt_instruction.pc;
				trace_reorder_queue[5].thread_idx = `INST_PIPELINE.dt_thread_idx;
				trace_reorder_queue[5].addr = {
					`INST_PIPELINE.dt_request_addr[31:`CACHE_LINE_OFFSET_WIDTH],
					{`CACHE_LINE_OFFSET_WIDTH{1'b0}}
				};
				trace_reorder_queue[5].mask = `INST_PIPELINE.dcache_data_stage.dcache_store_mask;
				trace_reorder_queue[5].data = `INST_PIPELINE.dcache_data_stage.dcache_store_data;
			end
		end
	end
		
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core")
// End:
