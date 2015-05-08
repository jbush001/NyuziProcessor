// 
// Copyright 2015 Jeff Bush
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

module spi_controller
	(input				clk,
	input				reset,
	
	// IO bus interface
	input [31:0]		io_address,
	input				io_read_en,	
	input [31:0]		io_write_data,
	input				io_write_en,
	output reg[31:0] 	io_read_data,

	// SPI interface
	output logic        spi_clk,
	output logic        spi_cs_n,
	input               spi_miso,
	output logic        spi_mosi);	
	
	logic transfer_active;
	logic[2:0] transfer_count;
	logic[7:0] miso_byte;	// Master in slave out
	logic[7:0] mosi_byte;	// Master out slave in
	logic[7:0] divider_countdown;
	logic[7:0] divider_rate;
	
	always_comb
	begin
		if (io_address == 'h48)
			io_read_data = miso_byte;
		else if (io_address == 'h4c)
			io_read_data = !transfer_active;
		else
			io_read_data = 'h55555555;	// debug
	end
	
	always_ff @(posedge reset, posedge clk)
	begin
		if (reset)
		begin
			transfer_active <= 0;
			spi_clk <= 0;
			spi_cs_n <= 1; 
			divider_rate <= 1;
			spi_mosi <= 1;
		end
		else
		begin
			// Control register
			if (io_write_en)
			begin
				if (io_address == 'h50)
					spi_cs_n <= io_write_data[0];
				else if (io_address == 'h54)
					divider_rate <= io_write_data;
			end

			if (transfer_active)
			begin
				if (divider_countdown == 0)
				begin
					divider_countdown <= divider_rate;
					spi_clk <= !spi_clk;
					if (spi_clk)
					begin
						// Falling edge
						if (transfer_count == 0)
							transfer_active <= 0;
						else
						begin
							transfer_count <= transfer_count - 1;
							
							// Shift out a bit
							{ spi_mosi, mosi_byte } <= { mosi_byte, 1'd0 };
						end
					end
					else
					begin
						// Rising edge
						miso_byte <= { miso_byte[6:0], spi_miso };
					end
				end
				else
					divider_countdown <= divider_countdown - 1;
			end
			else if (io_write_en && io_address == 'h44)
			begin
				assert(spi_clk == 0);

				// Start new transfer
				transfer_active <= 1;
				transfer_count <= 7;
				divider_countdown <= divider_rate;
				
				// Set up first bit
				{ spi_mosi, mosi_byte } <= { io_write_data[7:0], 1'd0 };
			end
		end
	end
endmodule
