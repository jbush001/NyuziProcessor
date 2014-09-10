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

`include "defines.sv"

//
// This routes AXI transactions between two masters and two slaves
// mapped into different regions of a common address space.
//

module axi_interconnect(
	input					clk,
	input					reset,

	// Master Interface 0 (address 0x00000000 - 0x0fffffff)
	axi_interface.master     axi_bus_m0,

	// Master Interface 1 (address 0x10000000 - 0xffffffff) 
	axi_interface.master    axi_bus_m1,

	// Slave Interface 0 (CPU/L2 cache)
	axi_interface.slave     axi_bus_s0,

	// Slave Interface 1 (Display Controller, read only)
	axi_interface.slave     axi_bus_s1);

	localparam M1_BASE_ADDRESS = 32'h10000000;

	typedef enum {
		STATE_ARBITRATE,
		STATE_ISSUE_ADDRESS,
		STATE_ACTIVE_BURST
	} burst_state_t;

	//
	// Write handling. Only slave interface 0 does writes.
	// XXX I don't explicitly handle the response in the state machine, but it
	// works because everything is in the correct state when the transaction is finished.
	// This could introduce a subtle bug if the behavior of the core changed.
	//
	burst_state_t write_state;
	logic[31:0] write_burst_address;
	logic[7:0] write_burst_length;	// Like axi_awlen, this is number of transfers minus 1
	logic write_master_select;

	assign axi_bus_m0.awaddr = write_burst_address;
	assign axi_bus_m0.awlen = write_burst_length;
	assign axi_bus_m0.wdata = axi_bus_s0.wdata;
	assign axi_bus_m0.wlast = axi_bus_s0.wlast;
	assign axi_bus_m0.bready = axi_bus_s0.bready;
	assign axi_bus_m1.awaddr = write_burst_address - M1_BASE_ADDRESS;
	assign axi_bus_m1.awlen = write_burst_length;
	assign axi_bus_m1.wdata = axi_bus_s0.wdata;
	assign axi_bus_m1.wlast = axi_bus_s0.wlast;
	assign axi_bus_m1.bready = axi_bus_s0.bready;
	
	assign axi_bus_m0.awvalid = write_master_select == 0 && write_state == STATE_ISSUE_ADDRESS;
	assign axi_bus_m1.awvalid = write_master_select == 1 && write_state == STATE_ISSUE_ADDRESS;
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			write_state <= STATE_ARBITRATE;
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			write_burst_address <= 32'h0;
			write_burst_length <= 8'h0;
			write_master_select <= 1'h0;
			// End of automatics
		end
		else if (write_state == STATE_ACTIVE_BURST)
		begin
			// Burst is active.  Check to see when it is finished.
			if (axi_bus_s0.wready && axi_bus_s0.wvalid)
			begin
				write_burst_length <= write_burst_length - 8'd1;
				if (write_burst_length == 0)
					write_state <= STATE_ARBITRATE;
			end
		end
		else if (write_state == STATE_ISSUE_ADDRESS)
		begin
			// Wait for the slave to accept the address and length
			if (axi_bus_s0.awready)
				write_state <= STATE_ACTIVE_BURST;
		end
		else if (axi_bus_s0.awvalid)
		begin
			// Start a new write transaction
			write_master_select <=  axi_bus_s0.awaddr[31:28] != 0;
			write_burst_address <= axi_bus_s0.awaddr;
			write_burst_length <= axi_bus_s0.awlen;
			write_state <= STATE_ISSUE_ADDRESS;
		end
	end
	
	always_comb
	begin
		if (write_master_select == 0)
		begin
			// Master Interface 0 is selected
			axi_bus_m0.wvalid = axi_bus_s0.wvalid && write_state == STATE_ACTIVE_BURST;
			axi_bus_m1.wvalid = 0;
			axi_bus_s0.awready = axi_bus_m0.awready && write_state == STATE_ISSUE_ADDRESS;
			axi_bus_s0.wready = axi_bus_m0.wready && write_state == STATE_ACTIVE_BURST;
			axi_bus_s0.bvalid = axi_bus_m0.bvalid;
		end
		else
		begin
			// Master interface 1 is selected
			axi_bus_m0.wvalid = 0;
			axi_bus_m1.wvalid = axi_bus_s0.wvalid && write_state == STATE_ACTIVE_BURST;
			axi_bus_s0.awready = axi_bus_m1.awready && write_state == STATE_ISSUE_ADDRESS;
			axi_bus_s0.wready = axi_bus_m1.wready && write_state == STATE_ACTIVE_BURST;
			axi_bus_s0.bvalid = axi_bus_m1.bvalid;
		end
	end
	
	//
	// Read handling.  Slave interface 1 has priority.
	//
	logic read_selected_slave;  // Which slave interface we are accepting request from
	logic read_selected_master; // Which master interface we are routing to
	logic[7:0] read_burst_length;	// Like axi_arlen, this is number of transfers minus one
	logic[31:0] read_burst_address;
	logic[1:0] read_state;
	wire axi_arready_m = read_selected_master ? axi_bus_m1.arready : axi_bus_m0.arready;
	wire axi_rready_m = read_selected_master ? axi_bus_m1.rready : axi_bus_m0.rready;
	wire axi_rvalid_m = read_selected_master ? axi_bus_m1.rvalid : axi_bus_m0.rvalid;
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			read_state <= STATE_ARBITRATE;

			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			read_burst_address <= 32'h0;
			read_burst_length <= 8'h0;
			read_selected_master <= 1'h0;
			read_selected_slave <= 1'h0;
			// End of automatics
		end
		else if (read_state == STATE_ACTIVE_BURST)
		begin
			// Burst is active.  Check to see when it is finished.
			if (axi_rready_m && axi_rvalid_m)
			begin
				read_burst_length <= read_burst_length - 8'd1;
				if (read_burst_length == 0)
					read_state <= STATE_ARBITRATE;
			end
		end
		else if (read_state == STATE_ISSUE_ADDRESS)
		begin
			// Wait for the slave to accept the address and length
			if (axi_arready_m)
				read_state <= STATE_ACTIVE_BURST;
		end
		else if (axi_bus_s1.arvalid)
		begin
			// Start a read burst from slave 1
			read_state <= STATE_ISSUE_ADDRESS;
			read_burst_address <= axi_bus_s1.araddr;
			read_burst_length <= axi_bus_s1.arlen;
			read_selected_slave <= 2'd1;
			read_selected_master <= axi_bus_s1.araddr[31:28] != 0;
		end
		else if (axi_bus_s0.arvalid)
		begin
			// Start a read burst from slave 0
			read_state <= STATE_ISSUE_ADDRESS;
			read_burst_address <= axi_bus_s0.araddr;
			read_burst_length <= axi_bus_s0.arlen;
			read_selected_slave <= 2'd0;
			read_selected_master <= axi_bus_s0.araddr[31:28] != 0;
		end
	end

	always_comb
	begin
		if (read_state == STATE_ARBITRATE)
		begin
			axi_bus_s0.rvalid = 0;
			axi_bus_s1.rvalid = 0;
			axi_bus_m0.rready = 0;
			axi_bus_m1.rready = 0;
			axi_bus_s0.arready = 0;
			axi_bus_s1.arready = 0;
		end
		else if (read_selected_slave == 0)
		begin
			axi_bus_s0.rvalid = axi_rvalid_m;
			axi_bus_s1.rvalid = 0;
			axi_bus_m0.rready = axi_bus_s0.rready && read_selected_master == 0; 
			axi_bus_m1.rready = axi_bus_s0.rready && read_selected_master == 1;
			axi_bus_s0.arready = axi_arready_m && read_state == STATE_ISSUE_ADDRESS;
			axi_bus_s1.arready = 0;
		end
		else 
		begin
			axi_bus_s0.rvalid = 0;
			axi_bus_s1.rvalid = axi_rvalid_m;
			axi_bus_m0.rready = axi_bus_s1.rready && read_selected_master == 0; 
			axi_bus_m1.rready = axi_bus_s1.rready && read_selected_master == 1;
			axi_bus_s0.arready = 0;
			axi_bus_s1.arready = axi_arready_m && read_state == STATE_ISSUE_ADDRESS;
		end
	end

	assign axi_bus_m0.arvalid = read_state == STATE_ISSUE_ADDRESS && read_selected_master == 0;
	assign axi_bus_m1.arvalid = read_state == STATE_ISSUE_ADDRESS && read_selected_master == 1;
	assign axi_bus_m0.araddr = read_burst_address;
	assign axi_bus_m1.araddr = read_burst_address - M1_BASE_ADDRESS;
	assign axi_bus_s0.rdata = read_selected_master ? axi_bus_m1.rdata : axi_bus_m0.rdata;
	assign axi_bus_s1.rdata = axi_bus_s0.rdata;

	// Note that we end up reusing read_burst_length to track how many beats are left
	// later.  At this point, the value of ARLEN should be ignored by slave
	// we are driving, so it won't break anything.
	assign axi_bus_m0.arlen = read_burst_length;
	assign axi_bus_m1.arlen = read_burst_length;
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

