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
	input [31:0]        io_address,
	input               io_read_en,	
	input [31:0]        io_write_data,
	input               io_write_en,
	output logic[31:0]  io_read_data,
	
	// UART interface
	output				uart_tx,
	input				uart_rx);

	localparam STATUS_REG = BASE_ADDRESS;
	localparam RX_REG = BASE_ADDRESS + 4;
	localparam TX_REG = BASE_ADDRESS + 8;
	localparam FIFO_LENGTH = 8;

	/*AUTOLOGIC*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	logic		rx_char_valid;		// From uart_receive of uart_receive.v
	logic		tx_ready;		// From uart_transmit of uart_transmit.v
	// End of automatics
	logic[7:0] rx_fifo_char;
	logic rx_fifo_empty;
	logic rx_fifo_read;
	logic rx_fifo_full;
	logic rx_fifo_overrun;
	logic rx_fifo_overrun_dq;
	logic rx_fifo_frame_error;

	logic[7:0] rx_char;
	logic rx_frame_error;
	logic[7:0] tx_char;
	logic tx_enable;

	always_comb
	begin
		case (io_address)
			STATUS_REG:
			begin 
				io_read_data[31:4] = 0;
				io_read_data[3:0] = { rx_fifo_frame_error, rx_fifo_overrun, !rx_fifo_empty, tx_ready };
			end
			default:
			begin
				io_read_data[31:8] = 0;
				io_read_data[7:0] = rx_fifo_char;
			end
		endcase
	end
	
	assign tx_enable = io_write_en && io_address == TX_REG;

	uart_transmit #(.BAUD_DIVIDE(BAUD_DIVIDE)) uart_transmit(
		.tx_char(io_write_data[7:0]),
		/*AUTOINST*/
								 // Outputs
								 .tx_ready		(tx_ready),
								 .uart_tx		(uart_tx),
								 // Inputs
								 .clk			(clk),
								 .reset			(reset),
								 .tx_enable		(tx_enable));

	uart_receive #(.BAUD_DIVIDE(BAUD_DIVIDE)) uart_receive(/*AUTOINST*/
							       // Outputs
							       .rx_char		(rx_char[7:0]),
							       .rx_char_valid	(rx_char_valid),
							       .rx_frame_error	(rx_frame_error),
							       // Inputs
							       .clk		(clk),
							       .reset		(reset),
							       .uart_rx		(uart_rx));
						     
	// XXX detect and flag uart_rx overflow
	assign rx_fifo_read = io_address == RX_REG && io_read_en;

	/// Logic for Overrun Error (OE) bit
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			rx_fifo_overrun <= 0;
		end
		else
		begin
			if (rx_fifo_read)
			begin
				rx_fifo_overrun <= 0;
			end
			if (rx_char_valid && rx_fifo_full)
			begin
				$write("[%d]overflow: %c\n", $time, rx_char);
				rx_fifo_overrun <= 1;
			end
		end
	end

	always_comb
	begin
		if (rx_char_valid && rx_fifo_full)
			rx_fifo_overrun_dq = 1;
		else
			rx_fifo_overrun_dq = 0;
	end

	/// Up to ALMOST_FULL_THRESHOLD characters can be filled. FIFO is
	/// automatically dequeued and OE bit is asserted when a character is queued
	/// after this point. The OE bit is deasserted when rx_fifo_read or the
	/// number of stored characters is lower than the threshold.
	sync_fifo #(.WIDTH(9), .SIZE(FIFO_LENGTH), 
		.ALMOST_FULL_THRESHOLD(FIFO_LENGTH - 1)) 
		rx_fifo(
		.clk(clk),
		.reset(reset),
		.almost_empty(),
		.almost_full(rx_fifo_full),
		.full(),
		.empty(rx_fifo_empty),
		.value_o({rx_fifo_frame_error, rx_fifo_char}),
		.enqueue_en(rx_char_valid),
		.flush_en(1'b0),
		.value_i({rx_frame_error, rx_char}),
		.dequeue_en(rx_fifo_read || rx_fifo_overrun_dq));
endmodule

// Local Variables:
// verilog-library-flags:("-y ../../core" "-y ../../testbench")
// verilog-typedef-regexp:"_t$"
// verilog-auto-reset-widths:unbased
// End:
