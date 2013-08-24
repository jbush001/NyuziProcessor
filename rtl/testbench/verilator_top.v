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
	end

	always @(posedge clk)
	begin
		if (processor_halt && !reset)
		begin
			$display("*** HALTED ***");
			$finish;
		end
	
		if (io_write_en && io_address == 4)
			$write("%c", io_write_data[7:0]);
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
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../fpga")
// End:

