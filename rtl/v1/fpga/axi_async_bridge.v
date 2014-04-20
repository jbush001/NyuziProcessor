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
	axi_interface               axi_bus_s,

	// Master Interface (to a slave)
	input						clk_m,
	axi_interface               axi_bus_m);

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
		.write_enable(!write_address_full && axi_bus_s.awvalid),
		.write_data({ axi_bus_s.awaddr, axi_bus_s.awlen }),
		.full(write_address_full),
		.read_clock(clk_m),
		.read_enable(!write_address_empty && axi_bus_m.awready),
		.read_data({ axi_bus_m.awaddr, axi_bus_m.awlen }),
		.empty(write_address_empty));

	assign axi_bus_s.awready = !write_address_full;
	assign axi_bus_m.awvalid = !write_address_empty;
	
	//
	// Write data from master->slave
	//
	wire write_data_full;
	wire write_data_empty;

	async_fifo #(DATA_WIDTH + 1, DATA_FIFO_LENGTH) write_data_fifo(
		.reset(reset),
		.write_clock(clk_s),
		.write_enable(!write_data_full && axi_bus_s.wvalid),
		.write_data({ axi_bus_s.wdata, axi_bus_s.wlast }),
		.full(write_data_full),
		.read_clock(clk_m),
		.read_enable(!write_data_empty && axi_bus_m.wready),
		.read_data({ axi_bus_m.wdata, axi_bus_m.wlast }),
		.empty(write_data_empty));
	
	assign axi_bus_s.wready = !write_data_full;
	assign axi_bus_m.wvalid = !write_data_empty;
	
	//
	// Write response from slave->master
	//
	wire write_response_full;
	wire write_response_empty;
	
	async_fifo #(1, CONTROL_FIFO_LENGTH) write_response_fifo(
		.reset(reset),
		.write_clock(clk_m),
		.write_enable(!write_response_full && axi_bus_m.bvalid),
		.write_data(1'b0),	// XXX pipe through actual error code
		.full(write_response_full),
		.read_clock(clk_s),
		.read_enable(!write_response_empty && axi_bus_s.bready),
		.read_data(/* unconnected */),
		.empty(write_response_empty));

	assign axi_bus_s.bvalid = !write_response_empty;
	assign axi_bus_m.bready = !write_response_full;
	
	// 
	// Read address from master->slave
	//
	wire read_address_full;
	wire read_address_empty;

	async_fifo #(ADDR_WIDTH + 8, CONTROL_FIFO_LENGTH) read_address_fifo(
		.reset(reset),
		.write_clock(clk_s),
		.write_enable(!read_address_full && axi_bus_s.arvalid),
		.write_data({ axi_bus_s.araddr, axi_bus_s.arlen }),
		.full(read_address_full),
		.read_clock(clk_m),
		.read_enable(!read_address_empty && axi_bus_m.arready),
		.read_data({ axi_bus_m.araddr, axi_bus_m.arlen }),
		.empty(read_address_empty));

	assign axi_bus_s.arready = !read_address_full;
	assign axi_bus_m.arvalid = !read_address_empty;

	// 
	// Read data from slave->master
	//
	wire read_data_full;
	wire read_data_empty;
	
	async_fifo #(DATA_WIDTH, DATA_FIFO_LENGTH) read_data_fifo(
		.reset(reset),
		.write_clock(clk_m),
		.write_enable(!read_data_full && axi_bus_m.rvalid),
		.write_data(axi_bus_m.rdata),
		.full(read_data_full),
		.read_clock(clk_s),
		.read_enable(!read_data_empty && axi_bus_s.rready),
		.read_data(axi_bus_s.rdata),
		.empty(read_data_empty));
	
	assign axi_bus_m.rready = !read_data_full;
	assign axi_bus_s.rvalid = !read_data_empty;
endmodule
