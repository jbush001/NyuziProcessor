// 
// Copyright 2013 Jeff Bush
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
	reg[CAPTURE_WIDTH_BITS - 1:0] capture_ram[0:CAPTURE_SIZE - 1];
	reg[CAPTURE_INDEX_WIDTH - 1:0] capture_entry;
	reg[CAPTURE_INDEX_WIDTH - 1:0] dump_entry;
	reg[$clog2(CAPTURE_WIDTH_BYTES) - 1:0] dump_byte;
	reg tx_enable = 0;
	reg[7:0] tx_char;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire		tx_ready;		// From uart_transmit of uart_transmit.v
	// End of automatics

	uart_transmit #(.BAUD_DIVIDE(BAUD_DIVIDE)) uart_transmit(/*AUTOINST*/
								 // Outputs
								 .tx_ready		(tx_ready),
								 .uart_tx		(uart_tx),
								 // Inputs
								 .clk			(clk),
								 .reset			(reset),
								 .tx_enable		(tx_enable),
								 .tx_char		(tx_char[7:0]));


	always @(posedge clk, posedge reset)
	begin : update
		integer i;

		if (reset)
		begin
			for (i = 0; i < CAPTURE_SIZE; i = i + 1)
				capture_ram[i] <= 0;

			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			capture_entry <= {CAPTURE_INDEX_WIDTH{1'b0}};
			dump_byte <= {(1+($clog2(CAPTURE_WIDTH_BYTES)-1)){1'b0}};
			dump_entry <= {CAPTURE_INDEX_WIDTH{1'b0}};
			state <= 2'h0;
			tx_char <= 8'h0;
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
						capture_ram[capture_entry] <= capture_data;
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
						if (dump_byte == CAPTURE_WIDTH_BYTES - 1)
						begin
							dump_byte <= 0;
							dump_entry <= dump_entry + 1;
							if (dump_entry == capture_entry)
								state <= STATE_STOPPED;
						end
						else
							dump_byte <= dump_byte + 1;

						tx_char <= capture_ram[dump_entry] >> (dump_byte * 8);
						tx_enable <= 1;
					end
				end
			
				STATE_STOPPED:
					tx_enable <= 0;
			endcase
		end
	end
endmodule
