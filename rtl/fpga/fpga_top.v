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

module fpga_top(
	input						clk50,
	output reg[17:0]			red_led,
	output reg[8:0]				green_led,
	output reg[6:0]				hex0,
	output reg[6:0]				hex1,
	output reg[6:0]				hex2,
	output reg[6:0]				hex3,
	output						uart_tx,
	input						uart_rx);

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [31:0]	axi_araddr;		// From l2_cache of l2_cache.v
	wire [7:0]	axi_arlen;		// From l2_cache of l2_cache.v
	wire		axi_arready;		// From memory of fpga_axi_mem.v
	wire		axi_arvalid;		// From l2_cache of l2_cache.v
	wire [31:0]	axi_awaddr;		// From l2_cache of l2_cache.v
	wire [7:0]	axi_awlen;		// From l2_cache of l2_cache.v
	wire		axi_awready;		// From memory of fpga_axi_mem.v
	wire		axi_awvalid;		// From l2_cache of l2_cache.v
	wire		axi_bready;		// From l2_cache of l2_cache.v
	wire		axi_bvalid;		// From memory of fpga_axi_mem.v
	wire [31:0]	axi_rdata;		// From memory of fpga_axi_mem.v
	wire		axi_rready;		// From l2_cache of l2_cache.v
	wire		axi_rvalid;		// From memory of fpga_axi_mem.v
	wire [31:0]	axi_wdata;		// From l2_cache of l2_cache.v
	wire		axi_wlast;		// From l2_cache of l2_cache.v
	wire		axi_wready;		// From memory of fpga_axi_mem.v
	wire		axi_wvalid;		// From l2_cache of l2_cache.v
	wire		halt_o;			// From core of core.v
	wire [31:0]	io_address;		// From core of core.v
	wire		io_read_en;		// From core of core.v
	wire [31:0]	io_write_data;		// From core of core.v
	wire		io_write_en;		// From core of core.v
	wire [25:0]	l2req_address;		// From core of core.v
	wire [511:0]	l2req_data;		// From core of core.v
	wire [63:0]	l2req_mask;		// From core of core.v
	wire [2:0]	l2req_op;		// From core of core.v
	wire		l2req_ready;		// From l2_cache of l2_cache.v
	wire [1:0]	l2req_strand;		// From core of core.v
	wire [1:0]	l2req_unit;		// From core of core.v
	wire		l2req_valid;		// From core of core.v
	wire [1:0]	l2req_way;		// From core of core.v
	wire [25:0]	l2rsp_address;		// From l2_cache of l2_cache.v
	wire [`CORE_INDEX_WIDTH-1:0] l2rsp_core;// From l2_cache of l2_cache.v
	wire [511:0]	l2rsp_data;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_op;		// From l2_cache of l2_cache.v
	wire		l2rsp_status;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_strand;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_unit;		// From l2_cache of l2_cache.v
	wire [`NUM_CORES-1:0] l2rsp_update;	// From l2_cache of l2_cache.v
	wire		l2rsp_valid;		// From l2_cache of l2_cache.v
	wire [`NUM_CORES*2-1:0] l2rsp_way;	// From l2_cache of l2_cache.v
	wire		pc_event_cond_branch_not_taken;// From core of core.v
	wire		pc_event_cond_branch_taken;// From core of core.v
	wire [3:0]	pc_event_dcache_wait;	// From core of core.v
	wire [3:0]	pc_event_icache_wait;	// From core of core.v
	wire		pc_event_instruction_issue;// From core of core.v
	wire		pc_event_instruction_retire;// From core of core.v
	wire		pc_event_l1d_hit;	// From core of core.v
	wire		pc_event_l1d_miss;	// From core of core.v
	wire		pc_event_l1i_hit;	// From core of core.v
	wire		pc_event_l1i_miss;	// From core of core.v
	wire		pc_event_l2_hit;	// From l2_cache of l2_cache.v
	wire		pc_event_l2_miss;	// From l2_cache of l2_cache.v
	wire		pc_event_l2_wait;	// From l2_cache of l2_cache.v
	wire		pc_event_l2_writeback;	// From l2_cache of l2_cache.v
	wire		pc_event_mispredicted_branch;// From core of core.v
	wire [3:0]	pc_event_raw_wait;	// From core of core.v
	wire		pc_event_store;		// From l2_cache of l2_cache.v
	wire		pc_event_uncond_branch;	// From core of core.v
	// End of automatics

	wire reset;
	wire[31:0] loader_addr;
	wire[31:0] loader_data;
	wire loader_we;

	// Divide clock down to 25 Mhz
	reg clk = 0;
	always @(posedge clk50)
		clk = !clk;		// Divide down to 25 Mhz

	wire [31:0] io_read_data;

	core core(/*AUTOINST*/
		  // Outputs
		  .halt_o		(halt_o),
		  .io_write_en		(io_write_en),
		  .io_read_en		(io_read_en),
		  .io_address		(io_address[31:0]),
		  .io_write_data	(io_write_data[31:0]),
		  .l2req_valid		(l2req_valid),
		  .l2req_strand		(l2req_strand[1:0]),
		  .l2req_unit		(l2req_unit[1:0]),
		  .l2req_op		(l2req_op[2:0]),
		  .l2req_way		(l2req_way[1:0]),
		  .l2req_address	(l2req_address[25:0]),
		  .l2req_data		(l2req_data[511:0]),
		  .l2req_mask		(l2req_mask[63:0]),
		  .pc_event_raw_wait	(pc_event_raw_wait[3:0]),
		  .pc_event_dcache_wait	(pc_event_dcache_wait[3:0]),
		  .pc_event_icache_wait	(pc_event_icache_wait[3:0]),
		  .pc_event_l1d_hit	(pc_event_l1d_hit),
		  .pc_event_l1d_miss	(pc_event_l1d_miss),
		  .pc_event_l1i_hit	(pc_event_l1i_hit),
		  .pc_event_l1i_miss	(pc_event_l1i_miss),
		  .pc_event_mispredicted_branch(pc_event_mispredicted_branch),
		  .pc_event_instruction_issue(pc_event_instruction_issue),
		  .pc_event_instruction_retire(pc_event_instruction_retire),
		  .pc_event_uncond_branch(pc_event_uncond_branch),
		  .pc_event_cond_branch_taken(pc_event_cond_branch_taken),
		  .pc_event_cond_branch_not_taken(pc_event_cond_branch_not_taken),
		  // Inputs
		  .clk			(clk),
		  .reset		(reset),
		  .io_read_data		(io_read_data[31:0]),
		  .l2req_ready		(l2req_ready),
		  .l2rsp_valid		(l2rsp_valid),
		  .l2rsp_core		(l2rsp_core[`CORE_INDEX_WIDTH-1:0]),
		  .l2rsp_status		(l2rsp_status),
		  .l2rsp_unit		(l2rsp_unit[1:0]),
		  .l2rsp_strand		(l2rsp_strand[1:0]),
		  .l2rsp_op		(l2rsp_op[1:0]),
		  .l2rsp_update		(l2rsp_update),
		  .l2rsp_address	(l2rsp_address[25:0]),
		  .l2rsp_way		(l2rsp_way[1:0]),
		  .l2rsp_data		(l2rsp_data[511:0]));
	
	always @(posedge clk)
	begin
		if (io_write_en)
		begin
			case (io_address)
				0: red_led <= io_write_data[17:0];
				4: green_led <= io_write_data[8:0];
				8: hex0 <= io_write_data[6:0];
				12: hex1 <= io_write_data[6:0];
				16: hex2 <= io_write_data[6:0];
				20: hex3 <= io_write_data[6:0];
			endcase
		end
	end
	
	uart #(.BASE_ADDRESS(24), .BAUD_DIVIDE(27)) uart(
		.rx(uart_rx),
		.tx(uart_tx),
		/*AUTOINST*/
							  // Outputs
							  .io_read_data		(io_read_data[31:0]),
							  // Inputs
							  .clk			(clk),
							  .reset		(reset),
							  .io_address		(io_address[31:0]),
							  .io_read_en		(io_read_en),
							  .io_write_data	(io_write_data[31:0]),
							  .io_write_en		(io_write_en));

	l2_cache l2_cache(
			  .l2req_core		(0),
			/*AUTOINST*/
			  // Outputs
			  .l2req_ready		(l2req_ready),
			  .l2rsp_valid		(l2rsp_valid),
			  .l2rsp_core		(l2rsp_core[`CORE_INDEX_WIDTH-1:0]),
			  .l2rsp_status		(l2rsp_status),
			  .l2rsp_unit		(l2rsp_unit[1:0]),
			  .l2rsp_strand		(l2rsp_strand[1:0]),
			  .l2rsp_op		(l2rsp_op[1:0]),
			  .l2rsp_update		(l2rsp_update[`NUM_CORES-1:0]),
			  .l2rsp_way		(l2rsp_way[`NUM_CORES*2-1:0]),
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
			  .pc_event_l2_hit	(pc_event_l2_hit),
			  .pc_event_l2_miss	(pc_event_l2_miss),
			  .pc_event_store	(pc_event_store),
			  .pc_event_l2_wait	(pc_event_l2_wait),
			  .pc_event_l2_writeback(pc_event_l2_writeback),
			  // Inputs
			  .clk			(clk),
			  .reset		(reset),
			  .l2req_valid		(l2req_valid),
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
			  
	fpga_axi_mem #(.MEM_SIZE('h1000)) memory(
						/*AUTOINST*/
						 // Outputs
						 .axi_awready		(axi_awready),
						 .axi_wready		(axi_wready),
						 .axi_bvalid		(axi_bvalid),
						 .axi_arready		(axi_arready),
						 .axi_rvalid		(axi_rvalid),
						 .axi_rdata		(axi_rdata[31:0]),
						 // Inputs
						 .clk			(clk),
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
						 .loader_we		(loader_we),
						 .loader_addr		(loader_addr[31:0]),
						 .loader_data		(loader_data[31:0]));

	jtagloader jtagloader(
		.we(loader_we),
		.addr(loader_addr),
		.data(loader_data),
		.reset(reset),
		.clk(clk));
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../testbench")
// End:
