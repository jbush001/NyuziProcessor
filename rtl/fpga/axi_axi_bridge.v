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

module axi_axi_bridge
	#(parameter BUS_WIDTH = 32)

	// Master
	(input						clk0,
	input [31:0]				axi_awaddr0,   // Write address channel
	input [7:0]					axi_awlen0,
	input						axi_awvalid0,
	output						axi_awready0,
	input [31:0]				axi_wdata0,    // Write data channel
	input 						axi_wlast0,
	input 						axi_wvalid0,
	output						axi_wready0,
	output 						axi_bvalid0,   // Write response channel
	input						axi_bready0,
	input [31:0]    			axi_araddr0,   // Read address channel
	input [7:0]					axi_arlen0,
	input 						axi_arvalid0,
	output						axi_arready0,
	input 						axi_rready0,   // Read data channel
	output						axi_rvalid0,         
	output [31:0]				axi_rdata0,

	// Slave
	output						clk1,
	output [31:0]				axi_awaddr1,   // Write address channel
	output [7:0]				axi_awlen1,
	output						axi_awvalid1,
	input						axi_awready1,
	output [31:0]				axi_wdata1,    // Write data channel
	output 						axi_wlast1,
	output 						axi_wvalid1,
	input						axi_wready1,
	input 						axi_bvalid1,   // Write response channel
	output						axi_bready1,
	output [31:0]    			axi_araddr1,   // Read address channel
	output [7:0]				axi_arlen1,
	output 						axi_arvalid1,
	input						axi_arready1,
	output 						axi_rready1,   // Read data channel
	input						axi_rvalid1,         
	input [31:0]				axi_rdata1);

	localparam CONTROL_FIFO_LENGTH = 1;
	localparam DATA_FIFO_LENGTH = 8;

	//
	// Write address from master->slave
	//
	wire write_address_full;
	wire write_address_empty;

	async_fifo #(BUS_WIDTH + 8, CONTROL_FIFO_LENGTH) write_address_fifo(
		.write_clock(clk0),
		.write_enable(!write_address_full && axi_awvalid0),
		.write_data({ axi_awaddr0, axi_awlen0 }),
		.full(write_address_full),
		.read_clock(clk1),
		.read_enable(!write_address_empty && axi_awready1),
		.read_data({ axi_awaddr1, axi_awlen1 }),
		.empty(write_address_empty));

	assign axi_awready0 = !write_address_full;
	assign axi_awvalid1 = !write_address_empty;
	
	//
	// Write data from master->slave
	//
	wire write_data_full;
	wire write_data_empty;

	async_fifo #(BUS_WIDTH + 1, DATA_FIFO_LENGTH) write_data_fifo(
		.write_clock(clk0),
		.write_enable(!write_data_full && axi_wvalid0),
		.write_data({ axi_wdata0, axi_wlast0 }),
		.full(write_data_full),
		.read_clock(clk1),
		.read_enable(!write_data_empty && axi_wready1),
		.read_data({ axi_wdata1, axi_wlast1 }),
		.empty(write_data_empty));
	
	assign axi_wready0 = !write_data_full;
	assign axi_wvalid1 = !write_data_empty;
	
	//
	// Write response from slave->master
	//
	wire write_response_full;
	wire write_response_empty;
	
	async_fifo #(1, CONTROL_FIFO_LENGTH) write_response_fifo(
		.write_clock(clk1),
		.write_enable(!write_data_full && axi_wvalid1),
		.write_data(1'b0),	// XXX pipe through actual error code
		.full(write_response_full),
		.read_clock(clk0),
		.read_enable(!write_data_empty && axi_ready0),
		.read_data(/* unconnected */),
		.empty(write_response_empty));

	assign axi_bvalid0 = !write_data_empty;
	assign axi_bready1 = !write_data_full;
	
	// 
	// Read address from master->slave
	//
	wire read_address_full;
	wire read_address_empty;

	async_fifo #(BUS_WIDTH + 8, CONTROL_FIFO_LENGTH) read_address_fifo(
		.write_clock(clk0),
		.write_enable(!read_address_full && axi_awvalid1),
		.write_data({ axi_awaddr0, axi_awlen0 }),
		.full(read_address_full),
		.read_clock(clk1),
		.read_enable(!read_address_empty && axi_awready1),
		.read_data({ axi_awaddr1, axi_awlen1 }),
		.empty(read_address_empty));

	assign axi_arready1 = !read_address_full;
	assign axi_arvalid0 = !read_address_empty;

	// 
	// Read data from slave->master
	//
	wire read_data_full;
	wire read_data_empty;
	
	async_fifo #(BUS_WIDTH, DATA_FIFO_LENGTH) read_data_fifo(
		.write_clock(clk1),
		.write_enable(!read_data_full && axi_rvalid0),
		.write_data(axi_rdata0),
		.full(read_data_full),
		.read_clock(clk0),
		.read_enable(!read_data_empty && axi_rready1),
		.read_data(axi_rdata1),
		.empty(read_data_empty));
	
	assign axi_rready0 = !read_data_full;
	assign axi_rvalid1 = !read_data_empty;

endmodule
