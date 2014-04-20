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


//
// Simulates behavior of virtual JTAG loader.
//

module jtagloader(
	input clk,
	output reg we,
	output reg [31:0] addr,
	output reg[31:0] data,
	output reg reset);

	localparam MAX_WORDS = 1024;
	integer i;
	reg[31:0] temp_program[0:MAX_WORDS - 1];
	reg[1000:0] filename;

	initial
	begin
		we = 0;
		addr = 0;
		data = 0;
		reset = 0;

		if ($value$plusargs("bin=%s", filename))
			$readmemh(filename, temp_program);
		else
		begin
			$display("error opening file");
			$finish;
		end

		#5 reset = 1;
		for (i = 0; i < MAX_WORDS && temp_program[i] !== 32'hxxxxxxxx; i = i + 1)
		begin
			@(posedge clk) addr = i * 4;
			data = temp_program[i];
			we = 1;
		end	

		$display("loaded %d program words", i);
		@(posedge clk) reset = 0;
		we = 0;
	end
endmodule
