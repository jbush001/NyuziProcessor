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
// Serial interface. 
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
	output				tx,
	input				rx);

	localparam TX_STATUS_REG = BASE_ADDRESS;
	localparam RX_REG = BASE_ADDRESS + 4;
	localparam TX_REG = BASE_ADDRESS + 8;

	/*AUTOWIRE*/	
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire		rx_char_valid;		// From uart_rx of uart_rx.v
	wire		tx_ready;		// From uart_tx of uart_tx.v
	// End of automatics
	wire rx_fifo_empty;
	wire[7:0] rx_char;
	wire rx_fifo_dequeue;
	wire[7:0] tx_char;
	wire[7:0] rx_fifo_char;
	wire tx_enable;

	always @*
	begin
		case (io_address)
			TX_STATUS_REG: io_read_data = { !rx_fifo_empty, tx_ready };
			default: io_read_data = rx_fifo_char;
		endcase
	end
	
	assign tx_enable = io_write_en && io_address == TX_REG;

	uart_tx #(.BAUD_DIVIDE(BAUD_DIVIDE * 8)) uart_tx(
		.tx_char(io_write_data[7:0]),
							/*AUTOINST*/
							 // Outputs
							 .tx_ready		(tx_ready),
							 .tx			(tx),
							 // Inputs
							 .clk			(clk),
							 .reset			(reset),
							 .tx_enable		(tx_enable));

	uart_rx #(.BAUD_DIVIDE(BAUD_DIVIDE)) uart_rx(/*AUTOINST*/
						     // Outputs
						     .rx_char		(rx_char[7:0]),
						     .rx_char_valid	(rx_char_valid),
						     // Inputs
						     .clk		(clk),
						     .reset		(reset),
						     .rx		(rx));
						     
	// XXX detect and flag rx overflow

	assign rx_fifo_dequeue = io_address == RX_REG && io_read_en;	
	sync_fifo #(.DATA_WIDTH(8), .NUM_ENTRIES(8)) rx_fifo(
		.clk(clk),
		.reset(reset),
		.almost_empty_o(),
		.almost_full_o(),
		.full_o(),
		.empty_o(rx_fifo_empty),
		.value_o(rx_fifo_char),
		.enqueue_i(rx_char_valid),
		.flush_i(1'b0),
		.value_i(rx_char),
		.dequeue_i(rx_fifo_dequeue));
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../testbench")
// End:
