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
	
	axi_internal_ram memory(
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

	integer stop_countdown = 100;
	always @(posedge clk)
	begin
		if (processor_halt && !reset)
			stop_countdown = stop_countdown - 1;
		
		if (stop_countdown == 0)
		begin
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

endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../fpga")
// End:

