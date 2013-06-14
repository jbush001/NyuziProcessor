// 
// Copyright 2011-2012 Jeff Bush
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

//
// Top level module for simulator
//

module simulator_top;
	
	parameter NUM_REGS = 32;

	reg 			clk;
	reg				reset = 0;
	integer 		i, j;
	reg[1000:0] 	filename;
	reg[31:0] 		regtemp[0:17 * NUM_REGS * `STRANDS_PER_CORE - 1];
	integer 		do_register_dump;
	integer			do_register_trace;
	integer 		do_state_trace;
	integer			state_trace_fp;
	integer 		mem_dump_start;
	integer 		mem_dump_length;
	reg[31:0] 		mem_dat;
	integer 		simulation_cycles;
	wire			processor_halt;
	integer			fp;
	reg[31:0] 		wb_pc = 0;
	integer			dummy_return;
	integer			do_autoflush_l2;

	localparam DATA_WIDTH = 32;
	
	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [12:0]	addr;			// From sdram_controller of sdram_controller.v
	wire [31:0]	axi_araddr;		// From gpgpu of gpgpu.v
	wire [7:0]	axi_arlen;		// From gpgpu of gpgpu.v
	wire		axi_arready;		// From sdram_controller of sdram_controller.v, ...
	wire		axi_arvalid;		// From gpgpu of gpgpu.v
	wire [31:0]	axi_awaddr;		// From gpgpu of gpgpu.v
	wire [7:0]	axi_awlen;		// From gpgpu of gpgpu.v
	wire		axi_awready;		// From sdram_controller of sdram_controller.v, ...
	wire		axi_awvalid;		// From gpgpu of gpgpu.v
	wire		axi_bready;		// From gpgpu of gpgpu.v
	wire		axi_bvalid;		// From sdram_controller of sdram_controller.v, ...
	wire [31:0]	axi_rdata;		// From sdram_controller of sdram_controller.v, ...
	wire		axi_rready;		// From gpgpu of gpgpu.v
	wire		axi_rvalid;		// From sdram_controller of sdram_controller.v, ...
	wire [31:0]	axi_wdata;		// From gpgpu of gpgpu.v
	wire		axi_wlast;		// From gpgpu of gpgpu.v
	wire		axi_wready;		// From sdram_controller of sdram_controller.v, ...
	wire		axi_wvalid;		// From gpgpu of gpgpu.v
	wire [1:0]	ba;			// From sdram_controller of sdram_controller.v
	wire		cas_n;			// From sdram_controller of sdram_controller.v
	wire		cke;			// From sdram_controller of sdram_controller.v
	wire		cs_n;			// From sdram_controller of sdram_controller.v
	wire [DATA_WIDTH-1:0] dq;		// To/From sdram_controller of sdram_controller.v, ...
	wire		dqmh;			// From sdram_controller of sdram_controller.v
	wire		dqml;			// From sdram_controller of sdram_controller.v
	wire		dram_clk;		// From sdram_controller of sdram_controller.v
	wire [31:0]	io_address;		// From gpgpu of gpgpu.v
	wire		io_read_en;		// From gpgpu of gpgpu.v
	wire [31:0]	io_write_data;		// From gpgpu of gpgpu.v
	wire		io_write_en;		// From gpgpu of gpgpu.v
	wire		pc_event_dram_page_hit;	// From sdram_controller of sdram_controller.v
	wire		pc_event_dram_page_miss;// From sdram_controller of sdram_controller.v
	wire		ras_n;			// From sdram_controller of sdram_controller.v
	wire		we_n;			// From sdram_controller of sdram_controller.v
	// End of automatics
	
	wire[31:0] display_address = 0;
	reg[31:0] io_read_data = 0;

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

`ifdef ENABLE_SDRAM
	sdram_controller #(
		.DATA_WIDTH(DATA_WIDTH), 
		.ROW_ADDR_WIDTH(12), 
		.COL_ADDR_WIDTH(8), 
		.T_POWERUP(10)) sdram_controller(/*AUTOINST*/
						 // Outputs
						 .dram_clk		(dram_clk),
						 .cke			(cke),
						 .cs_n			(cs_n),
						 .ras_n			(ras_n),
						 .cas_n			(cas_n),
						 .we_n			(we_n),
						 .ba			(ba[1:0]),
						 .addr			(addr[12:0]),
						 .dqmh			(dqmh),
						 .dqml			(dqml),
						 .axi_awready		(axi_awready),
						 .axi_wready		(axi_wready),
						 .axi_bvalid		(axi_bvalid),
						 .axi_arready		(axi_arready),
						 .axi_rvalid		(axi_rvalid),
						 .axi_rdata		(axi_rdata[31:0]),
						 .pc_event_dram_page_miss(pc_event_dram_page_miss),
						 .pc_event_dram_page_hit(pc_event_dram_page_hit),
						 // Inouts
						 .dq			(dq[DATA_WIDTH-1:0]),
						 // Inputs
						 .clk			(clk),
						 .reset			(reset),
						 .axi_awaddr		(axi_awaddr[31:0]),
						 .axi_awlen		(axi_awlen[7:0]),
						 .axi_awvalid		(axi_awvalid),
						 .axi_wdata		(axi_wdata[31:0]),
						 .axi_wlast		(axi_wlast),
						 .axi_wvalid		(axi_wvalid),
						 .axi_bready		(axi_bready),
						 .axi_araddr		(axi_araddr[31:0]),
						 .axi_arlen		(axi_arlen[7:0]),
						 .axi_arvalid		(axi_arvalid),
						 .axi_rready		(axi_rready));

	sim_sdram #(
		.DATA_WIDTH(DATA_WIDTH), 
		.ROW_ADDR_WIDTH(12), 
		.COL_ADDR_WIDTH(8)) memory(/*AUTOINST*/
					   // Inouts
					   .dq			(dq[DATA_WIDTH-1:0]),
					   // Inputs
					   .clk			(clk),
					   .cke			(cke),
					   .cs_n		(cs_n),
					   .ras_n		(ras_n),
					   .cas_n		(cas_n),
					   .we_n		(we_n),
					   .ba			(ba[1:0]),
					   .dqmh		(dqmh),
					   .dqml		(dqml),
					   .addr		(addr[12:0]));	

	`define MEM_ARRAY memory.memory
`else
	axi_internal_ram memory(
			.loader_we(1'b0),
			.loader_addr(32'd0),
			.loader_data(32'd0),
			.reset(1'b0),
			
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

	assign pc_event_dram_page_miss = 0;
	assign pc_event_dram_page_hit = 0;

	`define MEM_ARRAY memory.memory.data
`endif

	// Dummy peripheral.  This takes whatever is stored at location 32'hffff0000
	// and rotates it right one bit.
	reg[31:0] dummy_device_value = 0;

	always @*
	begin
		if (io_read_en && io_address == 0)
			io_read_data = dummy_device_value;
		else
			io_read_data = 32'hffffffff;
	end
	
	always @(posedge clk)
	begin
		if (io_write_en && io_address == 0)
			dummy_device_value <= { io_write_data[0], io_write_data[31:1] };
	end

	// For cosimulation logging, track memory requests
	reg was_store = 0; 
	reg[1:0] store_strand = 0;
	reg[25:0] store_addr = 0;
	reg[63:0] store_mask = 0;
	reg[511:0] store_data = 0;
	reg[31:0] store_pc = 0;

	// When the processor halts, we wait some cycles for the caches
	// and memory subsystem to flush any pending transactions.
	integer stop_countdown = 100;
	reg end_simulation = 0;
	always @(posedge clk)
	begin
		if (processor_halt)
			stop_countdown = stop_countdown - 1;
		
		if (stop_countdown == 0)
			end_simulation = 1;
	end

	initial
	begin
		// Load executable binary into memory
		if ($value$plusargs("bin=%s", filename))
			$readmemh(filename, `MEM_ARRAY);
		else
		begin
			$display("error opening file");
			$finish;
		end

		do_register_dump = 0; // Dump all registers at end

		`define PIPELINE gpgpu.core0.pipeline
		`define SS_STAGE `PIPELINE.strand_select_stage
		`define VREG_FILE `PIPELINE.vector_register_file
		`define SFSM0 `SS_STAGE.strand_fsm0
		`define SFSM1 `SS_STAGE.strand_fsm1
		`define SFSM2 `SS_STAGE.strand_fsm2
		`define SFSM3 `SS_STAGE.strand_fsm3

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

		if ($value$plusargs("statetrace=%s", filename))
		begin
			state_trace_fp = $fopen(filename, "w");
			do_state_trace = 1;
		end
		else
			do_state_trace = 0;

		if (!$value$plusargs("regtrace=%d", do_register_trace))
			do_register_trace = 0;
	
		// Open a waveform dump trace file
		if ($value$plusargs("trace=%s", filename))
		begin
			$dumpfile(filename);
			$dumpvars;
		end
	
		// Run simulation for some number of cycles
		if (!$value$plusargs("simcycles=%d", simulation_cycles))
			simulation_cycles = 500;

		reset = 1;
		#5

		// Main simulation loop
		for (i = 0; i < simulation_cycles && !end_simulation; i = i + 1)
		begin
			#5 clk = 1;
			#5 clk = 0;
			
			if (i == 20)
				reset = 0;
			
			if (do_state_trace >= 0)
			begin
				$fwrite(state_trace_fp, "%d,%d,%d,%d,%d,%d,%d,%d\n", 
					`SS_STAGE.fsm[0].strand_fsm.instruction_valid_i,
					`SS_STAGE.fsm[0].strand_fsm.thread_state_ff,
					`SS_STAGE.fsm[1].strand_fsm.instruction_valid_i,
					`SS_STAGE.fsm[1].strand_fsm.thread_state_ff,
					`SS_STAGE.fsm[2].strand_fsm.instruction_valid_i,
					`SS_STAGE.fsm[2].strand_fsm.thread_state_ff,
					`SS_STAGE.fsm[3].strand_fsm.instruction_valid_i,
					`SS_STAGE.fsm[3].strand_fsm.thread_state_ff);
			end

			wb_pc <= gpgpu.core0.pipeline.ma_pc;

			// Display register dump
			if (do_register_trace)
			begin
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
		
		if (do_state_trace >= 0)
			$fclose(state_trace_fp);

		if (processor_halt)
			$display("***HALTED***");

		$display("ran for %d cycles", i);
		$display("strand states:");
		$display(" RAW conflict %d", gpgpu.performance_counters.raw_wait_count);
		$display(" wait for dcache/store %d", gpgpu.performance_counters.dcache_wait_count);
		$display(" wait for icache %d", gpgpu.performance_counters.icache_wait_count);

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

		if ($value$plusargs("autoflushl2=%d", do_autoflush_l2))
			flush_l2_cache;

		if ($value$plusargs("memdumpbase=%x", mem_dump_start)
			&& $value$plusargs("memdumplen=%x", mem_dump_length)
			&& $value$plusargs("memdumpfile=%s", filename))
		begin
			fp = $fopen(filename, "wb");
			for (i = 0; i < mem_dump_length; i = i + 4)
			begin
				mem_dat = `MEM_ARRAY[(mem_dump_start + i) / 4];
				dummy_return = $fputc(mem_dat[31:24], fp);
				dummy_return = $fputc(mem_dat[23:16], fp);
				dummy_return = $fputc(mem_dat[15:8], fp);
				dummy_return = $fputc(mem_dat[7:0], fp);
			end

			$fclose(fp);
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
			`MEM_ARRAY[tag * 16 * `L2_NUM_SETS + set * 16 + line_offset] = 
				gpgpu.l2_cache.l2_cache_read.cache_mem.data[{ way, set }]
				 >> ((15 - line_offset) * 32);
		end
	end
	endtask
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../fpga")
// End:
