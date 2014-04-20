// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 


`timescale 1ns/1ns

module jtagloader(
	input clk,
	output we,
	output reg [31:0] addr,
	output [31:0] data,
	output reg reset
	);

parameter IR_CTRL = 4'd0;
parameter IR_ADDR = 4'd1;
parameter IR_DATA = 4'd2;

initial reset = 0;

wire update;
wire [3:0] iir;
wire tck, tdi, sdr, udr, uir;
reg [31:0] dr;
reg [3:0] ir;

jtag jtag0(
	.tdi(tdi),
	.tdo(dr[0]),
	.tck(tck),
	.ir_in(iir),
	.virtual_state_sdr(sdr),
	.virtual_state_udr(udr),
	.virtual_state_uir(uir)
	);

always @(posedge tck) begin
	if (uir) ir <= iir;
	if (sdr) dr <= { tdi, dr[31:1] };
	end

sync sync0(
	.in(udr),
	.clk_in(tck),
	.out(update),
	.clk_out(clk)
	);

assign data = dr;
assign we = update & (ir == IR_DATA);

always @(posedge clk)
	if (update) case (iir)
	IR_CTRL: reset <= dr[0];
	IR_ADDR: addr <= dr;
	IR_DATA: addr <= addr + 32'd4;
	endcase

endmodule

module sync(
	input clk_in,
	input clk_out,
	input in,
	output out
	);
reg toggle;
reg [2:0] sync;
always @(posedge clk_in)
	if (in) toggle <= ~toggle;
always @(posedge clk_out)
	sync <= { sync[1:0], toggle };
assign out = (sync[2] ^ sync[1]);
endmodule

