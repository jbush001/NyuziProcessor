// 
// Copyright (C) 2011-2014 Jeff Bush
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
// Top level testbench for Verilator based simulations. 
//
module verilator_tb(
	input clk,
	input reset);

	parameter NUM_REGS = 32;
	parameter ADDR_WIDTH = 32;
	parameter DATA_WIDTH = 32;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	logic [12:0]	dram_addr;		// From sdram_controller of sdram_controller.v
	logic [1:0]	dram_ba;		// From sdram_controller of sdram_controller.v
	wire		dram_cas_n;		// From sdram_controller of sdram_controller.v
	wire		dram_cke;		// From sdram_controller of sdram_controller.v
	wire		dram_clk;		// From sdram_controller of sdram_controller.v
	wire		dram_cs_n;		// From sdram_controller of sdram_controller.v
	wire [DATA_WIDTH-1:0] dram_dq;		// To/From sdram_controller of sdram_controller.v, ...
	wire		dram_ras_n;		// From sdram_controller of sdram_controller.v
	wire		dram_we_n;		// From sdram_controller of sdram_controller.v
	wire [31:0]	io_address;		// From gpgpu of gpgpu.v
	wire		io_read_en;		// From gpgpu of gpgpu.v
	wire [31:0]	io_write_data;		// From gpgpu of gpgpu.v
	wire		io_write_en;		// From gpgpu of gpgpu.v
	logic		pc_event_dram_page_hit;	// From sdram_controller of sdram_controller.v
	logic		pc_event_dram_page_miss;// From sdram_controller of sdram_controller.v
	wire		processor_halt;		// From gpgpu of gpgpu.v
	wire [7:0]	vga_b;			// From vga_controller of vga_controller.v
	wire		vga_blank_n;		// From vga_controller of vga_controller.v
	wire		vga_clk;		// From vga_controller of vga_controller.v
	wire [7:0]	vga_g;			// From vga_controller of vga_controller.v
	wire		vga_hs;			// From vga_controller of vga_controller.v
	wire [7:0]	vga_r;			// From vga_controller of vga_controller.v
	wire		vga_sync_n;		// From vga_controller of vga_controller.v
	wire		vga_vs;			// From vga_controller of vga_controller.v
	// End of automatics

	reg[31:0] io_read_data = 0;
	reg[1000:0] filename;
	integer do_register_trace;
	integer do_register_dump;
	reg[31:0] wb_pc = 0;
	integer total_cycles = 0;
	integer stop_countdown = 100;
	integer i;
	integer do_autoflush_l2;
	integer mem_dump_start;
	integer mem_dump_length;
	reg[31:0] mem_dat;
	integer dump_fp;
	integer profile_fp;
	integer enable_profile;
    integer max_cycles;
	integer enable_strand_state_trace;
	integer state_trace_fp;
	reg was_store = 0; 
	reg[1:0] store_strand = 0;
	reg[25:0] store_addr = 0;
	reg[63:0] store_mask = 0;
	reg[511:0] store_data = 0;
	reg[31:0] store_pc = 0;
	reg[31:0] regtemp[0:17 * NUM_REGS * `STRANDS_PER_CORE - 1];
	wire mem_clk = clk;
	wire core_clk;
	axi_interface axi_bus_core();
	axi_interface axi_bus_m0();
	axi_interface axi_bus_m1();
	axi_interface axi_bus_s0();
	axi_interface axi_bus_s1();
	    
	/* gpgpu AUTO_TEMPLATE(
		.clk(core_clk),
		.axi_bus(axi_bus_core),
		);
	*/
	gpgpu gpgpu(/*AUTOINST*/
		    // Interfaces
		    .axi_bus		(axi_bus_core),		 // Templated
		    // Outputs
		    .processor_halt	(processor_halt),
		    .io_write_en	(io_write_en),
		    .io_read_en		(io_read_en),
		    .io_address		(io_address[31:0]),
		    .io_write_data	(io_write_data[31:0]),
		    // Inputs
		    .clk		(core_clk),		 // Templated
		    .reset		(reset),
		    .io_read_data	(io_read_data[31:0]));
	  
	// Internal SRAM.  The system boots out of this.
	/* axi_internal_ram AUTO_TEMPLATE(
		.clk(mem_clk),
		.axi_bus(axi_bus_m0),
		.loader_we(1'b0),
		.loader_addr({ADDR_WIDTH{1'b0}}),
		.loader_data({DATA_WIDTH{1'b0}}),
		);
	*/
	axi_internal_ram #(.MEM_SIZE('h400000)) axi_internal_ram(/*AUTOINST*/
								 // Interfaces
								 .axi_bus		(axi_bus_m0),	 // Templated
								 // Inputs
								 .clk			(mem_clk),	 // Templated
								 .reset			(reset),
								 .loader_we		(1'b0),		 // Templated
								 .loader_addr		({ADDR_WIDTH{1'b0}}), // Templated
								 .loader_data		({DATA_WIDTH{1'b0}})); // Templated

	initial
	begin
		// Run simulation for some number of cycles
		if (!$value$plusargs("simcycles=%d", max_cycles))
			max_cycles = -1;

		if (!$value$plusargs("regtrace=%d", do_register_trace))
			do_register_trace = 0;
		
		if ($value$plusargs("profile=%s", filename))
		begin
			enable_profile = 1;
			profile_fp = $fopen(filename, "wb");
		end
		else
			enable_profile = 0;
			
		if ($value$plusargs("statetrace=%s", filename))
		begin
			enable_strand_state_trace = 1;
			state_trace_fp = $fopen(filename, "wb");
		end
	end

	always_ff @(posedge clk)
	begin
		// Do memory initialization on the second clock edge instead of 
		// in an initial block because otherwise it conflicts with code that clears 
		// memory in other initial blocks (we cannot work around this with # delays,
		// since they are not supported by Verilator). This also needs to be on edge 1
		// instead of zero, since the reset blocks will execute on the first.  The
		// system is in reset when this happens.
		if (total_cycles == 1)
			start_simulation;

        if (total_cycles == max_cycles)
        begin
            $display("exceeded maximum cycles");
            $finish;
        end
        
		total_cycles = total_cycles + 1;
		
		// When the processor halts, we wait some cycles for the caches
		// and memory subsystem to flush any pending transactions.
		if (processor_halt && !reset)
			stop_countdown = stop_countdown - 1;

		if (stop_countdown == 0)
		begin
			$display("***HALTED***");
			finish_simulation;
			$finish;
		end
	end

	// Dummy peripheral.  This takes whatever is stored at location 32'hffff0000
	// and rotates it right one bit.
	reg[31:0] dummy_device_value = 0;

	always_comb
	begin
		if (io_read_en && io_address == 0)
			io_read_data = dummy_device_value;
		else
			io_read_data = 32'hffffffff;
	end
	
	always_ff @(posedge core_clk)
	begin
		if (io_write_en && io_address == 0)
			dummy_device_value <= { io_write_data[0], io_write_data[31:1] };
		else if (io_write_en && io_address == 4)
			$write("%c", io_write_data[7:0]);   // Writes to virtual console
	end

	always_ff @(posedge clk)
	begin
		// Display register dump
		if (do_register_trace && !reset)
		begin
			wb_pc <= gpgpu.core0.pipeline.ma_pc;
			if (gpgpu.core0.pipeline.wb_enable_vector_writeback)
			begin
				$display("vwriteback %x %x %x %x %x", 
					wb_pc - 4, 
					gpgpu.core0.pipeline.wb_writeback_reg[6:5], // strand
					gpgpu.core0.pipeline.wb_writeback_reg[4:0], // register
					gpgpu.core0.pipeline.wb_writeback_mask,
					gpgpu.core0.pipeline.wb_writeback_value);
			end
			else if (gpgpu.core0.pipeline.wb_enable_scalar_writeback)
			begin
				$display("swriteback %x %x %x %x", 
					wb_pc - 4, 
					gpgpu.core0.pipeline.wb_writeback_reg[6:5], // strand
					gpgpu.core0.pipeline.wb_writeback_reg[4:0], // register
					gpgpu.core0.pipeline.wb_writeback_value[31:0]);
			end
			else if (gpgpu.core0.pipeline.ma_enable_scalar_writeback
				 && gpgpu.core0.pipeline.ma_writeback_reg[4:0] == `REG_PC 
				 && gpgpu.core0.pipeline.writeback_stage.is_load)
			begin
				// PC load
				$display("swriteback %x %x 1f %x", 
					gpgpu.core0.pipeline.ma_pc - 4, 
					gpgpu.core0.pipeline.wb_writeback_reg[6:5], // strand
					gpgpu.core0.pipeline.wb_rollback_pc[31:0]);
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
		
		if (enable_profile)
		begin
			if (gpgpu.core0.pipeline.strand_select_stage.ss_pc != 0)
				$fwrite(profile_fp, "%x\n", 
					gpgpu.core0.pipeline.strand_select_stage.ss_pc);
		end
		
		if (enable_strand_state_trace)
		begin
			$fwrite(state_trace_fp, "%d,%d,%d,%d,%d,%d,%d,%d\n",
				gpgpu.core0.pipeline.instruction_fetch_stage.if_instruction_valid[0],
				gpgpu.core0.pipeline.strand_select_stage.strand_fsm[0].thread_state_ff,
				gpgpu.core0.pipeline.instruction_fetch_stage.if_instruction_valid[1],
				gpgpu.core0.pipeline.strand_select_stage.strand_fsm[1].thread_state_ff,
				gpgpu.core0.pipeline.instruction_fetch_stage.if_instruction_valid[2],
				gpgpu.core0.pipeline.strand_select_stage.strand_fsm[2].thread_state_ff,
				gpgpu.core0.pipeline.instruction_fetch_stage.if_instruction_valid[3],
				gpgpu.core0.pipeline.strand_select_stage.strand_fsm[3].thread_state_ff);
		
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
			axi_internal_ram.memory.data[tag * 16 * `L2_NUM_SETS + set * 16 + line_offset] = 
				gpgpu.l2_cache.l2_cache_read.cache_mem.data[{ way, set }]
				 >> ((15 - line_offset) * 32);
		end
	end
	endtask
	
	`define PIPELINE gpgpu.core0.pipeline
	`define VREG_FILE `PIPELINE.vector_register_file

	// Load memory initialization file.
	task start_simulation;
	begin
		if ($value$plusargs("bin=%s", filename))
			$readmemh(filename, axi_internal_ram.memory.data);
		else
		begin
			$display("error opening file");
			$finish;
		end

		// If initial values are passed for scalar registers, load those now
		if ($value$plusargs("initial_regs=%s", filename))
		begin
			$readmemh(filename, regtemp);
			for (i = 0; i < NUM_REGS * `STRANDS_PER_CORE; i = i + 1)		// ignore PC
				`PIPELINE.scalar_register_file.registers[i] = regtemp[i];

			for (i = 0; i < NUM_REGS * `STRANDS_PER_CORE; i = i + 1)
			begin
				`VREG_FILE.lane[15].registers[i] = regtemp[(i + 8) * 16];
				`VREG_FILE.lane[14].registers[i] = regtemp[(i + 8) * 16 + 1];
				`VREG_FILE.lane[13].registers[i] = regtemp[(i + 8) * 16 + 2];
				`VREG_FILE.lane[12].registers[i] = regtemp[(i + 8) * 16 + 3];
				`VREG_FILE.lane[11].registers[i] = regtemp[(i + 8) * 16 + 4];
				`VREG_FILE.lane[10].registers[i] = regtemp[(i + 8) * 16 + 5];
				`VREG_FILE.lane[9].registers[i] = regtemp[(i + 8) * 16 + 6];
				`VREG_FILE.lane[8].registers[i] = regtemp[(i + 8) * 16 + 7];
				`VREG_FILE.lane[7].registers[i] = regtemp[(i + 8) * 16 + 8];
				`VREG_FILE.lane[6].registers[i] = regtemp[(i + 8) * 16 + 9];
				`VREG_FILE.lane[5].registers[i] = regtemp[(i + 8) * 16 + 10];
				`VREG_FILE.lane[4].registers[i] = regtemp[(i + 8) * 16 + 11];
				`VREG_FILE.lane[3].registers[i] = regtemp[(i + 8) * 16 + 12];
				`VREG_FILE.lane[2].registers[i] = regtemp[(i + 8) * 16 + 13];
				`VREG_FILE.lane[1].registers[i] = regtemp[(i + 8) * 16 + 14];
				`VREG_FILE.lane[0].registers[i] = regtemp[(i + 8) * 16 + 15];
			end
			
			do_register_dump = 1;
		end
	end
	endtask
	
	task finish_simulation;
	begin
		// Print statistics
		$display("ran for %d cycles", total_cycles);
		$display("strand states:");
		$display(" wait for dcache/store %d", 
			gpgpu.core0.pipeline.strand_select_stage.strand_fsm[0].dcache_wait_count
			+ gpgpu.core0.pipeline.strand_select_stage.strand_fsm[1].dcache_wait_count
			+ gpgpu.core0.pipeline.strand_select_stage.strand_fsm[2].dcache_wait_count
			+ gpgpu.core0.pipeline.strand_select_stage.strand_fsm[3].dcache_wait_count);
		$display(" wait for icache %d", 
			gpgpu.core0.pipeline.strand_select_stage.strand_fsm[0].icache_wait_count
			+ gpgpu.core0.pipeline.strand_select_stage.strand_fsm[1].icache_wait_count
			+ gpgpu.core0.pipeline.strand_select_stage.strand_fsm[2].icache_wait_count
			+ gpgpu.core0.pipeline.strand_select_stage.strand_fsm[3].icache_wait_count);
		$display(" wait for RAW dependency %d", 
			gpgpu.core0.pipeline.strand_select_stage.strand_fsm[0].raw_wait_count
			+ gpgpu.core0.pipeline.strand_select_stage.strand_fsm[1].raw_wait_count
			+ gpgpu.core0.pipeline.strand_select_stage.strand_fsm[2].raw_wait_count
			+ gpgpu.core0.pipeline.strand_select_stage.strand_fsm[3].raw_wait_count);

		// These indices must match up with the order defined in gpgpu.v
		$display("performance counters:");
		$display(" memory_ins_issue      %d", gpgpu.performance_counters.event_counter[16]);
		$display(" vector_ins_issue      %d", gpgpu.performance_counters.event_counter[15]);
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
			dump_fp = $fopen(filename, "wb");
			for (i = 0; i < mem_dump_length; i = i + 4)
			begin
				mem_dat = axi_internal_ram.memory.data[(mem_dump_start + i) / 4];
				
				// fputw is defined in verilator_main.cpp and writes the
				// entire word out to the file.
				$c("fputw(", dump_fp, ",", mem_dat, ");");
			end

			$fclose(dump_fp);
		end	
		
		if (enable_profile)
			$fclose(profile_fp);

		if (enable_strand_state_trace)
			$fclose(state_trace_fp);
			
		if (do_register_dump)
		begin
			$display("REGISTERS:");
			// Dump the registers
			for (i = 0; i < NUM_REGS * `STRANDS_PER_CORE; i = i + 1)
				$display("%08x", `PIPELINE.scalar_register_file.registers[i]);
	
			for (i = 0; i < NUM_REGS * `STRANDS_PER_CORE; i = i + 1)
			begin
				$display("%08x", `PIPELINE.vector_register_file.lane[15].registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane[14].registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane[13].registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane[12].registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane[11].registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane[10].registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane[9].registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane[8].registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane[7].registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane[6].registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane[5].registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane[4].registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane[3].registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane[2].registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane[1].registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane[0].registers[i]);
			end
		end
	end
	endtask

// For fputw function, needed to write memory dumps
`systemc_header
#include "../testbench/verilator_include.h"	
`verilog

`ifdef SIM_FPGA
	// Simulate a configuration that is very similar to the FPGA.

	// Bridge signals from core clock domain to memory clock domain.
	/* axi_async_bridge AUTO_TEMPLATE(
		.clk_s(core_clk),
		.clk_m(mem_clk),
		.axi_bus_s(axi_bus_core),
		.axi_bus_m(axi_bus_s0),
		);
	*/
	axi_async_bridge #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) cpu_async_bridge(
		/*AUTOINST*/
											      // Interfaces
											      .axi_bus_s	(axi_bus_core),	 // Templated
											      .axi_bus_m	(axi_bus_s0),	 // Templated
											      // Inputs
											      .reset		(reset),
											      .clk_s		(core_clk),	 // Templated
											      .clk_m		(mem_clk));	 // Templated
			  			  
	axi_interconnect axi_interconnect(
		.clk(mem_clk),
		/*AUTOINST*/
					  // Interfaces
					  .axi_bus_m0		(axi_bus_m0),
					  .axi_bus_m1		(axi_bus_m1),
					  .axi_bus_s0		(axi_bus_s0),
					  .axi_bus_s1		(axi_bus_s1),
					  // Inputs
					  .reset		(reset));

	/* sdram_controller AUTO_TEMPLATE(
		.clk(mem_clk),
		.axi_bus(axi_bus_m1),);
	*/
	sdram_controller #(
			.DATA_WIDTH(DATA_WIDTH), 
			.ROW_ADDR_WIDTH(13), 
			.COL_ADDR_WIDTH(10),

			// 50 Mhz = 20ns clock.  Each value is clocks of delay minus one.
			// Timing values based on datasheet for A3V64S40ETP SDRAM parts
			// on the DE2-115 board.
			.T_REFRESH(390),          // 64 ms / 8192 rows = 7.8125 uS  
			.T_POWERUP(10000),        // 200 us		
			.T_ROW_PRECHARGE(1),      // 21 ns	
			.T_AUTO_REFRESH_CYCLE(3), // 75 ns
			.T_RAS_CAS_DELAY(1),      // 21 ns	
			.T_CAS_LATENCY(1)		  // 21 ns (2 cycles)
		) sdram_controller(
			.clk(mem_clk),
			.reset(reset),
			/*AUTOINST*/
				   // Interfaces
				   .axi_bus		(axi_bus_m1),	 // Templated
				   // Outputs
				   .dram_clk		(dram_clk),
				   .dram_cke		(dram_cke),
				   .dram_cs_n		(dram_cs_n),
				   .dram_ras_n		(dram_ras_n),
				   .dram_cas_n		(dram_cas_n),
				   .dram_we_n		(dram_we_n),
				   .dram_ba		(dram_ba[1:0]),
				   .dram_addr		(dram_addr[12:0]),
				   .pc_event_dram_page_miss(pc_event_dram_page_miss),
				   .pc_event_dram_page_hit(pc_event_dram_page_hit),
				   // Inouts
				   .dram_dq		(dram_dq[DATA_WIDTH-1:0]));

	sim_sdram #(
			.DATA_WIDTH(DATA_WIDTH),
			.ROW_ADDR_WIDTH(13),
			.COL_ADDR_WIDTH(10),
			.MEM_SIZE('h400000) 
		) sdram(/*AUTOINST*/
			// Inouts
			.dram_dq	(dram_dq[DATA_WIDTH-1:0]),
			// Inputs
			.dram_clk	(dram_clk),
			.dram_cke	(dram_cke),
			.dram_cs_n	(dram_cs_n),
			.dram_ras_n	(dram_ras_n),
			.dram_cas_n	(dram_cas_n),
			.dram_we_n	(dram_we_n),
			.dram_ba	(dram_ba[1:0]),
			.dram_addr	(dram_addr[12:0]));

	/* vga_controller AUTO_TEMPLATE(
		.clk(mem_clk),
		.axi_bus(axi_bus_s1));
	*/
	vga_controller vga_controller(
		/*AUTOINST*/
				      // Interfaces
				      .axi_bus		(axi_bus_s1),	 // Templated
				      // Outputs
				      .vga_r		(vga_r[7:0]),
				      .vga_g		(vga_g[7:0]),
				      .vga_b		(vga_b[7:0]),
				      .vga_clk		(vga_clk),
				      .vga_blank_n	(vga_blank_n),
				      .vga_hs		(vga_hs),
				      .vga_vs		(vga_vs),
				      .vga_sync_n	(vga_sync_n),
				      // Inputs
				      .clk		(mem_clk),	 // Templated
				      .reset		(reset));

	reg _divided_clock = 0;
	always_ff @(posedge clk)
		_divided_clock = !_divided_clock;

	assign core_clk = _divided_clock;
`else
	// Just simulate with SRAM
	assign core_clk = clk;

	// Bridge the core directly to internal SRAM.
    assign axi_bus_m0.awaddr = axi_bus_core.awaddr;
    assign axi_bus_m0.awlen = axi_bus_core.awlen;
    assign axi_bus_m0.awvalid = axi_bus_core.awvalid;
    assign axi_bus_m0.wdata = axi_bus_core.wdata;
    assign axi_bus_m0.wlast = axi_bus_core.wlast;
    assign axi_bus_m0.wvalid = axi_bus_core.wvalid;
    assign axi_bus_m0.bready = axi_bus_core.bready;
    assign axi_bus_m0.araddr = axi_bus_core.araddr;
    assign axi_bus_m0.arlen = axi_bus_core.arlen;
    assign axi_bus_m0.arvalid = axi_bus_core.arvalid;
    assign axi_bus_m0.rready = axi_bus_core.rready;
	assign axi_bus_core.awready = axi_bus_m0.awready;
	assign axi_bus_core.wready = axi_bus_m0.wready;
	assign axi_bus_core.bvalid = axi_bus_m0.bvalid;
	assign axi_bus_core.arready = axi_bus_m0.arready;
	assign axi_bus_core.rvalid = axi_bus_m0.rvalid;
	assign axi_bus_core.rdata = axi_bus_m0.rdata;
`endif


endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../../fpga_common")
// End:

