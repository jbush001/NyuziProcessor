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
// Serial port interface. 
// BAUD_DIVIDE should be clk rate / (target baud rate * 8) 
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
	output reg[31:0] 	io_read_data,
	output				uart_tx,
	input				uart_rx);

	localparam TX_STATUS_REG = BASE_ADDRESS;
	localparam RX_REG = BASE_ADDRESS + 4;
	localparam TX_REG = BASE_ADDRESS + 8;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	logic		rx_char_valid;		// From uart_receive of uart_receive.v
	wire		tx_ready;		// From uart_transmit of uart_transmit.v
	// End of automatics
	wire rx_fifo_empty;
	wire[7:0] rx_char;
	wire rx_fifo_dequeue;
	wire[7:0] tx_char;
	wire[7:0] rx_fifo_char;
	wire tx_enable;

	always_comb
	begin
		case (io_address)
			TX_STATUS_REG: io_read_data = { !rx_fifo_empty, tx_ready };
			default: io_read_data = rx_fifo_char;
		endcase
	end
	
	assign tx_enable = io_write_en && io_address == TX_REG;

	uart_transmit #(.BAUD_DIVIDE(BAUD_DIVIDE * 8)) uart_transmit(
		.tx_char(io_write_data[7:0]),
							/*AUTOINST*/
								     // Outputs
								     .tx_ready		(tx_ready),
								     .uart_tx		(uart_tx),
								     // Inputs
								     .clk		(clk),
								     .reset		(reset),
								     .tx_enable		(tx_enable));

	uart_receive #(.BAUD_DIVIDE(BAUD_DIVIDE)) uart_receive(/*AUTOINST*/
							       // Outputs
							       .rx_char		(rx_char[7:0]),
							       .rx_char_valid	(rx_char_valid),
							       // Inputs
							       .clk		(clk),
							       .reset		(reset),
							       .uart_rx		(uart_rx));
						     
	// XXX detect and flag uart_rx overflow

	assign rx_fifo_dequeue = io_address == RX_REG && io_read_en;	
	sync_fifo #(.WIDTH(8), .SIZE(8)) rx_fifo(
		.clk(clk),
		.reset(reset),
		.almost_empty(),
		.almost_full(),
		.full(),
		.empty(rx_fifo_empty),
		.value_o(rx_fifo_char),
		.enqueue_en(rx_char_valid),
		.flush_en(1'b0),
		.value_i(rx_char),
		.dequeue_en(rx_fifo_dequeue));
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../testbench")
// End:
