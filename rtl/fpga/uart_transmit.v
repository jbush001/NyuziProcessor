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
// Serial transmit logic
// BAUD_DIVIDE should be: clk rate / target baud rate 
//

module uart_transmit
	#(parameter			BAUD_DIVIDE = 1)
	(input				clk,
	input				reset,
	input				tx_enable,
	output				tx_ready,
	input[7:0]			tx_char,
	output				uart_tx);

	localparam START_BIT = 1'b0;
	localparam STOP_BIT = 1'b1;

	logic[9:0] tx_shift;
	logic[3:0] shift_count;
	logic[31:0] baud_divider;

	wire transmit_active = shift_count != 0;
	assign uart_tx = transmit_active ? tx_shift[0] : 1'b1;
	assign tx_ready = !transmit_active;
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			baud_divider <= 32'h0;
			shift_count <= 4'h0;
			tx_shift <= 10'h0;
			// End of automatics
		end
		else
		begin
			if (transmit_active)
			begin
				if (baud_divider == 0)
				begin
					shift_count <= shift_count - 1;
					tx_shift <= { 1'b0, tx_shift[9:1] };
					baud_divider <= BAUD_DIVIDE;
				end
				else
					baud_divider <= baud_divider - 1;
			end
			else if (tx_enable)
			begin
				shift_count <= 4'd10;
				tx_shift <= { STOP_BIT, tx_char, START_BIT };
				baud_divider <= BAUD_DIVIDE;
			end
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
