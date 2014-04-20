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
