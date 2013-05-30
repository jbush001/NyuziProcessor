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
// Multiplexes on a per-byte basis between two sources.  Used to 
// bypass pending stores on L1 data cache accesses.  A 0 bit selects
// from data0_i and a 1 bit selects from data1_i
// 

module mask_unit(
	input mask_i,
	input [7:0] 			data0_i,
	input [7:0] 			data1_i,
	output [7:0] 			result_o);

	assign result_o = mask_i ? data1_i : data0_i;
endmodule
