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
// Used to check for logic bugs during simulation
// On each clock edge, the input 'test' is checked.  If it is not zero
// (either X or 1), this will stop the simulation and report an error
//

module assert_false
	#(parameter 	MESSAGE = "")
	(input			clk,
	input			test);

	// synthesis translate_off
	always @(posedge clk)
	begin
		if (test != 0)
		begin
			$display("ASSERTION FAILED in %m: %s", MESSAGE);
			$finish;
		end
		else if (test !== 0)
		begin
			// Is X or Z, not a valid value.
			$display("ASSERTION FAILED in %m: test value is %d", test);
			$finish;
		end
	end
	// synthesis translate_on
endmodule
