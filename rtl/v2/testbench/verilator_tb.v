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

	localparam MEM_SIZE = 'h500000;
	scalar_t sim_memory[MEM_SIZE];
	int total_cycles = 0;
	reg[1000:0] filename;
	int do_register_trace = 0;
	memory_access_t mem_access_latched = 0;
	
	task start_simulation;
	begin
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
		else if (total_cycles == 1000)
		begin
			$display("***HALTED***");
			finish_simulation;
			$finish;
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
		// Display register dump
		//
		if (do_register_trace && !reset)
		begin
			if (instruction_pipeline.wb_writeback_en)
			begin
				if (instruction_pipeline.wb_is_vector)
				begin
					$display("vwriteback %x %x %x %x %x", 
						instruction_pipeline.writeback_stage.debug_wb_pc - 4, 
						instruction_pipeline.wb_thread_idx,
						instruction_pipeline.wb_reg,
						instruction_pipeline.wb_mask,
						instruction_pipeline.wb_value);
				end
				else
				begin
					$display("swriteback %x %x %x %x", 
						instruction_pipeline.writeback_stage.debug_wb_pc - 4, 
						instruction_pipeline.wb_thread_idx,
						instruction_pipeline.wb_reg,
						instruction_pipeline.wb_value[0]);
				end
			end

			// Because memory writes occur one stage earlier in the pipeline, they need to be 
			// delayed here to match the expected order.
			if (SIM_dcache_write_en)
			begin
				mem_access_latched.valid <= 1;
				mem_access_latched.pc <= instruction_pipeline.dt_instruction.pc - 4;
				mem_access_latched.thread_idx <= instruction_pipeline.dt_thread_idx;
				mem_access_latched.addr <= SIM_dcache_request_addr;
				mem_access_latched.mask <= SIM_dcache_write_mask;
				mem_access_latched.data <= SIM_dcache_write_data;
			end
			else
				mem_access_latched.valid <= 0;
				
			if (mem_access_latched.valid)
			begin
				$display("store %x %x %x %x %x",
					mem_access_latched.pc,
					mem_access_latched.thread_idx,
					mem_access_latched.addr,
					mem_access_latched.mask,
					mem_access_latched.data);
			end
		end
	end
		
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core")
// End:
