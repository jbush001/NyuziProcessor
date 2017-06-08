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
// - Number of cache ways must be 1, 2, 4, or 8 (TLB_WAYS does not have
//   this constraint). This is a limitation in the cache_lru module.
// - If you change the number of L2 ways, you must also modify the
//   flush_l2_cache function in testbench/verilator_tb.sv. Comments above
//   that function describe how and why.
// - NUM_CORES must be 1-16. To synthesize more cores, increase the
//   width of core_id_t in defines.sv (as above, comments there describe why).
// - The size of a cache is sets * ways * cache line size (64 bytes)
// - L1D_SETS sets must be 64 or fewer (page size / cache line size) if
//   virtual address translation is enabled. This avoids aliasing in the
//   virtually indexed/physically tagged L1 cache by preventing the
//   same physical address from appearing in different cache sets
//   (see dcache_tag_stage)
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
`define HAS_MMU 1
`define ITLB_ENTRIES 64
`define DTLB_ENTRIES 64
`define TLB_WAYS 4

`endif
