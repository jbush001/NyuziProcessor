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
	
	// IO bus interface
	input [31:0]		io_address,
	input				io_read_en,	
	input [31:0]		io_write_data,
	input				io_write_en,
	output reg[31:0] 	io_read_data,
	
	// UART interface
	output				uart_tx,
	input				uart_rx);

	localparam STATUS_REG = BASE_ADDRESS;
	localparam RX_REG = BASE_ADDRESS + 4;
	localparam TX_REG = BASE_ADDRESS + 8;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	logic		rx_char_valid;		// From uart_receive of uart_receive.v
	wire		tx_ready;		    // From uart_transmit of uart_transmit.v
	// End of automatics
	wire rx_fifo_empty;
    wire[11:0] rx_entry;            assign rx_entry = { rx_flags, rx_char };
	wire[7:0] rx_char;
	wire rx_fifo_dequeue;
    wire[3:0] rx_flags;
    wire rx_break_intr;				assign rx_flags[3] = rx_break_intr;			
    wire rx_frame_error;			assign rx_flags[2] = rx_frame_error;		
    wire rx_parity_error;			assign rx_flags[1] = rx_parity_error;		
    wire rx_overrun_error;			assign rx_flags[0] = rx_overrun_error;		
	wire[7:0] tx_char;
    wire[11:0] rx_fifo_entry;
	wire[7:0] rx_fifo_char;         assign rx_fifo_char = rx_fifo_entry[7:0];
    wire[3:0] rx_fifo_flags;		assign rx_fifo_flags = rx_fifo_entry[11:8];
    wire rx_fifo_break_intr;		assign rx_fifo_flags[3] = rx_fifo_break_intr;
    wire rx_fifo_frame_error;		assign rx_fifo_flags[2] = rx_fifo_frame_error;
    wire rx_fifo_parity_error;		assign rx_fifo_flags[1] = rx_fifo_parity_error;
    wire rx_fifo_overrun_error;		assign rx_fifo_flags[0] = rx_fifo_overrun_error;
	wire tx_enable;

	assign rx_break_intr = 0;
	assign rx_frame_error = 0;
	assign rx_parity_error = 0;
	assign rx_overrun_error = rx_fifo.full;

	always_comb
	begin
		case (io_address)
			STATUS_REG: io_read_data = { !rx_fifo_empty, tx_ready, rx_fifo_flags };
            RX_REG:		io_read_data = rx_fifo_char;
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

    // TODO: Implement logics for FE, PE (not sure what BE is) 
	uart_receive #(.BAUD_DIVIDE(BAUD_DIVIDE)) uart_receive(/*AUTOINST*/
							       // Outputs
							       .rx_char		    (rx_char[7:0]),
							       .rx_char_valid	(rx_char_valid),
							       // Inputs
							       .clk		        (clk),
							       .reset		    (reset),
							       .uart_rx		    (uart_rx));
						     
	// XXX detect and flag uart_rx overflow
	assign rx_fifo_dequeue = io_address == RX_REG && io_read_en;

	sync_fifo #(.WIDTH(12), .SIZE(8)) rx_fifo(
		.clk(clk),
		.reset(reset),
		.almost_empty(),
		.almost_full(),
		.full(),
		.empty(rx_fifo_empty),
		.value_o(rx_fifo_entry),
		.enqueue_en(rx_char_valid),
		.flush_en(1'b0),
		.value_i(rx_entry),
		.dequeue_en(rx_fifo_dequeue));
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../testbench")
// End:
