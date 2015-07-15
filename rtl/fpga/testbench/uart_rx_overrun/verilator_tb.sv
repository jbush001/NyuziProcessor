// 
// Copyright 2011-2015 Pipat Methavanitpong
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

module verilator_tb(
	input		clk,
	input		reset);

	string word = "A quick brown fox jumps over the lazy dog"; // 41 chars

	logic[31:0] io_address, io_write_data; 
	logic       io_write_en, io_read_en;
	wire[31:0]  io_read_data;
	wire tx2rx;

	uart uart(.*, .io_address, .io_read_en, .io_write_data, .io_write_en, .io_read_data, .uart_tx(tx2rx), .uart_rx(tx2rx));
	
	initial
	begin
		$display("Hello World\n");
		$finish;
	end
endmodule
