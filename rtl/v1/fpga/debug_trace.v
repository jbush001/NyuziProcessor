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
// Quick and dirty event dumper
//

module debug_trace
	#(parameter CAPTURE_WIDTH_BITS = 32,
	parameter CAPTURE_SIZE = 64,
	parameter BAUD_DIVIDE = 1)

	(input                       clk,
	input						reset,
	input[CAPTURE_WIDTH_BITS - 1:0] capture_data,
	input                        capture_enable,
	input                        trigger,
	output                       uart_tx);

	localparam CAPTURE_INDEX_WIDTH = $clog2(CAPTURE_SIZE);
	localparam CAPTURE_WIDTH_BYTES = (CAPTURE_WIDTH_BITS + 7) / 8;

	localparam STATE_CAPTURE = 0;
	localparam STATE_DUMP = 1;
	localparam STATE_STOPPED = 2;

	reg[1:0] state = STATE_CAPTURE;
	reg wrapped = 0;
	reg[CAPTURE_INDEX_WIDTH - 1:0] capture_entry;
	reg[CAPTURE_INDEX_WIDTH - 1:0] dump_entry;
	reg[$clog2(CAPTURE_WIDTH_BYTES) - 1:0] dump_byte;
	reg[$clog2(CAPTURE_WIDTH_BYTES) - 1:0] dump_byte_latched;
	reg tx_enable = 0;
	wire[7:0] tx_char;
	wire[CAPTURE_WIDTH_BITS - 1:0] dump_value;


	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire		tx_ready;		// From uart_transmit of uart_transmit.v
	// End of automatics

	sram_1r1w #(.DATA_WIDTH(CAPTURE_WIDTH_BITS), .SIZE(CAPTURE_SIZE)) capture_mem(
		.clk(clk),
		.rd_enable(1'b1),
		.rd_addr(dump_entry),
		.rd_data(dump_value),
		.wr_enable(state == STATE_CAPTURE && capture_enable),
		.wr_addr(capture_entry),
		.wr_data(capture_data));

	uart_transmit #(.BAUD_DIVIDE(BAUD_DIVIDE)) uart_transmit(/*AUTOINST*/
								 // Outputs
								 .tx_ready		(tx_ready),
								 .uart_tx		(uart_tx),
								 // Inputs
								 .clk			(clk),
								 .reset			(reset),
								 .tx_enable		(tx_enable),
								 .tx_char		(tx_char[7:0]));


	assign tx_char = dump_value >> (dump_byte_latched * 8);

	always_ff @(posedge clk, posedge reset)
	begin : update

		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			capture_entry <= {CAPTURE_INDEX_WIDTH{1'b0}};
			dump_byte <= {(1+($clog2(CAPTURE_WIDTH_BYTES)-1)){1'b0}};
			dump_byte_latched <= {(1+($clog2(CAPTURE_WIDTH_BYTES)-1)){1'b0}};
			dump_entry <= {CAPTURE_INDEX_WIDTH{1'b0}};
			state <= 2'h0;
			tx_enable <= 1'h0;
			wrapped <= 1'h0;
			// End of automatics
		end
		else
		begin
			case (state)
				STATE_CAPTURE:
				begin
					// Capturing
					if (capture_enable)
					begin
						capture_entry <= capture_entry + 1;
						if (capture_entry == CAPTURE_SIZE- 1)
							wrapped <= 1;
					end
			
					if (trigger)
					begin
						state <= STATE_DUMP;
						if (wrapped)
							dump_entry <= capture_entry + 1;
						else
							dump_entry <= 0;
					end
				end

				STATE_DUMP:
				begin
					// Dumping
					if (tx_ready)
					begin
						tx_enable <= 1;	// Note: delayed by one cycle (as is capture ram)

						if (dump_byte == CAPTURE_WIDTH_BYTES - 1)
						begin
							dump_byte <= 0;
							dump_entry <= dump_entry + 1;
							if (dump_entry == capture_entry)
								state <= STATE_STOPPED;
						end
						else
							dump_byte <= dump_byte + 1;
							
						dump_byte_latched <= dump_byte;
					end
				end
			
				STATE_STOPPED:
					tx_enable <= 0;
			endcase
		end
	end
endmodule
