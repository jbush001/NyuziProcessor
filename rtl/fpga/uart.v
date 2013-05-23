// 
// Copyright 2011-2013 Jeff Bush
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
// Serial interface.  Currently transmit only.
//

module uart
	#(parameter			BASE_ADDRESS = 0,
	parameter			BAUD_DIVIDE = 1)
	(input				clk,
	input				reset,
	input [31:0]		io_address,
	input				io_read_en,	
	input [31:0]		io_write_data,
	input				io_write_en,
	output [31:0] 		io_read_data,
	output				uart_tx);

	localparam TX_RDY_REG = BASE_ADDRESS;
	localparam TX_REG = BASE_ADDRESS + 4;

	localparam START_BIT = 1'b0;
	localparam STOP_BIT = 1'b1;

	reg[9:0] tx_shift;
	reg[3:0] shift_count;
	reg[31:0] baud_divider;

	wire transmit_active = shift_count != 0;
	assign uart_tx = transmit_active ? tx_shift[0] : 1'b1;
	assign io_read_data = !transmit_active;	// TX_RDY_REG
	
	always @(posedge clk, posedge reset)
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
			else if (io_write_en && io_address == TX_REG)
			begin
				shift_count <= 4'd10;
				tx_shift <= { STOP_BIT, io_write_data[7:0], START_BIT };
				baud_divider <= BAUD_DIVIDE;
			end
		end
	end
endmodule
