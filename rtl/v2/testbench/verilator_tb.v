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

	instruction_pipeline instruction_pipeline(.*);
		
	localparam MEM_SIZE = 'h100000;
	scalar_t sim_memory[MEM_SIZE];
	int cycle_num = 0;
	reg[1000:0] filename;
	int do_register_trace = 0;
	
	task do_initialization;
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
	
		if (cycle_num == 300)
			$finish;
			
		cycle_num <= cycle_num + 1;
		if (cycle_num == 0)
			do_initialization;

		//
		// Memory
		//
		SIM_icache_data <= sim_memory[SIM_icache_request_addr[31:2]];

		mem_index = ((SIM_dcache_request_addr & ~63) / 4);
		assert(!(SIM_dcache_read_en & SIM_dcache_write_en));
		if (SIM_dcache_read_en)
		begin
			assert((SIM_dcache_request_addr & 63) == 0)
			for (int lane = 0; lane < `VECTOR_LANES; lane++)
				SIM_dcache_read_data[lane * 32+:32] <= sim_memory[mem_index + 15 - lane];
		end	
		
		if (SIM_dcache_write_en)
		begin
			assert((SIM_dcache_request_addr & 63) == 0);
			for (int lane = 0; lane < `VECTOR_LANES; lane++)
			begin : update_lane
				sim_memory[mem_index + lane] <= mask_data(SIM_dcache_write_data[(15 - lane) * 32+:32],
					sim_memory[mem_index + lane], SIM_dcache_write_mask[(63 - lane) * 4+:4]);
			end
		end

		//
		// Display register dump
		//
		if (do_register_trace && !reset)
		begin
			if (instruction_pipeline.wb_en && instruction_pipeline.wb_is_vector)
			begin
				$display("vwriteback %x %x %x %x %x", 
					instruction_pipeline.writeback_stage.debug_wb_pc - 4, 
					instruction_pipeline.wb_thread_idx,
					instruction_pipeline.wb_reg,
					instruction_pipeline.wb_mask,
					instruction_pipeline.wb_value);
			end
			else if (instruction_pipeline.wb_en && !instruction_pipeline.wb_is_vector)
			begin
				$display("swriteback %x %x %x %x", 
					instruction_pipeline.writeback_stage.debug_wb_pc - 4, 
					instruction_pipeline.wb_thread_idx,
					instruction_pipeline.wb_reg,
					instruction_pipeline.wb_value[0]);
			end

			if (SIM_dcache_write_en)
			begin
				$display("store %x %x %x %x %x",
					instruction_pipeline.dt_instruction.pc - 4,
					instruction_pipeline.dt_thread_idx,
					SIM_dcache_request_addr,
					SIM_dcache_write_mask,
					SIM_dcache_write_data);
			end
		end
	end
		
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core")
// End:
