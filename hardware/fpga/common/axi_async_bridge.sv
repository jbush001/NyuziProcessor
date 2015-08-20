// 
// Copyright 2011-2015 Jeff Bush
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
// Asynchronous AXI->AXI bridge.  This safely transfers AXI requests and responses
// between two clock domains running at different speeds.
//

module axi_async_bridge
	#(parameter ADDR_WIDTH = 32,
	parameter DATA_WIDTH = 32)

	(input						reset,
	
	// Slave Interface (from a master)
	input						clk_s,
	axi4_interface.slave        axi_bus_s,

	// Master Interface (to a slave)
	input						clk_m,
	axi4_interface.master       axi_bus_m);

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
		.write_enable(!write_address_full && axi_bus_s.m_awvalid),
		.write_data({ axi_bus_s.m_awaddr, axi_bus_s.m_awlen }),
		.full(write_address_full),
		.read_clock(clk_m),
		.read_enable(!write_address_empty && axi_bus_m.s_awready),
		.read_data({ axi_bus_m.m_awaddr, axi_bus_m.m_awlen }),
		.empty(write_address_empty));

	assign axi_bus_s.s_awready = !write_address_full;
	assign axi_bus_m.m_awvalid = !write_address_empty;
	
	//
	// Write data from master->slave
	//
	wire write_data_full;
	wire write_data_empty;

	async_fifo #(DATA_WIDTH + 1, DATA_FIFO_LENGTH) write_data_fifo(
		.reset(reset),
		.write_clock(clk_s),
		.write_enable(!write_data_full && axi_bus_s.m_wvalid),
		.write_data({ axi_bus_s.m_wdata, axi_bus_s.m_wlast }),
		.full(write_data_full),
		.read_clock(clk_m),
		.read_enable(!write_data_empty && axi_bus_m.s_wready),
		.read_data({ axi_bus_m.m_wdata, axi_bus_m.m_wlast }),
		.empty(write_data_empty));
	
	assign axi_bus_s.s_wready = !write_data_full;
	assign axi_bus_m.m_wvalid = !write_data_empty;
	
	//
	// Write response from slave->master
	//
	wire write_response_full;
	wire write_response_empty;
	
	async_fifo #(1, CONTROL_FIFO_LENGTH) write_response_fifo(
		.reset(reset),
		.write_clock(clk_m),
		.write_enable(!write_response_full && axi_bus_m.s_bvalid),
		.write_data(1'b0),	// XXX pipe through actual error code
		.full(write_response_full),
		.read_clock(clk_s),
		.read_enable(!write_response_empty && axi_bus_s.m_bready),
		.read_data(/* unconnected */),
		.empty(write_response_empty));

	assign axi_bus_s.s_bvalid = !write_response_empty;
	assign axi_bus_m.m_bready = !write_response_full;
	
	// 
	// Read address from master->slave
	//
	wire read_address_full;
	wire read_address_empty;

	async_fifo #(ADDR_WIDTH + 8, CONTROL_FIFO_LENGTH) read_address_fifo(
		.reset(reset),
		.write_clock(clk_s),
		.write_enable(!read_address_full && axi_bus_s.m_arvalid),
		.write_data({ axi_bus_s.m_araddr, axi_bus_s.m_arlen }),
		.full(read_address_full),
		.read_clock(clk_m),
		.read_enable(!read_address_empty && axi_bus_m.s_arready),
		.read_data({ axi_bus_m.m_araddr, axi_bus_m.m_arlen }),
		.empty(read_address_empty));

	assign axi_bus_s.s_arready = !read_address_full;
	assign axi_bus_m.m_arvalid = !read_address_empty;

	// 
	// Read data from slave->master
	//
	wire read_data_full;
	wire read_data_empty;
	
	async_fifo #(DATA_WIDTH, DATA_FIFO_LENGTH) read_data_fifo(
		.reset(reset),
		.write_clock(clk_m),
		.write_enable(!read_data_full && axi_bus_m.s_rvalid),
		.write_data(axi_bus_m.s_rdata),
		.full(read_data_full),
		.read_clock(clk_s),
		.read_enable(!read_data_empty && axi_bus_s.m_rready),
		.read_data(axi_bus_s.s_rdata),
		.empty(read_data_empty));
	
	assign axi_bus_m.m_rready = !read_data_full;
	assign axi_bus_s.s_rvalid = !read_data_empty;
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

