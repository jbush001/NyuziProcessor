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
// Serial receive logic
// BAUD_DIVIDE should be: clk rate / (target baud rate * 8) 
//

module uart_receive
	#(parameter BAUD_DIVIDE = 1)
	(input 				clk,
	input				reset,
	input				uart_rx,
	output[7:0]			rx_char,
	output logic		rx_char_valid);

	typedef enum {
		STATE_WAIT_START,
		STATE_READ_CHARACTER
	} receive_state_t;

	receive_state_t state_ff = STATE_WAIT_START;
	receive_state_t state_nxt = STATE_WAIT_START;
	logic[3:0] sample_count_ff;
	logic[3:0] sample_count_nxt;
	logic[7:0] shift_register;	
	logic[3:0] bit_count_ff;
	logic[3:0] bit_count_nxt;
	logic do_shift;
	logic[10:0] clock_divider;
	wire rx_sync;
	wire sample_enable = clock_divider == 0;

	assign rx_char = shift_register;

	synchronizer #(.RESET_STATE(1)) rx_synchronizer(
		.clk(clk),
		.reset(reset),
		.data_i(uart_rx),
		.data_o(rx_sync));

	always_comb
	begin
		bit_count_nxt = bit_count_ff;
		state_nxt = state_ff;
		sample_count_nxt = sample_count_ff;
		rx_char_valid = 0;
		do_shift = 0;
		
		unique case (state_ff)
			STATE_WAIT_START:
			begin
				if (!rx_sync)
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
						state_nxt = STATE_WAIT_START;
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
		endcase
	end
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			state_ff <= STATE_WAIT_START;
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			bit_count_ff <= 4'h0;
			clock_divider <= 11'h0;
			sample_count_ff <= 4'h0;
			shift_register <= 8'h0;
			// End of automatics
		end
		else
		begin
			state_ff <= state_nxt;
			sample_count_ff <= sample_count_nxt;
			bit_count_ff <= bit_count_nxt;
			if (do_shift)
				shift_register <= { rx_sync, shift_register[7:1] };
				
			if (clock_divider == 0)
				clock_divider <= BAUD_DIVIDE;
			else
				clock_divider <= clock_divider - 1;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

