// 
// Copyright 2011-2013 Jeff Bush
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

// Convenience module to endian swap bytes in a word.  This is a module (despite
// its simplicity) so it can be used with array instantiation for wide signals.

module endian_swapper(
	input [31:0] inval,
	output [31:0] endian_twiddled_data);

	assign endian_twiddled_data = { inval[7:0], inval[15:8], inval[23:16], inval[31:24] };
endmodule
