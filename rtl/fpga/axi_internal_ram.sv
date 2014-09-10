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
// SRAM with an AXI interface
//
module axi_internal_ram
	#(parameter MEM_SIZE = 'h40000) // Number of 32-bit words

	(input						clk,
	input						reset,
	
	// AXI interface
	axi_interface.slave         axi_bus,
	
	// Interface to JTAG loader.  Note that it is perfectly valid to access
	// these when the part is in reset.  The reset signal only applies to the
	// AXI state machine.
	input						loader_we,
	input[31:0]					loader_addr,
	input[31:0]					loader_data);

	typedef enum {
		STATE_IDLE,
		STATE_READ_BURST,
		STATE_WRITE_BURST,
		STATE_WRITE_ACK
	} axi_state_t;

	logic[31:0] burst_address;
	logic[31:0] burst_address_nxt;
	logic[7:0] burst_count;
	logic[7:0] burst_count_nxt;
	axi_state_t state;
	axi_state_t state_nxt;
	logic do_read;
	logic do_write;
	logic[31:0] wr_addr;
	logic[31:0] wr_data;

	localparam SRAM_ADDR_WIDTH = $clog2(MEM_SIZE); 
	
	always_comb
	begin
		if (loader_we)
		begin
			wr_addr = loader_addr[31:2];
			wr_data = loader_data;
		end
		else // do write
		begin
			wr_addr = burst_address;
			wr_data = axi_bus.wdata;
		end
	end

	sram_1r1w #(.SIZE(MEM_SIZE), .DATA_WIDTH(32)) memory(
		.clk(clk),
		.read_en(do_read),
		.read_addr(burst_address_nxt[SRAM_ADDR_WIDTH - 1:0]),
		.read_data(axi_bus.rdata),
		.write_en(loader_we || do_write),
		.write_addr(wr_addr[SRAM_ADDR_WIDTH - 1:0]),
		.write_data(wr_data));

	assign axi_bus.awready = axi_bus.arready;

	// Drive external bus signals
	always_comb
	begin
		axi_bus.rvalid = 0;
		axi_bus.wready = 0;
		axi_bus.bvalid = 0;
		axi_bus.arready = 0;
		case (state)
			STATE_IDLE:        axi_bus.arready = 1;	// and awready
			STATE_READ_BURST:  axi_bus.rvalid = 1;
			STATE_WRITE_BURST: axi_bus.wready = 1;
			STATE_WRITE_ACK:   axi_bus.bvalid = 1;
		endcase	
	end

	// Next state logic
	always_comb
	begin
		do_read = 0;
		do_write = 0;
		burst_address_nxt = burst_address;
		burst_count_nxt = burst_count;
		state_nxt = state;
		
		unique case (state)
			STATE_IDLE:
			begin
				// I've cheated here.  It's legal per the spec for arready/awready to go low
				// but not if arvalid/awvalid are asserted (respectively).  I know
				// that the client never does that, so I don't bother latching
				// addresses separately.
				if (axi_bus.awvalid)
				begin
					burst_address_nxt = axi_bus.awaddr[31:2];
					burst_count_nxt = axi_bus.awlen;
					state_nxt = STATE_WRITE_BURST;
				end
				else if (axi_bus.arvalid)
				begin
					do_read = 1;
					burst_address_nxt = axi_bus.araddr[31:2];
					burst_count_nxt = axi_bus.arlen;
					state_nxt = STATE_READ_BURST;
				end
			end
			
			STATE_READ_BURST:
			begin
				if (axi_bus.rready)
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
				if (axi_bus.wvalid)
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
				if (axi_bus.bready)
					state_nxt = STATE_IDLE;
			end

			default:
				state_nxt = STATE_IDLE;
		endcase	
	end

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			state <= STATE_IDLE;
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			burst_address <= 32'h0;
			burst_count <= 8'h0;
			// End of automatics
		end
		else
		begin
`ifdef SIMULATION
			if (burst_address > MEM_SIZE)
			begin
				// Note that this isn't necessarily indicative of a hardware bug,
				// but could just be a bad memory address produced by software
				$display("L2 cache accessed invalid address %x", burst_address);
				$finish;
			end
`endif

			burst_address <= burst_address_nxt;
			burst_count <= burst_count_nxt;
			state <= state_nxt;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

