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
// Arbitrates for the processor cache interface (PCI) between store buffer, L1 instruction 
// cache, and L1 data cache and muxes control signals.  This currently uses a very simple 
// fixed priority arbiter.
//

module pci_arbiter_mux(
	input				clk,
	output 				pci_valid,
	input				pci_ack,
	output reg[1:0]		pci_strand = 0,
	output reg[1:0]		pci_unit = 0,
	output reg[2:0]		pci_op = 0,
	output reg[1:0]		pci_way = 0,
	output reg[25:0]	pci_address = 0,
	output reg[511:0]	pci_data = 0,
	output reg[63:0]	pci_mask = 0,
	output				icache_pci_selected,
	output				dcache_pci_selected,
	output				stbuf_pci_selected,
	input				icache_pci_valid,
	input [1:0]			icache_pci_strand,
	input [1:0]			icache_pci_unit,
	input [2:0]			icache_pci_op,
	input [1:0]			icache_pci_way,
	input [25:0]		icache_pci_address,
	input [511:0]		icache_pci_data,
	input [63:0]		icache_pci_mask,
	input 				dcache_pci_valid,
	input [1:0]			dcache_pci_strand,
	input [1:0]			dcache_pci_unit,
	input [2:0]			dcache_pci_op,
	input [1:0]			dcache_pci_way,
	input [25:0]		dcache_pci_address,
	input [511:0]		dcache_pci_data,
	input [63:0]		dcache_pci_mask,
	input 				stbuf_pci_valid,
	input [1:0]			stbuf_pci_strand,
	input [1:0]			stbuf_pci_unit,
	input [2:0]			stbuf_pci_op,
	input [1:0]			stbuf_pci_way,
	input [25:0]		stbuf_pci_address,
	input [511:0]		stbuf_pci_data,
	input [63:0]		stbuf_pci_mask);

	reg[1:0]			selected_unit = 0;
	reg 				unit_selected = 0;

	assign icache_pci_selected = selected_unit == 0 && unit_selected;
	assign dcache_pci_selected = selected_unit == 1 && unit_selected;
	assign stbuf_pci_selected = selected_unit == 2 && unit_selected;

	// L2 arbiter
	always @*
	begin
		case (selected_unit)
			2'd0:
			begin
				pci_strand = icache_pci_strand;
				pci_unit = icache_pci_unit;
				pci_op = icache_pci_op;
				pci_way = icache_pci_way;
				pci_address = icache_pci_address;
				pci_data = icache_pci_data;
				pci_mask = icache_pci_mask;
			end

			2'd1:
			begin
				pci_strand = dcache_pci_strand;
				pci_unit = dcache_pci_unit;
				pci_op = dcache_pci_op;
				pci_way = dcache_pci_way;
				pci_address = dcache_pci_address;
				pci_data = dcache_pci_data;
				pci_mask = dcache_pci_mask;
			end

			2'd2:
			begin
				pci_strand = stbuf_pci_strand;
				pci_unit = stbuf_pci_unit;
				pci_op = stbuf_pci_op;
				pci_way = stbuf_pci_way;
				pci_address = stbuf_pci_address;
				pci_data = stbuf_pci_data;
				pci_mask = stbuf_pci_mask;
			end
			
			default:
			begin
				// Don't care
				pci_strand = {2{1'bx}};
				pci_unit = {2{1'bx}};
				pci_op = {3{1'bx}};
				pci_way = {2{1'bx}};
				pci_address = {26{1'bx}};
				pci_data = {511{1'bx}};
				pci_mask = {64{1'bx}};
			end
		endcase
	end
	
	assign pci_valid = unit_selected && !pci_ack;
	
	always @(posedge clk)
	begin
		if (unit_selected)
		begin
			// Check for end of send
			if (pci_ack)
				unit_selected <= #1 0;
		end
		else
		begin
			// Chose a new unit		
			unit_selected <= #1 (icache_pci_valid || dcache_pci_valid || stbuf_pci_valid);
			if (icache_pci_valid)
				selected_unit <= #1 0;
			else if (dcache_pci_valid)
				selected_unit <= #1 1;
			else if (stbuf_pci_valid)
				selected_unit <= #1 2;
		end
	end
endmodule
