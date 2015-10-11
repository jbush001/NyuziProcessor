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

module gpio_controller
	#(parameter BASE_ADDRESS = 0,
	parameter NUM_PINS = 8,
	parameter ENABLE_SYNCHRONIZER = 0)

	(input				  clk,
	input				  reset,
	                      
	// IO bus interface   
	input [31:0]		  io_address,
	input				  io_read_en,	
	input [31:0]		  io_write_data,
	input				  io_write_en,
	output logic[31:0] 	  io_read_data,

	// To/from SD card
	inout[NUM_PINS - 1:0] gpio_value);	

	localparam DIRECTION_REG = BASE_ADDRESS;
	localparam VALUE_REG = BASE_ADDRESS + 4;
	
	logic[NUM_PINS - 1:0] direction;
	logic[NUM_PINS - 1:0] output_value;

	genvar pin_idx;
	generate
		for (pin_idx = 0; pin_idx < NUM_PINS; pin_idx++)
		begin : pin_dir_gen
			assign gpio_value[pin_idx] = direction[pin_idx] 
				? output_value[pin_idx] : 1'bZ;
		end
	endgenerate

	generate
		if (ENABLE_SYNCHRONIZER)
		begin
			synchronizer #(.WIDTH(NUM_PINS)) input_synchronizer(
				.data_o(io_read_data),
				.data_i(gpio_value),
				.*);
		end
		else
		begin
			assign io_read_data = gpio_value;
		end
	endgenerate

	always_ff @(posedge reset, posedge clk)
	begin
		if (reset)
		begin
			direction <= 0;
			output_value <= 0;
		end
		else if (io_write_en)
		begin
			if (io_address == DIRECTION_REG)
				direction <= io_write_data[NUM_PINS - 1:0];
			else if (io_address == VALUE_REG)
				output_value <= io_write_data[NUM_PINS - 1:0];
		end
	end
endmodule

// Local Variables:
// verilog-library-flags:("-y ../../core" "-y ../../testbench")
// verilog-typedef-regexp:"_t$"
// verilog-auto-reset-widths:unbased
// End:
