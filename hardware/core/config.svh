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

//
// Configurable parameters
// - THREADS_PER_CORE must be 2 or greater.
// - Number of cache ways must be 1, 2, 4, or 8 (TLB_WAYS does not have
//   this constraint). This is a limitation in the cache_lru module.
// - L1D_WAYS/L1I_WAYS must be greater than or equal to THREADS_PER_CORE,
//   otherwise the system may livelock on a cache miss.
// - The number of cache sets must be a power of two.
// - If you change the number of L2 ways, you must also modify the
//   flush_l2_cache function in testbench/soc_tb.sv. Comments above
//   that function describe how and why.
// - NUM_CORES must be 1-16. To synthesize more cores, increase the
//   width of core_id_t in defines.sv (as above, comments there describe why).
// - L1D_SETS sets must be 64 or fewer (page size / cache line size). This
//   avoids aliasing in the virtually indexed/physically tagged L1 cache by
//   preventing the same physical address from appearing in different cache
//   sets (see dcache_tag_stage).
// - The size of a cache is sets * ways * cache line size (64 bytes)
//

`define NUM_CORES 1
`define THREADS_PER_CORE 4
`define L1D_WAYS 4
`define L1D_SETS 64        // 16k
`define L1I_WAYS 4
`define L1I_SETS 64        // 16k
`define L2_WAYS 8
`define L2_SETS 256        // 128k
`define AXI_DATA_WIDTH 32
`define ITLB_ENTRIES 64
`define DTLB_ENTRIES 64
`define TLB_WAYS 4

// Picked random part version and number to have unique pattern to verify.
// The manufacturer ID is chosen to be the last possible ID.
`define JTAG_PART_VERSION 4
`define JTAG_PART_NUMBER 'hd20d
`define JTAG_MANUFACTURER_ID {4'b1111,  7'b1111101}

`endif
