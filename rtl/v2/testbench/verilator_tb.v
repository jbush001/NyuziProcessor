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
	l2rsp_packet_t l2_response;
	axi_interface axi_bus();
	localparam MEM_SIZE = 'h400000;

	/*AUTOWIRE*/

	`define CORE0 gpgpu.core[0].core
	`define INST_PIPELINE `CORE0.instruction_pipeline
	`define MEMORY memory.memory.data

	gpgpu gpgpu(
		.axi_bus(axi_bus),
		.*);

	axi_internal_ram #(.MEM_SIZE(MEM_SIZE)) memory(
		.axi_bus(axi_bus),
		.loader_we(0),
		.loader_addr(0),
		.loader_data(0),
		.*);

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
	int do_autoflush_l2 = 0;

	localparam TRACE_REORDER_QUEUE_LEN = 7;
	trace_event_t trace_reorder_queue[TRACE_REORDER_QUEUE_LEN];
	
	initial
	begin
		for (int i = 0; i < TRACE_REORDER_QUEUE_LEN; i++)
			trace_reorder_queue[i] = 0;
	end

	task start_simulation;
	begin
		for (int i = 0; i < MEM_SIZE; i++)
			`MEMORY[i] = 0;

		if ($value$plusargs("bin=%s", filename))
			$readmemh(filename, `MEMORY);
		else
		begin
			$display("error opening file");
			$finish;
		end
	end
	endtask

	task flush_l2_line;
		input l2_tag_t tag;
		input l2_set_idx_t set;
		input l2_way_idx_t way;
	begin
		for (int line_offset = 0; line_offset < `CACHE_LINE_WORDS; line_offset++)
		begin
			memory.memory.data[(tag * `L2_SETS + set) * `CACHE_LINE_WORDS + line_offset] = 
				gpgpu.l2_cache.l2_cache_read.l2_data.data[{ way, set }]
				 >> ((`CACHE_LINE_WORDS - 1 - line_offset) * 32);
		end
	end
	endtask

	// Manually copy lines from the L2 cache back to memory so we can
	// validate it there.
	`define L2_TAG_WAY gpgpu.l2_cache.l2_cache_tag.way_tags

	task flush_l2_cache;
	begin
		for (int set = 0; set < `L2_SETS; set++)
		begin
			// XXX these need to be manually commented out when changing 
			// the number of L2 ways, since it is not possible to 
			// access generated array instances when a dynamic variable.
			if (`L2_TAG_WAY[0].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[0].tag_ram.data[set], set, 0);

			if (`L2_TAG_WAY[1].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[1].tag_ram.data[set], set, 1);

			if (`L2_TAG_WAY[2].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[2].tag_ram.data[set], set, 2);

			if (`L2_TAG_WAY[3].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[3].tag_ram.data[set], set, 3);
		
			if (`L2_TAG_WAY[4].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[4].tag_ram.data[set], set, 4);

			if (`L2_TAG_WAY[5].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[5].tag_ram.data[set], set, 5);

			if (`L2_TAG_WAY[6].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[6].tag_ram.data[set], set, 6);

			if (`L2_TAG_WAY[7].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[7].tag_ram.data[set], set, 7);
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
		if ($value$plusargs("memdumpbase=%x", mem_dump_start)
			&& $value$plusargs("memdumplen=%x", mem_dump_length)
			&& $value$plusargs("memdumpfile=%s", filename))
		begin
			if ($value$plusargs("autoflushl2=%d", do_autoflush_l2))
				flush_l2_cache;

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
		$display(" l1d_miss              %d", `CORE0.performance_counters.event_counter[0]);
		$display(" l1d_hit               %d", `CORE0.performance_counters.event_counter[1]);
		$display(" l1i_miss              %d", `CORE0.performance_counters.event_counter[2]);
		$display(" l1i_hit               %d", `CORE0.performance_counters.event_counter[3]);
		$display(" instruction_issue     %d", `CORE0.performance_counters.event_counter[4]);
		$display(" instruction_retire    %d", `CORE0.performance_counters.event_counter[5]);
		$display(" store count           %d", `CORE0.performance_counters.event_counter[6]);
		$display(" store rollback count  %d", `CORE0.performance_counters.event_counter[7]);
`endif
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
				finish_cycles = 100;
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

			if (`INST_PIPELINE.dd_store_en)
			begin
				assert(trace_reorder_queue[5].event_type == TE_INVALID);
				trace_reorder_queue[5].event_type = TE_STORE;
				trace_reorder_queue[5].pc = `INST_PIPELINE.dt_instruction.pc;
				trace_reorder_queue[5].thread_idx = `INST_PIPELINE.dt_thread_idx;
				trace_reorder_queue[5].addr = {
					`INST_PIPELINE.dt_request_addr[31:`CACHE_LINE_OFFSET_WIDTH],
					{`CACHE_LINE_OFFSET_WIDTH{1'b0}}
				};
				trace_reorder_queue[5].mask = `INST_PIPELINE.dd_store_mask;
				trace_reorder_queue[5].data = `INST_PIPELINE.dd_store_data;
			end
			
			// Invalidate the store instruction if it was rolled back.
			if (`INST_PIPELINE.sb_full_rollback && `INST_PIPELINE.dd_instruction_valid)
				trace_reorder_queue[4].event_type = TE_INVALID;
				
			// Invalidate the store instruction if a synchronized store failed
			if (`INST_PIPELINE.dd_instruction_valid 
				&& `INST_PIPELINE.dd_instruction.memory_access_type == MEM_SYNC
				&& !`INST_PIPELINE.dd_instruction.is_load
				&& !`INST_PIPELINE.sb_store_sync_success)
				trace_reorder_queue[4].event_type = TE_INVALID;
		end
	end
		
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../../fpga_common")
// End:
