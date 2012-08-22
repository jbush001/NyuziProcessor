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
// Simulates system memory
//

module sim_memory
	#(parameter MEM_SIZE = 'h40000)	// Number of 32-bit words

	(input						clk,
	input [31:0]				axi_awaddr, 
	input [7:0]					axi_awlen,
	input 						axi_awvalid,
	output 						axi_awready,
	input [31:0]				axi_wdata,  
	input						axi_wlast,
	input 						axi_wvalid,
	output 						axi_wready,
	output 						axi_bvalid, 
	input						axi_bready,
	input [31:0]				axi_araddr,
	input [7:0]					axi_arlen,
	input 						axi_arvalid,
	output 						axi_arready,
	input 						axi_rready,
	output 						axi_rvalid,         
	output [31:0]				axi_rdata);

	localparam STATE_IDLE = 0;
	localparam STATE_READ_BURST = 1;
	localparam STATE_WRITE_BURST = 2;
	localparam STATE_WRITE_ACK = 3;

	reg[31:0] memory[0:MEM_SIZE - 1];
	reg[31:0] burst_address = 0;
	reg[7:0] burst_count = 0;
	integer state_ff = STATE_IDLE;
	integer i;

	initial
	begin
		for (i = 0; i < MEM_SIZE; i = i + 1)
			memory[i] = 0;
	end

	always @(posedge clk)
	begin
		case (state_ff)
			STATE_IDLE:
			begin
				if (axi_awvalid)
				begin
					// Start a write transaction
					if (axi_awaddr[31:2] > MEM_SIZE)
					begin
						// Note that this isn't necessarily indicative of a hardware bug,
						// but could just be a bad memory address produced by software
						$display("L2 cache wrote invalid address %x", axi_awaddr);
						$finish;
					end

					burst_address <= #1 axi_awaddr[31:2];
					burst_count <= #1 axi_awlen;
					state_ff <= #1 STATE_WRITE_BURST;
				end
				else if (axi_arvalid)
				begin
					// Start a read transaction
					if (axi_araddr[31:2] > MEM_SIZE)
					begin
						// Note that this isn't necessarily indicative of a hardware bug,
						// but could just be a bad memory address produced by software
						$display("L2 cache read invalid address %x", axi_araddr);
						$finish;
					end
				
					burst_address <= #1 axi_araddr[31:2];
					burst_count <= #1 axi_arlen;
					state_ff <= #1 STATE_READ_BURST;
				end
			end
			
			STATE_READ_BURST:
			begin
				if (axi_rready)
				begin
					burst_address <= #1 burst_address + 1;
					burst_count <= #1 burst_count - 1;
					if (burst_count == 0)
						state_ff <= #1 STATE_IDLE;
				end
			end
			
			STATE_WRITE_BURST:
			begin
				if (axi_wvalid)
				begin
					memory[burst_address] <= #1 axi_wdata;
					burst_address <= #1 burst_address + 1;
					burst_count <= #1 burst_count - 1;
					if (burst_count == 0)
						state_ff <= #1 STATE_WRITE_ACK;
				end
			end
			
			STATE_WRITE_ACK:
			begin
				if (axi_bready)
					state_ff <= #1 STATE_IDLE;
			end
		endcase
	end

	assign axi_arready = state_ff == STATE_IDLE;
	assign axi_awready = axi_arready;
	assign axi_rvalid = state_ff == STATE_READ_BURST;
	assign axi_wready = state_ff == STATE_WRITE_BURST;
	assign axi_bvalid = state_ff == STATE_WRITE_ACK;
	assign axi_rdata = memory[burst_address];
endmodule
