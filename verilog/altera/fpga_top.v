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

// Dummy top level entity for synthesis

module fpga_top(
	input						clk,
	output [31:0]				axi_awaddr,         // Write address channel
	output [7:0]				axi_awlen,
	output 						axi_awvalid,
	input						axi_awready,
	output [31:0]				axi_wdata,          // Write data channel
	output 						axi_wlast,
	output 						axi_wvalid,
	input						axi_wready,
	input						axi_bvalid,         // Write response channel
	output						axi_bready,
	output [31:0]				axi_araddr,         // Read address channel
	output [7:0]				axi_arlen,
	output 						axi_arvalid,
	input						axi_arready,
	output 						axi_rready,     // Read data channel
	input						axi_rvalid,         
	input [31:0]				axi_rdata);

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire		halt_o;			// From core of core.v
	wire		l2req_ack;		// From l2_cache of l2_cache.v
	wire [25:0]	l2req_address;		// From core of core.v
	wire [511:0]	l2req_data;		// From core of core.v
	wire [63:0]	l2req_mask;		// From core of core.v
	wire [2:0]	l2req_op;		// From core of core.v
	wire [1:0]	l2req_strand;		// From core of core.v
	wire [1:0]	l2req_unit;		// From core of core.v
	wire		l2req_valid;		// From core of core.v
	wire [1:0]	l2req_way;		// From core of core.v
	wire [511:0]	l2rsp_data;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_op;		// From l2_cache of l2_cache.v
	wire		l2rsp_status;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_strand;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_unit;		// From l2_cache of l2_cache.v
	wire		l2rsp_update;		// From l2_cache of l2_cache.v
	wire		l2rsp_valid;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_way;		// From l2_cache of l2_cache.v
	// End of automatics
	
	core core(/*AUTOINST*/
		  // Outputs
		  .l2req_valid		(l2req_valid),
		  .l2req_strand		(l2req_strand[1:0]),
		  .l2req_unit		(l2req_unit[1:0]),
		  .l2req_op		(l2req_op[2:0]),
		  .l2req_way		(l2req_way[1:0]),
		  .l2req_address	(l2req_address[25:0]),
		  .l2req_data		(l2req_data[511:0]),
		  .l2req_mask		(l2req_mask[63:0]),
		  .halt_o		(halt_o),
		  // Inputs
		  .clk			(clk),
		  .l2req_ack		(l2req_ack),
		  .l2rsp_valid		(l2rsp_valid),
		  .l2rsp_status		(l2rsp_status),
		  .l2rsp_unit		(l2rsp_unit[1:0]),
		  .l2rsp_strand		(l2rsp_strand[1:0]),
		  .l2rsp_op		(l2rsp_op[1:0]),
		  .l2rsp_update		(l2rsp_update),
		  .l2rsp_way		(l2rsp_way[1:0]),
		  .l2rsp_data		(l2rsp_data[511:0]));
	
	l2_cache l2_cache(/*AUTOINST*/
			  // Outputs
			  .l2req_ack		(l2req_ack),
			  .l2rsp_valid		(l2rsp_valid),
			  .l2rsp_status		(l2rsp_status),
			  .l2rsp_unit		(l2rsp_unit[1:0]),
			  .l2rsp_strand		(l2rsp_strand[1:0]),
			  .l2rsp_op		(l2rsp_op[1:0]),
			  .l2rsp_update		(l2rsp_update),
			  .l2rsp_way		(l2rsp_way[1:0]),
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

endmodule

// Local Variables:
// verilog-library-flags:("-y ../rtl")
// End: