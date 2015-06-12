// 
// Copyright 2011-2015 Jeff Bush
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

`ifndef __CONFIG_V
`define __CONFIG_V

// Configurable parameters
// Number of ways must be 1, 2, 4, or 8
// If the number of L2 ways is changed, the flush_l2_cache function in 
// testbench/verilator_tb.sv needs to be modified. Comments above
// that function describe why and how.

`define NUM_CORES 1
`define THREADS_PER_CORE 4
`define L1D_WAYS 4
`define L1D_SETS 64		// 16k
`define L1I_WAYS 4
`define L1I_SETS 64		// 16k
`define L2_WAYS 8
`define L2_SETS 512		// 256k
`define AXI_DATA_WIDTH 32

`endif
