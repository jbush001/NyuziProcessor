// 
// Copyright 2011-2013 Jeff Bush
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
// This routes AXI transactions between two masters and two slaves
// mapped into different regions of a common address space.
//

module axi_interconnect(
	input					clk,
	input					reset,

	// Master Interface 0 (address 0x00000000 - 0x0fffffff)
	output [31:0]			axi_awaddr_m0, 
	output [7:0]			axi_awlen_m0,
	output 					axi_awvalid_m0,
	input 					axi_awready_m0,
	output [31:0]			axi_wdata_m0,  
	output					axi_wlast_m0,
	output reg				axi_wvalid_m0,
	input					axi_wready_m0,
	input					axi_bvalid_m0, 
	output					axi_bready_m0,
	output [31:0]			axi_araddr_m0,
	output [7:0]			axi_arlen_m0,
	output 					axi_arvalid_m0,
	input					axi_arready_m0,
	output reg				axi_rready_m0,
	input					axi_rvalid_m0,         
	input [31:0]			axi_rdata_m0,

	// Master Interface 1 (address 0x10000000 - 0xffffffff) 
	output [31:0]			axi_awaddr_m1, 
	output [7:0]			axi_awlen_m1,
	output 					axi_awvalid_m1,
	input 					axi_awready_m1,
	output [31:0]			axi_wdata_m1,  
	output					axi_wlast_m1,
	output reg				axi_wvalid_m1,
	input					axi_wready_m1,
	input					axi_bvalid_m1, 
	output					axi_bready_m1,
	output [31:0]			axi_araddr_m1,
	output [7:0]			axi_arlen_m1,
	output 					axi_arvalid_m1,
	input					axi_arready_m1,
	output reg				axi_rready_m1,
	input					axi_rvalid_m1,         
	input [31:0]			axi_rdata_m1,

	// Slave Interface 0 (CPU/L2 cache)
	input [31:0]			axi_awaddr_s0, 
	input [7:0]				axi_awlen_s0,
	input 					axi_awvalid_s0,
	output reg				axi_awready_s0,
	input [31:0]			axi_wdata_s0,  
	input					axi_wlast_s0,
	input 					axi_wvalid_s0,
	output reg				axi_wready_s0,
	output reg				axi_bvalid_s0, 
	input					axi_bready_s0,
	input [31:0]			axi_araddr_s0,
	input [7:0]				axi_arlen_s0,
	input 					axi_arvalid_s0,
	output reg				axi_arready_s0,
	input 					axi_rready_s0,
	output reg				axi_rvalid_s0,         
	output [31:0]			axi_rdata_s0,

	// Slave Interface 1 (Display Controller, read only)
	input [31:0]			axi_araddr_s1,
	input [7:0]				axi_arlen_s1,
	input 					axi_arvalid_s1,
	output reg				axi_arready_s1,
	input 					axi_rready_s1,
	output reg				axi_rvalid_s1,         
	output [31:0]			axi_rdata_s1);

	localparam M1_BASE_ADDRESS = 32'h10000000;

	localparam STATE_ARBITRATE = 0;
	localparam STATE_ISSUE_ADDRESS = 1;
	localparam STATE_ACTIVE_BURST = 2;

	//
	// Write handling. Only slave interface 0 does writes.
	// XXX I don't explicitly handle the response in the state machine, but it
	// works because everything is in the correct state when the transaction is finished.
	// This could introduce a subtle bug if the behavior of the core changed.
	//
	reg[1:0] write_state;
	reg[31:0] write_burst_address;
	reg[7:0] write_burst_length;
	reg write_master_select;

	assign axi_awaddr_m0 = write_burst_address;
	assign axi_awlen_m0 = write_burst_length;
	assign axi_wdata_m0 = axi_wdata_s0;
	assign axi_wlast_m0 = axi_wlast_s0;
	assign axi_bready_m0 = axi_bready_s0;
	assign axi_awaddr_m1 = write_burst_address - M1_BASE_ADDRESS;
	assign axi_awlen_m1 = write_burst_length;
	assign axi_wdata_m1 = axi_wdata_s0;
	assign axi_wlast_m1 = axi_wlast_s0;
	assign axi_bready_m1 = axi_bready_s0;
	
	assign axi_awvalid_m0 = write_master_select == 0 && write_state == STATE_ISSUE_ADDRESS;
	assign axi_awvalid_m1 = write_master_select == 1 && write_state == STATE_ISSUE_ADDRESS;
	
	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			write_burst_address <= 32'h0;
			write_burst_length <= 8'h0;
			write_master_select <= 1'h0;
			write_state <= 2'h0;
			// End of automatics
		end
		else if (write_state == STATE_ACTIVE_BURST)
		begin
			// Burst is active.  Check to see when it is finished.
			if (axi_wready_s0 && axi_wvalid_s0)
			begin
				write_burst_length <= write_burst_length - 8'd1;
				if (write_burst_length == 8'd1)
					write_state <= STATE_ARBITRATE;
			end
		end
		else if (write_state == STATE_ISSUE_ADDRESS)
		begin
			// Wait for the slave to accept the address and length
			if (axi_awready_s0)
				write_state <= STATE_ACTIVE_BURST;
		end
		else if (axi_awvalid_s0)
		begin
			// Start a new write transaction
			write_master_select <=  axi_awaddr_s0[31:28] != 0;
			write_burst_address <= axi_awaddr_s0;
			write_burst_length <= axi_awlen_s0;
			write_state <= STATE_ISSUE_ADDRESS;
		end
	end
	
	always @*
	begin
		if (write_master_select == 0)
		begin
			// Master Interface 0 is selected
			axi_wvalid_m0 = axi_wvalid_s0 && write_state == STATE_ACTIVE_BURST;
			axi_wvalid_m1 = 0;
			axi_awready_s0 = axi_awready_m0 && write_state == STATE_ISSUE_ADDRESS;
			axi_wready_s0 = axi_wready_m0 && write_state == STATE_ACTIVE_BURST;
			axi_bvalid_s0 = axi_bvalid_m0;
		end
		else
		begin
			// Master interface 1 is selected
			axi_wvalid_m0 = 0;
			axi_wvalid_m1 = axi_wvalid_s0 && write_state == STATE_ACTIVE_BURST;
			axi_awready_s0 = axi_awready_m1 && write_state == STATE_ISSUE_ADDRESS;
			axi_wready_s0 = axi_wready_m1 && write_state == STATE_ACTIVE_BURST;
			axi_bvalid_s0 = axi_bvalid_m1;
		end
	end
	
	//
	// Read handling.  Slave interface 1 has priority.
	//
	reg read_selected_slave;  // Which slave interface we are accepting request from
	reg read_selected_master; // Which master interface we are routing to
	reg[7:0] read_burst_length;
	reg[31:0] read_burst_address;
	reg[1:0] read_state;
	wire axi_arready_m = read_selected_master ? axi_arready_m1 : axi_arready_m0;
	wire axi_rready_m = read_selected_master ? axi_rready_m1 : axi_rready_m0;
	wire axi_rvalid_m = read_selected_master ? axi_rvalid_m1 : axi_rvalid_m0;
	
	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			read_burst_address <= 32'h0;
			read_burst_length <= 8'h0;
			read_selected_master <= 1'h0;
			read_selected_slave <= 1'h0;
			read_state <= 2'h0;
			// End of automatics
		end
		else if (read_state == STATE_ACTIVE_BURST)
		begin
			// Burst is active.  Check to see when it is finished.
			if (axi_rready_m && axi_rvalid_m)
			begin
				read_burst_length <= read_burst_length - 8'd1;
				if (read_burst_length == 8'd1)
					read_state <= STATE_ARBITRATE;
			end
		end
		else if (read_state == STATE_ISSUE_ADDRESS)
		begin
			// Wait for the slave to accept the address and length
			if (axi_arready_m)
				read_state <= STATE_ACTIVE_BURST;
		end
		else if (axi_arvalid_s1)
		begin
			// Start a read burst from slave 1
			read_state <= STATE_ISSUE_ADDRESS;
			read_burst_address <= axi_araddr_s1;
			read_burst_length <= axi_arlen_s1;
			read_selected_slave <= 2'd1;
			read_selected_master <= axi_araddr_s1[31:28] != 0;
		end
		else if (axi_arvalid_s0)
		begin
			// Start a read burst from slave 0
			read_state <= STATE_ISSUE_ADDRESS;
			read_burst_address <= axi_araddr_s0;
			read_burst_length <= axi_arlen_s0;
			read_selected_slave <= 2'd0;
			read_selected_master <= axi_araddr_s0[31:28] != 0;
		end
	end

	always @*
	begin
		if (read_state == STATE_ARBITRATE)
		begin
			axi_rvalid_s0 = 0;
			axi_rvalid_s1 = 0;
			axi_rready_m0 = 0;
			axi_rready_m1 = 0;
			axi_arready_s0 = 0;
			axi_arready_s1 = 0;
		end
		else if (read_selected_slave == 0)
		begin
			axi_rvalid_s0 = axi_rvalid_m;
			axi_rvalid_s1 = 0;
			axi_rready_m0 = axi_rready_s0 && read_selected_master == 0; 
			axi_rready_m1 = axi_rready_s0 && read_selected_master == 1;
			axi_arready_s0 = axi_arready_m && read_state == STATE_ISSUE_ADDRESS;
			axi_arready_s1 = 0;
		end
		else 
		begin
			axi_rvalid_s0 = 0;
			axi_rvalid_s1 = axi_rvalid_m;
			axi_rready_m0 = axi_rready_s1 && read_selected_master == 0; 
			axi_rready_m1 = axi_rready_s1 && read_selected_master == 1;
			axi_arready_s0 = 0;
			axi_arready_s1 = axi_arready_m && read_state == STATE_ISSUE_ADDRESS;
		end
	end

	assign axi_arvalid_m0 = read_state == STATE_ISSUE_ADDRESS && read_selected_master == 0;
	assign axi_arvalid_m1 = read_state == STATE_ISSUE_ADDRESS && read_selected_master == 1;
	assign axi_araddr_m0 = read_burst_address;
	assign axi_araddr_m1 = read_burst_address - M1_BASE_ADDRESS;
	assign axi_rdata_s0 = read_selected_master ? axi_rdata_m1 : axi_rdata_m0;
	assign axi_rdata_s1 = axi_rdata_s0;

	// Note that we end up reusing read_burst_length to track how many beats are left
	// later.  At this point, the value of ARLEN should be ignored by slave
	// we are driving, so it won't break anything.
	assign axi_arlen_m0 = read_burst_length;
	assign axi_arlen_m1 = read_burst_length;
endmodule
