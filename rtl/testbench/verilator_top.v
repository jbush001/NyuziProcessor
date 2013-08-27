// 
// Copyright 2013 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

`include "defines.v"


module verilator_top(
	input clk,
	input reset);

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [31:0]	axi_araddr;		// From gpgpu of gpgpu.v
	wire [7:0]	axi_arlen;		// From gpgpu of gpgpu.v
	wire		axi_arready;		// From memory of axi_internal_ram.v
	wire		axi_arvalid;		// From gpgpu of gpgpu.v
	wire [31:0]	axi_awaddr;		// From gpgpu of gpgpu.v
	wire [7:0]	axi_awlen;		// From gpgpu of gpgpu.v
	wire		axi_awready;		// From memory of axi_internal_ram.v
	wire		axi_awvalid;		// From gpgpu of gpgpu.v
	wire		axi_bready;		// From gpgpu of gpgpu.v
	wire		axi_bvalid;		// From memory of axi_internal_ram.v
	wire [31:0]	axi_rdata;		// From memory of axi_internal_ram.v
	wire		axi_rready;		// From gpgpu of gpgpu.v
	wire		axi_rvalid;		// From memory of axi_internal_ram.v
	wire [31:0]	axi_wdata;		// From gpgpu of gpgpu.v
	wire		axi_wlast;		// From gpgpu of gpgpu.v
	wire		axi_wready;		// From memory of axi_internal_ram.v
	wire		axi_wvalid;		// From gpgpu of gpgpu.v
	wire [31:0]	io_address;		// From gpgpu of gpgpu.v
	wire		io_read_en;		// From gpgpu of gpgpu.v
	wire [31:0]	io_write_data;		// From gpgpu of gpgpu.v
	wire		io_write_en;		// From gpgpu of gpgpu.v
	wire		processor_halt;		// From gpgpu of gpgpu.v
	// End of automatics

	reg[31:0] io_read_data = 0;
	reg[1000:0] filename;
	integer do_register_trace = 0;
	reg[31:0] wb_pc = 0;
	
	initial
	begin
		if ($value$plusargs("bin=%s", filename))
		begin
			$display("loading %s", filename);
			$readmemh(filename, memory.memory.data);
		end
		else
		begin
			$display("error opening file");
			$finish;
		end

		if (!$value$plusargs("regtrace=%d", do_register_trace))
			do_register_trace = 0;
	end
	
	gpgpu gpgpu(/*AUTOINST*/
		    // Outputs
		    .processor_halt	(processor_halt),
		    .axi_awaddr		(axi_awaddr[31:0]),
		    .axi_awlen		(axi_awlen[7:0]),
		    .axi_awvalid	(axi_awvalid),
		    .axi_wdata		(axi_wdata[31:0]),
		    .axi_wlast		(axi_wlast),
		    .axi_wvalid		(axi_wvalid),
		    .axi_bready		(axi_bready),
		    .axi_araddr		(axi_araddr[31:0]),
		    .axi_arlen		(axi_arlen[7:0]),
		    .axi_arvalid	(axi_arvalid),
		    .axi_rready		(axi_rready),
		    .io_write_en	(io_write_en),
		    .io_read_en		(io_read_en),
		    .io_address		(io_address[31:0]),
		    .io_write_data	(io_write_data[31:0]),
		    // Inputs
		    .clk		(clk),
		    .reset		(reset),
		    .axi_awready	(axi_awready),
		    .axi_wready		(axi_wready),
		    .axi_bvalid		(axi_bvalid),
		    .axi_arready	(axi_arready),
		    .axi_rvalid		(axi_rvalid),
		    .axi_rdata		(axi_rdata[31:0]),
		    .io_read_data	(io_read_data[31:0]));
	
	axi_internal_ram #(.MEM_SIZE('hC0000)) memory(
			.loader_we(1'b0),
			.loader_addr(32'd0),
			.loader_data(32'd0),
		/*AUTOINST*/
				// Outputs
				.axi_awready	(axi_awready),
				.axi_wready	(axi_wready),
				.axi_bvalid	(axi_bvalid),
				.axi_arready	(axi_arready),
				.axi_rvalid	(axi_rvalid),
				.axi_rdata	(axi_rdata[31:0]),
				// Inputs
				.clk		(clk),
				.reset		(reset),
				.axi_awaddr	(axi_awaddr[31:0]),
				.axi_awlen	(axi_awlen[7:0]),
				.axi_awvalid	(axi_awvalid),
				.axi_wdata	(axi_wdata[31:0]),
				.axi_wlast	(axi_wlast),
				.axi_wvalid	(axi_wvalid),
				.axi_bready	(axi_bready),
				.axi_araddr	(axi_araddr[31:0]),
				.axi_arlen	(axi_arlen[7:0]),
				.axi_arvalid	(axi_arvalid),
				.axi_rready	(axi_rready));

	// When the processor halts, we wait some cycles for the caches
	// and memory subsystem to flush any pending transactions.
	integer total_cycles = 0;
	integer stop_countdown = 100;
	integer i;
	integer do_autoflush_l2;
	integer mem_dump_start;
	integer mem_dump_length;
	reg[31:0] mem_dat;
	integer fp;
	
	always @(posedge clk)
	begin
		total_cycles = total_cycles + 1;
		if (processor_halt && !reset)
			stop_countdown = stop_countdown - 1;
		
		if (stop_countdown == 0)
		begin
			// Perform cleanup tasks
			$display("ran for %d cycles", total_cycles);
			$display("strand states:");
			$display(" wait for dcache/store %d", 
				gpgpu.core0.pipeline.strand_select_stage.strand_fsm[0].raw_wait_count
				+ gpgpu.core0.pipeline.strand_select_stage.strand_fsm[1].raw_wait_count
				+ gpgpu.core0.pipeline.strand_select_stage.strand_fsm[2].raw_wait_count
				+ gpgpu.core0.pipeline.strand_select_stage.strand_fsm[3].raw_wait_count);
			$display(" wait for icache %d", 
				gpgpu.core0.pipeline.strand_select_stage.strand_fsm[0].icache_wait_count
				+ gpgpu.core0.pipeline.strand_select_stage.strand_fsm[1].icache_wait_count
				+ gpgpu.core0.pipeline.strand_select_stage.strand_fsm[2].icache_wait_count
				+ gpgpu.core0.pipeline.strand_select_stage.strand_fsm[3].icache_wait_count);

			// These indices must match up with the order defined in gpgpu.v
			$display("performance counters:");
			$display(" l2_writeback          %d", gpgpu.performance_counters.event_counter[14]);
			$display(" l2_wait               %d", gpgpu.performance_counters.event_counter[13]);
			$display(" l2_hit                %d", gpgpu.performance_counters.event_counter[12]);
			$display(" l2_miss               %d", gpgpu.performance_counters.event_counter[11]);
			$display(" l1d_hit               %d", gpgpu.performance_counters.event_counter[10]);
			$display(" l1d_miss              %d", gpgpu.performance_counters.event_counter[9]);
			$display(" l1i_hit               %d", gpgpu.performance_counters.event_counter[8]);
			$display(" l1i_miss              %d", gpgpu.performance_counters.event_counter[7]);
			$display(" store                 %d", gpgpu.performance_counters.event_counter[6]);
			$display(" instruction_issue     %d", gpgpu.performance_counters.event_counter[5]);
			$display(" instruction_retire    %d", gpgpu.performance_counters.event_counter[4]);
			$display(" mispredicted_branch   %d", gpgpu.performance_counters.event_counter[3]);
			$display(" uncond_branch         %d", gpgpu.performance_counters.event_counter[2]);
			$display(" cond_branch_taken     %d", gpgpu.performance_counters.event_counter[1]);
			$display(" cond_branch_not_taken %d", gpgpu.performance_counters.event_counter[0]);
		
			if ($value$plusargs("autoflushl2=%d", do_autoflush_l2))
				flush_l2_cache;

			if ($value$plusargs("memdumpbase=%x", mem_dump_start)
				&& $value$plusargs("memdumplen=%x", mem_dump_length)
				&& $value$plusargs("memdumpfile=%s", filename))
			begin
				fp = $fopen(filename, "wb");
				for (i = 0; i < mem_dump_length; i = i + 4)
				begin
					mem_dat = memory.memory.data[(mem_dump_start + i) / 4];
					
					// fputw is defined in verilator_main.cpp and writes the
					// entire word out to the file.
					$c("fputw(", fp, ",", mem_dat, ");");
				end

				$fclose(fp);
			end
		
			$display("***HALTED***");
			$finish;
		end
	end

	always @(posedge clk)
	begin
		if (io_write_en && io_address == 4)
			$write("%c", io_write_data[7:0]);
	end

	reg was_store = 0; 
	reg[1:0] store_strand = 0;
	reg[25:0] store_addr = 0;
	reg[63:0] store_mask = 0;
	reg[511:0] store_data = 0;
	reg[31:0] store_pc = 0;

	always @(posedge clk)
	begin
		// Display register dump
		if (do_register_trace)
		begin
			wb_pc <= gpgpu.core0.pipeline.ma_pc;
			if (gpgpu.core0.pipeline.wb_enable_vector_writeback)
			begin
				// New format
				$display("vwriteback %x %x %x %x %x", 
					wb_pc - 4, 
					gpgpu.core0.pipeline.wb_writeback_reg[6:5], // strand
					gpgpu.core0.pipeline.wb_writeback_reg[4:0], // register
					gpgpu.core0.pipeline.wb_writeback_mask,
					gpgpu.core0.pipeline.wb_writeback_value);
			end
			else if (gpgpu.core0.pipeline.wb_enable_scalar_writeback)
			begin
				// New format
				$display("swriteback %x %x %x %x", 
					wb_pc - 4, 
					gpgpu.core0.pipeline.wb_writeback_reg[6:5], // strand
					gpgpu.core0.pipeline.wb_writeback_reg[4:0], // register
					gpgpu.core0.pipeline.wb_writeback_value[31:0]);
			end
			
			if (was_store && !gpgpu.core0.pipeline.stbuf_rollback)
			begin
				$display("store %x %x %x %x %x",
					store_pc,
					store_strand,
					{ store_addr, 6'd0 },
					store_mask,
					store_data);
			end
			
			// This gets delayed by a cycle (checked in block above)
			was_store = gpgpu.core0.pipeline.dcache_store;
			if (was_store)
			begin
				store_pc = gpgpu.core0.pipeline.ex_pc - 4;
				store_strand = gpgpu.core0.pipeline.dcache_req_strand;
				store_addr = gpgpu.core0.pipeline.dcache_addr;
				store_mask = gpgpu.core0.pipeline.dcache_store_mask;
				store_data = gpgpu.core0.pipeline.data_to_dcache;
			end
		end
	end

	// Manually copy lines from the L2 cache back to memory so we can
	// validate it there.
	task flush_l2_cache;
		integer set;
		integer way;
	begin
		for (set = 0; set < `L2_NUM_SETS; set = set + 1)
		begin
			if (gpgpu.l2_cache.l2_cache_tag.way[0].l2_valid_mem.data[set])
				flush_l2_line(gpgpu.l2_cache.l2_cache_tag.way[0].l2_tag_mem.data[set], set, 2'd0);

			if (gpgpu.l2_cache.l2_cache_tag.way[1].l2_valid_mem.data[set])
				flush_l2_line(gpgpu.l2_cache.l2_cache_tag.way[1].l2_tag_mem.data[set], set, 2'd1);

			if (gpgpu.l2_cache.l2_cache_tag.way[2].l2_valid_mem.data[set])
				flush_l2_line(gpgpu.l2_cache.l2_cache_tag.way[2].l2_tag_mem.data[set], set, 2'd2);

			if (gpgpu.l2_cache.l2_cache_tag.way[3].l2_valid_mem.data[set])
				flush_l2_line(gpgpu.l2_cache.l2_cache_tag.way[3].l2_tag_mem.data[set], set, 2'd3);
		end
	end
	endtask

	task flush_l2_line;
		input[`L2_TAG_WIDTH - 1:0] tag;
		input[`L2_SET_INDEX_WIDTH - 1:0] set;
		input[1:0] way;
		integer line_offset;
	begin
		for (line_offset = 0; line_offset < 16; line_offset = line_offset + 1)
		begin
			memory.memory.data[tag * 16 * `L2_NUM_SETS + set * 16 + line_offset] = 
				gpgpu.l2_cache.l2_cache_read.cache_mem.data[{ way, set }]
				 >> ((15 - line_offset) * 32);
		end
	end
	endtask

`systemc_header
#include "../testbench/verilator_include.h"	// Header for contained object
 `verilog

endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../fpga")
// End:

