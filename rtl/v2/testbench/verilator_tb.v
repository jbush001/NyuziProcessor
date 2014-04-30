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

	scalar_t SIM_dcache_request_addr;
	logic SIM_dcache_read_en;
	logic SIM_dcache_write_en;
	logic[`CACHE_LINE_BITS - 1:0] SIM_dcache_write_data;
	logic[`CACHE_LINE_BITS - 1:0] SIM_dcache_read_data;
	logic[`CACHE_LINE_BYTES - 1:0] SIM_dcache_write_mask;
	int mem_dump_start;
	int mem_dump_length;
	logic processor_halt;
	reg[31:0] mem_dat;
	integer dump_fp;

	instruction_pipeline instruction_pipeline(.*);
		
	typedef struct packed {
		logic valid;
		scalar_t pc;
		thread_idx_t thread_idx;
		scalar_t addr;
		logic[`CACHE_LINE_BYTES - 1:0] mask;
		logic[`CACHE_LINE_BITS - 1:0] data;
	} memory_access_t;

	typedef enum {
		TE_INVALID,
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

	localparam MEM_SIZE = 'h500000;
	scalar_t sim_memory[MEM_SIZE];
	int total_cycles = 0;
	reg[1000:0] filename;
	int do_register_trace = 0;
	memory_access_t mem_access_latched = 0;
	int finish_cycles = 0;

	localparam TRACE_REORDER_QUEUE_LEN = 7;
	trace_event_t trace_reorder_queue[TRACE_REORDER_QUEUE_LEN];
	
	task start_simulation;
	begin
		for (int i = 0; i < TRACE_REORDER_QUEUE_LEN; i++)
			trace_reorder_queue[i] = 0;
	
		for (int i = 0; i < MEM_SIZE; i++)
			sim_memory[i] = 0;
			
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
	
	function [31:0] endian_swap;
		input[31:0] value_in;
	begin
		endian_swap = { value_in[7:0], value_in[15:8], value_in[23:16], value_in[31:24] };
	end
	endfunction
	
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

		//
		// Memory
		//
		SIM_icache_data <= sim_memory[SIM_icache_request_addr[31:2]];

		mem_index = ((SIM_dcache_request_addr & ~63) / 4);
		assert(!(SIM_dcache_read_en & SIM_dcache_write_en));
		if (SIM_dcache_read_en)
		begin
			assert((SIM_dcache_request_addr & 63) == 0)
			for (int lane = 0; lane < `CACHE_LINE_WORDS; lane++)
				SIM_dcache_read_data[lane * 32+:32] <= sim_memory[mem_index + `CACHE_LINE_WORDS - 1 - lane];
		end	
		
		if (SIM_dcache_write_en)
		begin
			assert((SIM_dcache_request_addr & 63) == 0);
			for (int lane = 0; lane < `CACHE_LINE_WORDS; lane++)
			begin : update_lane
				sim_memory[mem_index + lane] <= mask_data(SIM_dcache_write_data[(`CACHE_LINE_WORDS - 1 - lane) * 32+:32],
					sim_memory[mem_index + lane], SIM_dcache_write_mask[(`CACHE_LINE_WORDS - 1 - lane) * 4+:4]);
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

			if (instruction_pipeline.wb_writeback_en)
			begin : dumpwb
				int tindex;
		
				if (instruction_pipeline.writeback_stage.DEBUG_wb_pipeline == PIPE_SCYCLE_ARITH)
					tindex = 5;
				else if (instruction_pipeline.writeback_stage.DEBUG_wb_pipeline == PIPE_MEM)
					tindex = 4;
				else // Multicycle arithmetic
					tindex = 0;

				if (instruction_pipeline.wb_writeback_is_vector)
					trace_reorder_queue[tindex].event_type = TE_VWRITEBACK;
				else
					trace_reorder_queue[tindex].event_type = TE_SWRITEBACK;

				trace_reorder_queue[tindex].pc = instruction_pipeline.writeback_stage.DEBUG_wb_pc - 4;
				trace_reorder_queue[tindex].thread_idx = instruction_pipeline.wb_writeback_thread_idx;
				trace_reorder_queue[tindex].writeback_reg = instruction_pipeline.wb_writeback_reg;
				trace_reorder_queue[tindex].mask = instruction_pipeline.wb_writeback_mask;
				trace_reorder_queue[tindex].data = instruction_pipeline.wb_writeback_value;
			end

			// Handle PC destination.
			if (instruction_pipeline.sx_instruction_valid 
				&& instruction_pipeline.sx_instruction.has_dest 
				&& instruction_pipeline.sx_instruction.dest_reg == `REG_PC)
			begin
				trace_reorder_queue[5].event_type = TE_SWRITEBACK;
				trace_reorder_queue[5].pc = instruction_pipeline.sx_instruction.pc - 4;
				trace_reorder_queue[5].thread_idx = instruction_pipeline.wb_rollback_thread_idx;
				trace_reorder_queue[5].writeback_reg = 31;
				trace_reorder_queue[5].data[0] = instruction_pipeline.wb_rollback_pc;
			end
			else if (instruction_pipeline.dd_instruction_valid 
				&& instruction_pipeline.dd_instruction.has_dest 
				&& instruction_pipeline.dd_instruction.dest_reg == `REG_PC)
			begin
				trace_reorder_queue[4].event_type = TE_SWRITEBACK;
				trace_reorder_queue[4].pc = instruction_pipeline.dd_instruction.pc - 4;
				trace_reorder_queue[4].thread_idx = instruction_pipeline.wb_rollback_thread_idx;
				trace_reorder_queue[4].writeback_reg = 31;
				trace_reorder_queue[4].data[0] = instruction_pipeline.wb_rollback_pc;
			end

			if (SIM_dcache_write_en)
			begin
				// This occurs one cycle before writeback, so put in zeroth entry
				trace_reorder_queue[6].event_type = TE_STORE;
				trace_reorder_queue[6].pc = instruction_pipeline.dt_instruction.pc - 4;
				trace_reorder_queue[6].thread_idx = instruction_pipeline.dt_thread_idx;
				trace_reorder_queue[6].addr = SIM_dcache_request_addr;
				trace_reorder_queue[6].mask = SIM_dcache_write_mask;
				trace_reorder_queue[6].data = SIM_dcache_write_data;
			end
		end
	end
		
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core")
// End:
