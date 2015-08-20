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
// Quick and dirty event dumper
// BAUD_DIVIDE should be: clk rate / target baud rate 
// Each cycle that capture_enable is asserted, capture_data is
// stored into a circular buffer.  When trigger is asserted (it only
// needs to be asserted for one cycle), this will transmit the contents
// of the circular buffer.  Each entry will be padded to a multiple of
// bytes and sent a byte at a time, starting at the least significand bit
// of capture_data.
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
	reg[CAPTURE_INDEX_WIDTH - 1:0] dump_entry_nxt;
	reg[$clog2(CAPTURE_WIDTH_BYTES) - 1:0] dump_byte_nxt;
	reg tx_enable = 0;
	wire[7:0] tx_char;
	wire[CAPTURE_WIDTH_BITS - 1:0] dump_value;


	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire		tx_ready;		// From uart_transmit of uart_transmit.v
	// End of automatics

	sram_1r1w #(.DATA_WIDTH(CAPTURE_WIDTH_BITS), .SIZE(CAPTURE_SIZE)) capture_mem(
		.clk(clk),
		.read_en(1'b1),
		.read_addr(dump_entry_nxt),
		.read_data(dump_value),
		.write_en(state == STATE_CAPTURE && capture_enable),
		.write_addr(capture_entry),
		.write_data(capture_data));

	uart_transmit #(.BAUD_DIVIDE(BAUD_DIVIDE)) uart_transmit(/*AUTOINST*/
								 // Outputs
								 .tx_ready		(tx_ready),
								 .uart_tx		(uart_tx),
								 // Inputs
								 .clk			(clk),
								 .reset			(reset),
								 .tx_enable		(tx_enable),
								 .tx_char		(tx_char[7:0]));


	assign tx_char = dump_value[(dump_byte * 8)+:8];

	always_comb
	begin
		dump_entry_nxt = dump_entry;
		dump_byte_nxt = dump_byte;
	
		case (state)
			STATE_CAPTURE:
			begin
				if (trigger)
				begin
					if (wrapped)
						dump_entry_nxt = capture_entry + 1;
					else
						dump_entry_nxt = 0;
						
					dump_byte_nxt = 0;
				end
			end
			
			STATE_DUMP:
			begin
				if (tx_ready)
				begin
					if (dump_byte == CAPTURE_WIDTH_BYTES - 1)
						dump_entry_nxt = dump_entry + 1;
						
					if (tx_ready && tx_enable)
					begin
						if (dump_byte == CAPTURE_WIDTH_BYTES - 1)
							dump_byte_nxt = 0;
						else
							dump_byte_nxt = dump_byte + 1;
					end
				end
			end
		endcase
	end

	always_ff @(posedge clk, posedge reset)
	begin : update

		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			capture_entry <= {CAPTURE_INDEX_WIDTH{1'b0}};
			dump_byte <= {(1+($clog2(CAPTURE_WIDTH_BYTES)-1)){1'b0}};
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
						state <= STATE_DUMP;
				end

				STATE_DUMP:
				begin
					// Dumping
					if (tx_ready)
					begin
						tx_enable <= 1;	// Note: delayed by one cycle (as is capture ram)

						if (dump_entry == capture_entry)
							state <= STATE_STOPPED;
					end
				end
			
				STATE_STOPPED:
					tx_enable <= 0;
			endcase

			dump_entry <= dump_entry_nxt;
			dump_byte <= dump_byte_nxt;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

