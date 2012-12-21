// 
// Copyright 2011-2012 Jeff Bush
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
// This module contains the control registers, special purpose memory locations
// that are used for system level functions like obtaining the current strand
// ID.
//

module control_registers
	#(parameter			CORE_ID = 0)
	
	(input 				clk, 
	input				reset,
	output reg[3:0]		strand_enable,
	input[1:0]			ex_strand,
	input[4:0]			cr_index,
	input 				cr_read_en,
	input				cr_write_en,
	input[31:0]			cr_write_value,
	output reg[31:0]	cr_read_value);

	reg[31:0]		_test_cr7;

	initial
	begin
		// XXX for FPGA synthesis without global reset enabled.  May go away.
	 	strand_enable = 4'b0001;	// Enable strand 0
	end

	assert_false #("cr_read_en and cr_write_en asserted simultaneously") a0(
		.clk(clk), .test(cr_read_en && cr_write_en));

	always @*
	begin
		case (cr_index)
			0: cr_read_value = { CORE_ID, ex_strand }; // Strand ID
			7: cr_read_value = _test_cr7;
			30: cr_read_value = strand_enable;
			default: cr_read_value = 0;
		endcase
	end

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
		 	strand_enable <= 4'b0001;	// Enable strand 0

			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			_test_cr7 <= 32'h0;
			// End of automatics
		end
		else
		begin
			// Transfer to a control register
			if (cr_write_en)
			begin
				case (cr_index)
					7: _test_cr7 <= cr_write_value;
					30: strand_enable <= cr_write_value[3:0];
					31: strand_enable <= 0;	// HALT
				endcase
			end
		end
	end
endmodule
