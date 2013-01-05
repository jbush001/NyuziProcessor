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
	
	// Control signals to from other units
	output reg[3:0]		strand_enable,
	output reg[31:0]	exception_handler_address,
	input				latch_fault,
	input [31:0]		fault_pc,
	input [1:0]			fault_strand,

	// To memory access/writeback stage.
	input[1:0]			ex_strand,	// strand that is reading or writing control register
	input[4:0]			cr_index,
	input 				cr_read_en,
	input				cr_write_en,
	input[31:0]			cr_write_value,
	output reg[31:0]	cr_read_value);

	reg[31:0] saved_fault_pc[0:3];
	integer i;

	localparam CR_STRAND_ID = 0;
	localparam CR_EXCEPTION_HANDLER = 1;
	localparam CR_FAULT_ADDRESS = 2;
	localparam CR_HALT_STRAND = 29;
	localparam CR_STRAND_ENABLE = 30;
	localparam CR_HALT = 31;

	assert_false #("cr_read_en and cr_write_en asserted simultaneously") a0(
		.clk(clk), .test(cr_read_en && cr_write_en));

	always @*
	begin
		case (cr_index)
			CR_STRAND_ID: cr_read_value = { CORE_ID, ex_strand }; 		// Strand ID
			CR_EXCEPTION_HANDLER: cr_read_value = exception_handler_address;
			CR_FAULT_ADDRESS: cr_read_value = saved_fault_pc[ex_strand];
			CR_STRAND_ENABLE: cr_read_value = strand_enable;
			default: cr_read_value = 0;
		endcase
	end

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
		 	strand_enable <= 4'b0001;	// Enable strand 0
			for (i = 0; i < 4; i = i + 1)
				saved_fault_pc[i] <= 0;

			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			exception_handler_address <= 32'h0;
			// End of automatics
		end
		else
		begin
			// Transfer to a control register
			if (cr_write_en)
			begin
				case (cr_index)
					CR_HALT_STRAND: strand_enable <= strand_enable & ~(4'b0001 << ex_strand);
					CR_EXCEPTION_HANDLER: exception_handler_address <= cr_write_value;
					CR_STRAND_ENABLE: strand_enable <= cr_write_value[3:0];
					CR_HALT: strand_enable <= 0;	// HALT
				endcase
			end
			
			// Fault handling
			if (latch_fault)
			begin
				$display("latching fault address %x", fault_pc);
				saved_fault_pc[fault_strand] <= fault_pc;
			end
		end
	end
endmodule
