// 
// Copyright 2012-2013 Jeff Bush
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

module uart_rx
	#(parameter BAUD_DIVIDE = 1)
	(input 				clk,
	input				reset,
	input				rx,
	output[7:0]			rx_char,
	output reg			rx_char_valid);

	localparam STATE_WAIT_START = 0;
	localparam STATE_READ_CHARACTER = 1;
	localparam STATE_STOP_BIT = 2;

	wire sample_enable = clock_divider == 0;
	reg[1:0] state_ff = STATE_WAIT_START;
	reg[1:0] state_nxt = STATE_WAIT_START;
	reg[3:0] sample_count_ff;
	reg[3:0] sample_count_nxt;
	reg[15:0] shift_register;	
	reg[3:0] bit_count_ff;
	reg[3:0] bit_count_nxt;
	reg rx_sync0;
	reg rx_sync1;
	reg do_shift;
	reg[10:0] clock_divider;

	assign rx_char = shift_register;

	// Synchronizer
	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			rx_sync0 <= 1;
			rx_sync1 <= 1;
		end
		else
		begin
			rx_sync0 <= rx;
			rx_sync1 <= rx_sync0;
		end
	end

	always @*
	begin
		bit_count_nxt = bit_count_ff;
		state_nxt = state_ff;
		sample_count_nxt = sample_count_ff;
		rx_char_valid = 0;
		do_shift = 0;
		
		case (state_ff)
			STATE_WAIT_START:
			begin
				if (!rx_sync1)
				begin
					state_nxt = STATE_READ_CHARACTER;
					sample_count_nxt = 12;	// Scan to middle of first bit
				end
			end

			STATE_READ_CHARACTER:
			begin
				if (sample_count_ff == 0)
				begin
					sample_count_nxt = 8;
					if (bit_count_ff == 8)
					begin
						state_nxt = STATE_STOP_BIT;
						rx_char_valid = 1;
						bit_count_nxt = 0;
					end
					else
					begin
						do_shift = 1;
						bit_count_nxt = bit_count_ff + 1;
					end
				end
				else if (sample_enable)
					sample_count_nxt = sample_count_ff - 1;
			end
			
			STATE_STOP_BIT:
			begin
				if (sample_count_ff == 0)
					state_nxt = STATE_WAIT_START;
				else if (sample_enable)
					sample_count_nxt = sample_count_ff - 1;
					
			end
		endcase
	end
	
	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			bit_count_ff <= 4'h0;
			clock_divider <= 11'h0;
			sample_count_ff <= 4'h0;
			shift_register <= 16'h0;
			state_ff <= 2'h0;
			// End of automatics
		end
		else
		begin
			state_ff <= state_nxt;
			sample_count_ff <= sample_count_nxt;
			bit_count_ff <= bit_count_nxt;
			if (do_shift)
				shift_register <= { rx_sync1, shift_register[7:1] };
				
			if (clock_divider == 0)
				clock_divider <= BAUD_DIVIDE;
			else
				clock_divider <= clock_divider - 1;
		end
	end
endmodule
