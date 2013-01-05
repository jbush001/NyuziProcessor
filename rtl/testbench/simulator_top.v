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

`include "l2_cache.h"

//
// Top level module for simulator
//

module simulator_top;
	
	parameter NUM_STRANDS = 4;
	parameter NUM_REGS = 32;

	reg 			clk;
	reg				reset = 0;
	integer 		i;
	reg[1000:0] 	filename;
	reg[31:0] 		regtemp[0:17 * NUM_REGS * NUM_STRANDS - 1];
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
	
	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [31:0]	axi_araddr;		// From l2_cache of l2_cache.v
	wire [7:0]	axi_arlen;		// From l2_cache of l2_cache.v
	wire		axi_arready;		// From memory of axi_sram.v
	wire		axi_arvalid;		// From l2_cache of l2_cache.v
	wire [31:0]	axi_awaddr;		// From l2_cache of l2_cache.v
	wire [7:0]	axi_awlen;		// From l2_cache of l2_cache.v
	wire		axi_awready;		// From memory of axi_sram.v
	wire		axi_awvalid;		// From l2_cache of l2_cache.v
	wire		axi_bready;		// From l2_cache of l2_cache.v
	wire		axi_bvalid;		// From memory of axi_sram.v
	wire [31:0]	axi_rdata;		// From memory of axi_sram.v
	wire		axi_rready;		// From l2_cache of l2_cache.v
	wire		axi_rvalid;		// From memory of axi_sram.v
	wire [31:0]	axi_wdata;		// From l2_cache of l2_cache.v
	wire		axi_wlast;		// From l2_cache of l2_cache.v
	wire		axi_wready;		// From memory of axi_sram.v
	wire		axi_wvalid;		// From l2_cache of l2_cache.v
	wire [31:0]	display_data;		// From memory of axi_sram.v
	wire [31:0]	io_address;		// From core of core.v
	wire		io_read_en;		// From core of core.v
	wire [31:0]	io_write_data;		// From core of core.v
	wire		io_write_en;		// From core of core.v
	wire [25:0]	l2req_address;		// From core of core.v
	wire [3:0]	l2req_core;		// From core of core.v
	wire [511:0]	l2req_data;		// From core of core.v
	wire [63:0]	l2req_mask;		// From core of core.v
	wire [2:0]	l2req_op;		// From core of core.v
	wire		l2req_ready;		// From l2_cache of l2_cache.v
	wire [1:0]	l2req_strand;		// From core of core.v
	wire [1:0]	l2req_unit;		// From core of core.v
	wire		l2req_valid;		// From core of core.v
	wire [1:0]	l2req_way;		// From core of core.v
	wire [25:0]	l2rsp_address;		// From l2_cache of l2_cache.v
	wire [3:0]	l2rsp_core;		// From l2_cache of l2_cache.v
	wire [511:0]	l2rsp_data;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_op;		// From l2_cache of l2_cache.v
	wire		l2rsp_status;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_strand;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_unit;		// From l2_cache of l2_cache.v
	wire		l2rsp_update;		// From l2_cache of l2_cache.v
	wire		l2rsp_valid;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_way;		// From l2_cache of l2_cache.v
	// End of automatics
	
	wire[31:0] display_address = 0;
	reg[31:0] io_read_data = 0;

	core core(
		.halt_o(processor_halt),
		/*AUTOINST*/
		  // Outputs
		  .io_write_en		(io_write_en),
		  .io_read_en		(io_read_en),
		  .io_address		(io_address[31:0]),
		  .io_write_data	(io_write_data[31:0]),
		  .l2req_valid		(l2req_valid),
		  .l2req_core		(l2req_core[3:0]),
		  .l2req_strand		(l2req_strand[1:0]),
		  .l2req_unit		(l2req_unit[1:0]),
		  .l2req_op		(l2req_op[2:0]),
		  .l2req_way		(l2req_way[1:0]),
		  .l2req_address	(l2req_address[25:0]),
		  .l2req_data		(l2req_data[511:0]),
		  .l2req_mask		(l2req_mask[63:0]),
		  // Inputs
		  .clk			(clk),
		  .reset		(reset),
		  .io_read_data		(io_read_data[31:0]),
		  .l2req_ready		(l2req_ready),
		  .l2rsp_valid		(l2rsp_valid),
		  .l2rsp_core		(l2rsp_core[3:0]),
		  .l2rsp_status		(l2rsp_status),
		  .l2rsp_unit		(l2rsp_unit[1:0]),
		  .l2rsp_strand		(l2rsp_strand[1:0]),
		  .l2rsp_op		(l2rsp_op[1:0]),
		  .l2rsp_update		(l2rsp_update),
		  .l2rsp_address	(l2rsp_address[25:0]),
		  .l2rsp_way		(l2rsp_way[1:0]),
		  .l2rsp_data		(l2rsp_data[511:0]));

	l2_cache l2_cache(
				/*AUTOINST*/
			  // Outputs
			  .l2req_ready		(l2req_ready),
			  .l2rsp_valid		(l2rsp_valid),
			  .l2rsp_core		(l2rsp_core[3:0]),
			  .l2rsp_status		(l2rsp_status),
			  .l2rsp_unit		(l2rsp_unit[1:0]),
			  .l2rsp_strand		(l2rsp_strand[1:0]),
			  .l2rsp_op		(l2rsp_op[1:0]),
			  .l2rsp_update		(l2rsp_update),
			  .l2rsp_way		(l2rsp_way[1:0]),
			  .l2rsp_address	(l2rsp_address[25:0]),
			  .l2rsp_data		(l2rsp_data[511:0]),
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
			  .axi_rready		(axi_rready),
			  // Inputs
			  .clk			(clk),
			  .reset		(reset),
			  .l2req_valid		(l2req_valid),
			  .l2req_core		(l2req_core[3:0]),
			  .l2req_unit		(l2req_unit[1:0]),
			  .l2req_strand		(l2req_strand[1:0]),
			  .l2req_op		(l2req_op[2:0]),
			  .l2req_way		(l2req_way[1:0]),
			  .l2req_address	(l2req_address[25:0]),
			  .l2req_data		(l2req_data[511:0]),
			  .l2req_mask		(l2req_mask[63:0]),
			  .axi_awready		(axi_awready),
			  .axi_wready		(axi_wready),
			  .axi_bvalid		(axi_bvalid),
			  .axi_arready		(axi_arready),
			  .axi_rvalid		(axi_rvalid),
			  .axi_rdata		(axi_rdata[31:0]));

	axi_sram memory(/*AUTOINST*/
			// Outputs
			.axi_awready	(axi_awready),
			.axi_wready	(axi_wready),
			.axi_bvalid	(axi_bvalid),
			.axi_arready	(axi_arready),
			.axi_rvalid	(axi_rvalid),
			.axi_rdata	(axi_rdata[31:0]),
			.display_data	(display_data[31:0]),
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
			.axi_rready	(axi_rready),
			.display_address(display_address[31:0]));

	// Dummy peripheral.  This takes whatever is stored at location 32'hffff0000
	// and rotates it right one bit.
	reg[31:0] dummy_device_value = 0;
	
	always @(posedge clk)
	begin
		if (io_read_en && io_address == 0)
			io_read_data <= dummy_device_value;
		else
			io_read_data <= 32'hffffffff;

		if (io_write_en && io_address == 0)
			dummy_device_value <= { io_write_data[0], io_write_data[31:1] };
	end

	// For cosimulation loggin, track memory requests
	reg was_store = 0; 
	reg[1:0] store_strand = 0;
	reg[25:0] store_addr = 0;
	reg[63:0] store_mask = 0;
	reg[511:0] store_data = 0;
	reg[31:0] store_pc = 0;

	initial
	begin
		// Load executable binary into memory
		if ($value$plusargs("bin=%s", filename))
			$readmemh(filename, memory.memory);
		else
		begin
			$display("error opening file");
			$finish;
		end

		do_register_dump = 0; // Dump all registers at end

		`define PIPELINE core.pipeline
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
			for (i = 0; i < NUM_REGS * NUM_STRANDS; i = i + 1)		// ignore PC
				`PIPELINE.scalar_register_file.registers[i] = regtemp[i];

			for (i = 0; i < NUM_REGS * NUM_STRANDS; i = i + 1)
			begin
				`VREG_FILE.lane15.registers[i] = regtemp[(i + 8) * 16];
				`VREG_FILE.lane14.registers[i] = regtemp[(i + 8) * 16 + 1];
				`VREG_FILE.lane13.registers[i] = regtemp[(i + 8) * 16 + 2];
				`VREG_FILE.lane12.registers[i] = regtemp[(i + 8) * 16 + 3];
				`VREG_FILE.lane11.registers[i] = regtemp[(i + 8) * 16 + 4];
				`VREG_FILE.lane10.registers[i] = regtemp[(i + 8) * 16 + 5];
				`VREG_FILE.lane9.registers[i] = regtemp[(i + 8) * 16 + 6];
				`VREG_FILE.lane8.registers[i] = regtemp[(i + 8) * 16 + 7];
				`VREG_FILE.lane7.registers[i] = regtemp[(i + 8) * 16 + 8];
				`VREG_FILE.lane6.registers[i] = regtemp[(i + 8) * 16 + 9];
				`VREG_FILE.lane5.registers[i] = regtemp[(i + 8) * 16 + 10];
				`VREG_FILE.lane4.registers[i] = regtemp[(i + 8) * 16 + 11];
				`VREG_FILE.lane3.registers[i] = regtemp[(i + 8) * 16 + 12];
				`VREG_FILE.lane2.registers[i] = regtemp[(i + 8) * 16 + 13];
				`VREG_FILE.lane1.registers[i] = regtemp[(i + 8) * 16 + 14];
				`VREG_FILE.lane0.registers[i] = regtemp[(i + 8) * 16 + 15];
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

		// Reset the chip
		#5 reset = 1;
		#5 reset = 0;

		// Main simulation loop
		clk = 0;
		for (i = 0; i < simulation_cycles && !processor_halt; i = i + 1)
		begin
			#5 clk = 1;
			#5 clk = 0;
			
			if (do_state_trace >= 0)
			begin
				$fwrite(state_trace_fp, "%d,%d,%d,%d,%d,%d,%d,%d\n", 
					`SS_STAGE.strand_fsm0.instruction_valid_i,
					`SS_STAGE.strand_fsm0.thread_state_ff,
					`SS_STAGE.strand_fsm1.instruction_valid_i,
					`SS_STAGE.strand_fsm1.thread_state_ff,
					`SS_STAGE.strand_fsm2.instruction_valid_i,
					`SS_STAGE.strand_fsm2.thread_state_ff,
					`SS_STAGE.strand_fsm3.instruction_valid_i,
					`SS_STAGE.strand_fsm3.thread_state_ff);
			end

			wb_pc <= core.pipeline.ma_pc;

			// Display register dump
			if (do_register_trace)
			begin
				if (core.pipeline.wb_enable_vector_writeback)
				begin
					// New format
					$display("vwriteback %x %x %x %x %x", 
						wb_pc - 4, 
						core.pipeline.wb_writeback_reg[6:5], // strand
						core.pipeline.wb_writeback_reg[4:0], // register
						core.pipeline.wb_writeback_mask,
						core.pipeline.wb_writeback_value);
				end
				else if (core.pipeline.wb_enable_scalar_writeback)
				begin
					// New format
					$display("swriteback %x %x %x %x", 
						wb_pc - 4, 
						core.pipeline.wb_writeback_reg[6:5], // strand
						core.pipeline.wb_writeback_reg[4:0], // register
						core.pipeline.wb_writeback_value[31:0]);
				end
				
				if (was_store && !core.pipeline.stbuf_rollback)
				begin
					$display("store %x %x %x %x %x",
						store_pc,
						store_strand,
						{ store_addr, 6'd0 },
						store_mask,
						store_data);
				end
				
				// This gets delayed by a cycle (checked in block above)
				was_store = core.pipeline.dcache_store;
				if (was_store)
				begin
					store_pc = core.pipeline.ex_pc - 4;
					store_strand = core.pipeline.dcache_req_strand;
					store_addr = core.pipeline.dcache_addr;
					store_mask = core.pipeline.dcache_store_mask;
					store_data = core.pipeline.data_to_dcache;
				end
			end
		end
		
		if (do_state_trace >= 0)
			$fclose(state_trace_fp);

		if (processor_halt)
			$display("***HALTED***");

		$display("ran for %d cycles", i);
		$display(" instructions issued %d", `SS_STAGE.issue_count);
		$display(" instructions retired %d", `PIPELINE.writeback_stage.retire_count);
		$display(" mispredicted branches %d", `PIPELINE.execute_stage.mispredicted_branch_count);
		$display("strand states:");
		$display(" RAW conflict %d", 
			`SFSM0.raw_wait_count
			+ `SFSM1.raw_wait_count
			+ `SFSM2.raw_wait_count
			+ `SFSM3.raw_wait_count);
		$display(" wait for dcache/store %d", 
			`SFSM0.dcache_wait_count
			+ `SFSM1.dcache_wait_count
			+ `SFSM2.dcache_wait_count
			+ `SFSM3.dcache_wait_count);
		$display(" wait for icache %d", 
			`SFSM0.icache_wait_count
			+ `SFSM1.icache_wait_count
			+ `SFSM2.icache_wait_count
			+ `SFSM3.icache_wait_count);
		$display("L1 icache hits %d misses %d", 
			core.icache.hit_count, core.icache.miss_count);
		$display("L1 dcache hits %d misses %d", 
			core.dcache.hit_count, core.dcache.miss_count);
		$display("L1 store count %d",
			core.store_buffer.store_count);
		$display("L2 cache hits %d misses %d",
			l2_cache.hit_count, l2_cache.miss_count);

		if (do_register_dump)
		begin
			$display("REGISTERS:");
			// Dump the registers
			for (i = 0; i < NUM_REGS * NUM_STRANDS; i = i + 1)
				$display("%08x", `PIPELINE.scalar_register_file.registers[i]);
	
			for (i = 0; i < NUM_REGS * NUM_STRANDS; i = i + 1)
			begin
				$display("%08x", `PIPELINE.vector_register_file.lane15.registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane14.registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane13.registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane12.registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane11.registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane10.registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane9.registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane8.registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane7.registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane6.registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane5.registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane4.registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane3.registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane2.registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane1.registers[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane0.registers[i]);
			end
		end

		if ($value$plusargs("autoflushl2=%d", do_autoflush_l2))
			sync_l2_cache;

		if ($value$plusargs("memdumpbase=%x", mem_dump_start)
			&& $value$plusargs("memdumplen=%x", mem_dump_length)
			&& $value$plusargs("memdumpfile=%s", filename))
		begin
			fp = $fopen(filename, "wb");
			for (i = 0; i < mem_dump_length; i = i + 4)
			begin
				mem_dat = memory.memory[(mem_dump_start + i) / 4];
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
	reg[`L2_SET_INDEX_WIDTH - 1:0] set_index;
	reg[3:0] line_offset;
	reg[`L2_TAG_WIDTH - 1:0] flush_tag;
	integer set_index_count;
	integer line_offset_count;
	reg valid;

	task sync_l2_cache;
	begin
		for (set_index_count = 0; set_index_count < `L2_NUM_SETS; set_index_count
			= set_index_count + 1)
		begin
			set_index = set_index_count;
	
			{ valid, flush_tag } = l2_cache.l2_cache_tag.l2_tag_mem0.data[set_index];
			if (valid)
			begin
				for (line_offset_count = 0; line_offset_count < 16; line_offset_count 
					= line_offset_count + 1)
				begin
					line_offset = line_offset_count;
					memory.memory[{ flush_tag, set_index, line_offset }] = 
						l2_cache.l2_cache_read.cache_mem.data[{ 2'd0, set_index }]
						 >> ((15 - line_offset) * 32);
				end
			end

			{ valid, flush_tag } = l2_cache.l2_cache_tag.l2_tag_mem1.data[set_index];
			if (valid)
			begin
				for (line_offset_count = 0; line_offset_count < 16; line_offset_count 
					= line_offset_count + 1)
				begin
					line_offset = line_offset_count;
					memory.memory[{ flush_tag, set_index, line_offset }] = 
						l2_cache.l2_cache_read.cache_mem.data[{ 2'd1, set_index }]
						 >> ((15 - line_offset) * 32);
				end
			end

			{ valid, flush_tag } = l2_cache.l2_cache_tag.l2_tag_mem2.data[set_index];
			if (valid)
			begin
				for (line_offset_count = 0; line_offset_count < 16; line_offset_count 
					= line_offset_count + 1)
				begin
					line_offset = line_offset_count;
					memory.memory[{ flush_tag, set_index, line_offset }] = 
						l2_cache.l2_cache_read.cache_mem.data[{ 2'd2, set_index }]
						 >> ((15 - line_offset) * 32);
				end
			end

			{ valid, flush_tag } = l2_cache.l2_cache_tag.l2_tag_mem3.data[set_index];
			if (valid)
			begin
				for (line_offset_count = 0; line_offset_count < 16; line_offset_count 
					= line_offset_count + 1)
				begin
					line_offset = line_offset_count;
					memory.memory[{ flush_tag, set_index, line_offset }] = 
						l2_cache.l2_cache_read.cache_mem.data[{ 2'd3, set_index }]
						 >> ((15 - line_offset) * 32);
				end
			end
		end
	end
	endtask
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core")
// End:
