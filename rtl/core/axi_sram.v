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

//
// SRAM with an AXI interface
// A place holder for what would normally be external memory.
//
module axi_sram
	#(parameter MEM_SIZE = 'h40000, // Number of 32-bit words
	parameter LOAD_MEM_INIT_FILE = 0)	

	(input						clk,
	input [31:0]				axi_awaddr, 
	input [7:0]					axi_awlen,
	input 						axi_awvalid,
	output 						axi_awready,
	input [31:0]				axi_wdata,  
	input						axi_wlast,
	input 						axi_wvalid,
	output reg					axi_wready = 0,
	output reg					axi_bvalid = 0, 
	input						axi_bready,
	input [31:0]				axi_araddr,
	input [7:0]					axi_arlen,
	input 						axi_arvalid,
	output reg					axi_arready = 0,
	input 						axi_rready,
	output reg					axi_rvalid = 0,         
	output reg[31:0]			axi_rdata = 0,
	input[31:0]					display_address,
	output reg[31:0]			display_data = 0);

	localparam STATE_IDLE = 0;
	localparam STATE_READ_BURST = 1;
	localparam STATE_WRITE_BURST = 2;
	localparam STATE_WRITE_ACK = 3;

	reg[31:0] memory[0:MEM_SIZE - 1];
	reg[31:0] burst_address = 0;
	reg[31:0] burst_address_nxt = 0;
	reg[7:0] burst_count = 0;
	reg[7:0] burst_count_nxt = 0;
	integer state = STATE_IDLE;
	integer state_nxt = STATE_IDLE;
	reg do_read = 0;
	reg do_write = 0;
	integer i;

	// synthesis translate_off
	initial
	begin
		for (i = 0; i < MEM_SIZE; i = i + 1)
			memory[i] = 0;

		if (LOAD_MEM_INIT_FILE)
			$readmemh("memory.hex", memory);
	end
	// synthesis translate_on

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
					if (burst_count == 0)
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
					if (burst_count == 0)
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

	always @(posedge clk)
	begin
		if (burst_address > MEM_SIZE)
		begin
			// Note that this isn't necessarily indicative of a hardware bug,
			// but could just be a bad memory address produced by software
			$display("L2 cache accessed invalid address %x", burst_address);
			$finish;
		end

		burst_address <= #1 burst_address_nxt;
		burst_count <= #1 burst_count_nxt;

		// First port
		if (do_read)
			axi_rdata <= #1 memory[burst_address_nxt];
		else if (do_write)
			memory[burst_address] <= #1 axi_wdata;
			
		// Second port
		display_data <= #1 memory[display_address];

		state <= #1 state_nxt;
	end

endmodule
