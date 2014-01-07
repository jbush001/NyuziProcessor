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

`include "../core/defines.v"

//
// SRAM with an AXI interface
//
module axi_internal_ram
	#(parameter MEM_SIZE = 'h40000) // Number of 32-bit words

	(input						clk,
	input						reset,
	
	// AXI interface
	input [31:0]				axi_awaddr, 
	input [7:0]					axi_awlen,
	input 						axi_awvalid,
	output 						axi_awready,
	input [31:0]				axi_wdata,  
	input						axi_wlast,
	input 						axi_wvalid,
	output reg					axi_wready,
	output reg					axi_bvalid, 
	input						axi_bready,
	input [31:0]				axi_araddr,
	input [7:0]					axi_arlen,
	input 						axi_arvalid,
	output reg					axi_arready,
	input 						axi_rready,
	output reg					axi_rvalid,         
	output [31:0]				axi_rdata,
	
	// Interface to JTAG loader.  Note that it is perfectly valid to access
	// these when the part is in reset.  The reset signal only applies to the
	// AXI state machine.
	input						loader_we,
	input[31:0]					loader_addr,
	input[31:0]					loader_data);

	localparam STATE_IDLE = 0;
	localparam STATE_READ_BURST = 1;
	localparam STATE_WRITE_BURST = 2;
	localparam STATE_WRITE_ACK = 3;

	reg[31:0] burst_address;
	reg[31:0] burst_address_nxt;
	reg[7:0] burst_count;
	reg[7:0] burst_count_nxt;
	integer state = STATE_IDLE;
	integer state_nxt = STATE_IDLE;
	reg do_read = 0;
	reg do_write = 0;
	integer i;
	reg[31:0] wr_addr = 0;
	reg[31:0] wr_data = 0;

	localparam SRAM_ADDR_WIDTH = `CLOG2(MEM_SIZE); 
	
	always @*
	begin
		if (loader_we)
		begin
			wr_addr = loader_addr[31:2];
			wr_data = loader_data;
		end
		else // do write
		begin
			wr_addr = burst_address;
			wr_data = axi_wdata;
		end
	end

	sram_1r1w #(.SIZE(MEM_SIZE)) memory(
		.clk(clk),
		.rd_enable(do_read),
		.rd_addr(burst_address_nxt[SRAM_ADDR_WIDTH - 1:0]),
		.rd_data(axi_rdata),
		.wr_enable(loader_we || do_write),
		.wr_addr(wr_addr[SRAM_ADDR_WIDTH - 1:0]),
		.wr_data(wr_data));

	assign axi_awready = axi_arready;

	always @*
	begin
		do_read = 0;
		do_write = 0;
		burst_address_nxt = burst_address;
		burst_count_nxt = burst_count;
		state_nxt = state;
		
		case (state)
			STATE_IDLE:
			begin
				// I've cheated here.  It's legal per the spec for arready/awready to go low
				// but not if arvalid/awvalid are asserted (respectively).  I know
				// that the client never does that, so I don't bother latching
				// addresses separately.
				axi_rvalid = 0;
				axi_wready = 0;
				axi_bvalid = 0;
				axi_arready = 1;	// and awready

				if (axi_awvalid)
				begin
					burst_address_nxt = axi_awaddr[31:2];
					burst_count_nxt = axi_awlen;
					state_nxt = STATE_WRITE_BURST;
				end
				else if (axi_arvalid)
				begin
					do_read = 1;
					burst_address_nxt = axi_araddr[31:2];
					burst_count_nxt = axi_arlen;
					state_nxt = STATE_READ_BURST;
				end
			end
			
			STATE_READ_BURST:
			begin
				axi_rvalid = 1;
				axi_wready = 0;
				axi_bvalid = 0;
				axi_arready = 0;
				
				if (axi_rready)
				begin
					if (burst_count == 1)
						state_nxt = STATE_IDLE;
					else
					begin
						burst_address_nxt = burst_address + 1;
						burst_count_nxt = burst_count - 1;
						do_read = 1;
					end
				end
			end
			
			STATE_WRITE_BURST:
			begin
				axi_rvalid = 0;
				axi_wready = 1;
				axi_bvalid = 0;
				axi_arready = 0;
				
				if (axi_wvalid)
				begin
					do_write = 1;
					if (burst_count == 1)
						state_nxt = STATE_WRITE_ACK;
					else
					begin
						burst_address_nxt = burst_address + 1;
						burst_count_nxt = burst_count - 1;
					end
				end
			end
			
			STATE_WRITE_ACK:
			begin
				axi_rvalid = 0;
				axi_wready = 0;
				axi_bvalid = 1;
				axi_arready = 0;

				if (axi_bready)
					state_nxt = STATE_IDLE;
			end


			default:
			begin
				axi_rvalid = 0;
				axi_wready = 0;
				axi_bvalid = 0;
				axi_arready = 0;
				state_nxt = STATE_IDLE;
			end
		endcase	
	end

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			burst_address <= 32'h0;
			burst_count <= 8'h0;
			state <= 1'h0;
			// End of automatics
		end
		else
		begin
			// synthesis translate_off
			if (burst_address > MEM_SIZE)
			begin
				// Note that this isn't necessarily indicative of a hardware bug,
				// but could just be a bad memory address produced by software
				$display("L2 cache accessed invalid address %x", burst_address);
				$finish;
			end
			// synthesis translate_on

			burst_address <= burst_address_nxt;
			burst_count <= burst_count_nxt;
			state <= state_nxt;
		end
	end
endmodule
