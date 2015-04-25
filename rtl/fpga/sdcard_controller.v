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

//
// Control an SD card in SPI mode.
// This is a work in progress.  Initialization is unimplemented, many 
// parts of the protocol are probably incorrect.
//

module sdcard_controller
	(input				clk,
	input				reset,
	
	// IO bus interface
	input [31:0]		io_address,
	input				io_read_en,	
	input [31:0]		io_write_data,
	input				io_write_en,
	output reg[31:0] 	io_read_data,

	// to/from SD card
	output logic        sd_sclk,
	input               sd_do,	// Sampled on rising edge
	output logic        sd_cs_n,
	output logic        sd_di,	// Shifted out on falling edge	
	output logic        sd_wp_n);
	
	logic transfer_active;
	logic[2:0] transfer_count;
	logic[7:0] miso_byte;	// Master in slave out
	logic[7:0] mosi_byte;	// Master out slave in
	logic[7:0] divider_countdown;
	logic[7:0] divider_rate = 16;	// XXX hardcoded, need to expose via register
	
	assign sd_wp_n = 0;
	
	always_comb
	begin
		io_read_data = 'hffffffff;
		
		if (io_read_en)
		begin
			if (io_address == 'h48)
				io_read_data = miso_byte;
			else if (io_address == 'h4c)
				io_read_data = !transfer_active;
		end
	end
	
	always_ff @(posedge reset, posedge clk)
	begin
		if (reset)
		begin
			transfer_active <= 0;
			sd_sclk <= 1;
			sd_cs_n <= 1; 
		end
		else
		begin
			// Control register
			if (io_write_en && io_address == 'h50)
				sd_cs_n <= !io_write_data[0];
		
			if (transfer_active)
			begin
				if (divider_countdown == 0)
				begin
					divider_countdown <= divider_rate;
					sd_sclk <= !sd_sclk;
					if (sd_sclk)
					begin
						// Shift out on falling edge of sd clock
						{ sd_di, mosi_byte } <= { mosi_byte, 1'd0 };
					end
					else
					begin
						// Sample on rising edge of SD clock
						miso_byte <= { miso_byte[6:0], sd_do };
						transfer_count <= transfer_count - 1;
						if (transfer_count == 0)
						begin
							transfer_active <= 0;
						end
					end
				end
				else
					divider_countdown <= divider_countdown - 1;
			end
			else if (io_write_en && io_address == 'h44)
			begin
				// Start new transfer
				transfer_active <= 1;
				transfer_count <= 7;
				mosi_byte <= io_write_data[7:0];
				divider_countdown <= divider_rate;
				assert(sd_sclk == 1);
			end
		end
	end
endmodule
