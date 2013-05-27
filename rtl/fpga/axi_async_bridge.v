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

//
// Asynchronous AXI->AXI bridge
//

module axi_async_bridge
	#(parameter ADDR_WIDTH = 32,
	parameter DATA_WIDTH = 32)

	(input						reset,
	
	// Slave Interface (from a master)
	input						clk_s,
	input [ADDR_WIDTH - 1:0]	axi_awaddr_s,   // Write address channel
	input [7:0]					axi_awlen_s,
	input						axi_awvalid_s,
	output						axi_awready_s,
	input [DATA_WIDTH - 1:0]	axi_wdata_s,    // Write data channel
	input 						axi_wlast_s,
	input 						axi_wvalid_s,
	output						axi_wready_s,
	output 						axi_bvalid_s,   // Write response channel
	input						axi_bready_s,
	input [ADDR_WIDTH - 1:0]	axi_araddr_s,   // Read address channel
	input [7:0]					axi_arlen_s,
	input 						axi_arvalid_s,
	output						axi_arready_s,
	input 						axi_rready_s,   // Read data channel
	output						axi_rvalid_s,         
	output [DATA_WIDTH - 1:0]	axi_rdata_s,

	// Master Interface (to a slave)
	input						clk_m,
	output [ADDR_WIDTH - 1:0]	axi_awaddr_m,   // Write address channel
	output [7:0]				axi_awlen_m,
	output						axi_awvalid_m,
	input						axi_awready_m,
	output [DATA_WIDTH - 1:0]	axi_wdata_m,    // Write data channel
	output 						axi_wlast_m,
	output 						axi_wvalid_m,
	input						axi_wready_m,
	input 						axi_bvalid_m,   // Write response channel
	output						axi_bready_m,
	output [ADDR_WIDTH - 1:0]	axi_araddr_m,   // Read address channel
	output [7:0]				axi_arlen_m,
	output 						axi_arvalid_m,
	input						axi_arready_m,
	output 						axi_rready_m,   // Read data channel
	input						axi_rvalid_m,         
	input [DATA_WIDTH - 1:0]	axi_rdata_m);

	localparam CONTROL_FIFO_LENGTH = 2;	// requirement of async_fifo
	localparam DATA_FIFO_LENGTH = 8;

	//
	// Write address from master->slave
	//
	wire write_address_full;
	wire write_address_empty;

	async_fifo #(ADDR_WIDTH + 8, CONTROL_FIFO_LENGTH) write_address_fifo(
		.reset(reset),
		.write_clock(clk_s),
		.write_enable(!write_address_full && axi_awvalid_s),
		.write_data({ axi_awaddr_s, axi_awlen_s }),
		.full(write_address_full),
		.read_clock(clk_m),
		.read_enable(!write_address_empty && axi_awready_m),
		.read_data({ axi_awaddr_m, axi_awlen_m }),
		.empty(write_address_empty));

	assign axi_awready_s = !write_address_full;
	assign axi_awvalid_m = !write_address_empty;
	
	//
	// Write data from master->slave
	//
	wire write_data_full;
	wire write_data_empty;

	async_fifo #(DATA_WIDTH + 1, DATA_FIFO_LENGTH) write_data_fifo(
		.reset(reset),
		.write_clock(clk_s),
		.write_enable(!write_data_full && axi_wvalid_s),
		.write_data({ axi_wdata_s, axi_wlast_s }),
		.full(write_data_full),
		.read_clock(clk_m),
		.read_enable(!write_data_empty && axi_wready_m),
		.read_data({ axi_wdata_m, axi_wlast_m }),
		.empty(write_data_empty));
	
	assign axi_wready_s = !write_data_full;
	assign axi_wvalid_m = !write_data_empty;
	
	//
	// Write response from slave->master
	//
	wire write_response_full;
	wire write_response_empty;
	
	async_fifo #(1, CONTROL_FIFO_LENGTH) write_response_fifo(
		.reset(reset),
		.write_clock(clk_m),
		.write_enable(!write_response_full && axi_bvalid_m),
		.write_data(1'b0),	// XXX pipe through actual error code
		.full(write_response_full),
		.read_clock(clk_s),
		.read_enable(!write_response_empty && axi_bready_s),
		.read_data(/* unconnected */),
		.empty(write_response_empty));

	assign axi_bvalid_s = !write_response_empty;
	assign axi_bready_m = !write_response_full;
	
	// 
	// Read address from master->slave
	//
	wire read_address_full;
	wire read_address_empty;

	async_fifo #(ADDR_WIDTH + 8, CONTROL_FIFO_LENGTH) read_address_fifo(
		.reset(reset),
		.write_clock(clk_s),
		.write_enable(!read_address_full && axi_arvalid_s),
		.write_data({ axi_araddr_s, axi_arlen_s }),
		.full(read_address_full),
		.read_clock(clk_m),
		.read_enable(!read_address_empty && axi_arready_m),
		.read_data({ axi_araddr_m, axi_arlen_m }),
		.empty(read_address_empty));

	assign axi_arready_s = !read_address_full;
	assign axi_arvalid_m = !read_address_empty;

	// 
	// Read data from slave->master
	//
	wire read_data_full;
	wire read_data_empty;
	
	async_fifo #(DATA_WIDTH, DATA_FIFO_LENGTH) read_data_fifo(
		.reset(reset),
		.write_clock(clk_m),
		.write_enable(!read_data_full && axi_rvalid_m),
		.write_data(axi_rdata_m),
		.full(read_data_full),
		.read_clock(clk_s),
		.read_enable(!read_data_empty && axi_rready_s),
		.read_data(axi_rdata_s),
		.empty(read_data_empty));
	
	assign axi_rready_m = !read_data_full;
	assign axi_rvalid_s = !read_data_empty;
endmodule
