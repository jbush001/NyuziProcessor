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

module fpga_top(
	input						clk,
	output [31:0]			addr_o,
	output  					request_o,
	input 						ack_i,
	output 					write_o,
	input [31:0]				data_i,
	output [31:0]				data_o);

	wire 				pci_valid;
	wire				pci_ack;
	wire [1:0]		pci_strand;
	wire [1:0]		pci_unit;
	wire [2:0]		pci_op;
	wire [1:0]		pci_way;
	wire [25:0]		pci_address;
	wire [511:0]		pci_data;
	wire [63:0]		pci_mask;
	wire 				cpi_valid;
	wire				cpi_status;
	wire [1:0]			cpi_unit;
	wire [1:0]			cpi_strand;
	wire [1:0]			cpi_op;
	wire 				cpi_update;
	wire [1:0]			cpi_way;
	wire [511:0]		cpi_data;	
	
	core core(
		.clk(clk),
		.pci_valid(pci_valid),
		.pci_ack(pci_ack),
		.pci_strand(pci_strand),
		.pci_unit(pci_unit),
		.pci_op(pci_op),
		.pci_way(pci_way),
		.pci_address(pci_address),
		.pci_data(pci_data),
		.pci_mask(pci_mask),
		.cpi_valid(cpi_valid),
		.cpi_status(cpi_status),
		.cpi_unit(cpi_unit),
		.cpi_strand(cpi_strand),
		.cpi_op(cpi_op),
		.cpi_update(cpi_update),
		.cpi_way(cpi_way),
		.cpi_data(cpi_data),
		.halt_o());
	
	l2_cache l2_cache(
		.clk(clk),
		.pci_valid(pci_valid),
		.pci_ack(pci_ack),
		.pci_strand(pci_strand),
		.pci_unit(pci_unit),
		.pci_op(pci_op),
		.pci_way(pci_way),
		.pci_address(pci_address),
		.pci_data(pci_data),
		.pci_mask(pci_mask),
		.cpi_valid(cpi_valid),
		.cpi_status(cpi_status),
		.cpi_unit(cpi_unit),
		.cpi_strand(cpi_strand),
		.cpi_op(cpi_op),
		.cpi_update(cpi_update),
		.cpi_way(cpi_way),
		.cpi_data(cpi_data),
		.addr_o(addr_o),
		.request_o(request_o),
		.ack_i(ack_i),
		.write_o(write_o),
		.data_i(data_i),
		.data_o(data_o));

endmodule
