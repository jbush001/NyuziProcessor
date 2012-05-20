//
// L2 cache pipeline directory stage.
// - If this is a cache hit, update L2 cache directory to reflect line that will
// be pushed to L1 cache.
// - Query directory if a line has been evicted to determine if it needs to be
// flushed from L1 caches (to maintain inclusion).
// - On a store, check if any L1 lines map the data and need to be updated.
// - Update/check dirty bits
//

`include "l2_cache.h"

module l2_cache_dir(
	input                            clk,
	input                            stall_pipeline,
	input                            tag_pci_valid,
	input[1:0]                       tag_pci_unit,
	input[1:0]                       tag_pci_strand,
	input[2:0]                       tag_pci_op,
	input[1:0]                       tag_pci_way,
	input[25:0]                      tag_pci_address,
	input[511:0]                     tag_pci_data,
	input[63:0]                      tag_pci_mask,
	input                            tag_has_sm_data,
	input[511:0]                     tag_sm_data,
	input[1:0]                       tag_sm_fill_l2_way,
	input[1:0]                       tag_replace_l2_way,
	input[`L2_TAG_WIDTH - 1:0]       tag_l2_tag0,
	input[`L2_TAG_WIDTH - 1:0]       tag_l2_tag1,
	input[`L2_TAG_WIDTH - 1:0]       tag_l2_tag2,
	input[`L2_TAG_WIDTH - 1:0]       tag_l2_tag3,
	input                            tag_l2_valid0,
	input                            tag_l2_valid1,
	input                            tag_l2_valid2,
	input                            tag_l2_valid3,
	output reg                       dir_pci_valid = 0,
	output reg[1:0]                  dir_pci_unit = 0,
	output reg[1:0]                  dir_pci_strand = 0,
	output reg[2:0]                  dir_pci_op = 0,
	output reg[1:0]                  dir_pci_way = 0,
	output reg[25:0]                 dir_pci_address = 0,
	output reg[511:0]                dir_pci_data = 0,
	output reg[63:0]                 dir_pci_mask = 0,
	output reg                       dir_has_sm_data = 0,
	output reg[511:0]                dir_sm_data = 0,
	output reg[1:0]                  dir_sm_fill_way = 0,
	output reg[1:0]                  dir_hit_l2_way = 0,
	output reg[1:0]                  dir_replace_l2_way = 0,
	output reg                       dir_cache_hit = 0,
	output reg[`L2_TAG_WIDTH - 1:0]  dir_replace_l2_tag = 0,
	output reg[`NUM_CORES - 1:0]     dir_l1_valid = 0,
	output reg[`NUM_CORES * 2 - 1:0] dir_l1_way = 0,
	output reg[`NUM_CORES * `L1_TAG_WIDTH - 1:0] dir_l1_tag = 0,
	output reg                       dir_l2_dirty0 = 0,
	output reg                       dir_l2_dirty1 = 0,
	output reg                       dir_l2_dirty2 = 0,
	output reg                       dir_l2_dirty3 = 0);

	integer i;

	initial
	begin
		for (i = 0; i < NUM_DIR_ENTRIES; i = i + 1)
		begin
			dir_valid_mem[i] = 0;
			dir_l1_way_mem[i] = 0;
			dir_l1_tag_mem[i] = 0;
		end

		for (i = 0; i < `L2_NUM_SETS; i = i + 1)
		begin
			l2_dirty_mem0[i] = 0;
			l2_dirty_mem1[i] = 0;
			l2_dirty_mem2[i] = 0;
			l2_dirty_mem3[i] = 0;
		end	
	end

	wire[`L1_TAG_WIDTH - 1:0] requested_l1_tag = tag_pci_address[`L1_SET_INDEX_WIDTH + `L1_TAG_WIDTH - 1:`L1_SET_INDEX_WIDTH];
	wire[`L2_TAG_WIDTH - 1:0] requested_l2_tag = tag_pci_address[25:`L2_SET_INDEX_WIDTH];
	wire[`L2_SET_INDEX_WIDTH - 1:0] requested_l2_set = tag_pci_address[`L2_SET_INDEX_WIDTH - 1:0];

	// Directory key is { l2_way, l2_set }
	// Directory entries are: valid, l1_way, tag
	localparam NUM_DIR_ENTRIES = `L2_NUM_SETS * `L2_NUM_WAYS * `NUM_CORES;
	localparam DIR_INDEX_WIDTH = $clog2(NUM_DIR_ENTRIES);

	// Memories (need to create directory entries for each core, currently hard-coded to one)
	reg dir_valid_mem[0:NUM_DIR_ENTRIES - 1];
	reg[1:0] dir_l1_way_mem[0:NUM_DIR_ENTRIES - 1];
	reg[`L1_TAG_WIDTH - 1:0] dir_l1_tag_mem[0:NUM_DIR_ENTRIES - 1];
	reg	l2_dirty_mem0[0:`L2_NUM_SETS - 1];
	reg	l2_dirty_mem1[0:`L2_NUM_SETS - 1];
	reg	l2_dirty_mem2[0:`L2_NUM_SETS - 1];
	reg	l2_dirty_mem3[0:`L2_NUM_SETS - 1];
	reg[1:0] hit_l2_way = 0;

	wire l2_hit0 = tag_l2_tag0 == requested_l2_tag && tag_l2_valid0;
	wire l2_hit1 = tag_l2_tag1 == requested_l2_tag && tag_l2_valid1;
	wire l2_hit2 = tag_l2_tag2 == requested_l2_tag && tag_l2_valid2;
	wire l2_hit3 = tag_l2_tag3 == requested_l2_tag && tag_l2_valid3;
	wire cache_hit = l2_hit0 || l2_hit1 || l2_hit2 || l2_hit3;

	reg[DIR_INDEX_WIDTH:0] dir_index = 0;

	always @*
	begin
		if (cache_hit)
			dir_index = { hit_l2_way, requested_l2_set };
		else if (tag_has_sm_data)
			dir_index = { tag_sm_fill_l2_way, requested_l2_set };
		else
			dir_index = { tag_replace_l2_way, requested_l2_set };	// I don't remember why this is
	end

	reg[`L2_TAG_WIDTH - 1:0] replace_l2_tag_muxed = 0;

	always @*
	begin
		case (tag_replace_l2_way)
			0: replace_l2_tag_muxed = tag_l2_tag0;
			1: replace_l2_tag_muxed = tag_l2_tag1;
			2: replace_l2_tag_muxed = tag_l2_tag2;
			3: replace_l2_tag_muxed = tag_l2_tag3;
		endcase
	end

	always @*
	begin
		case ({l2_hit0, l2_hit1, l2_hit2, l2_hit3})
			4'b1000: hit_l2_way = 0;
			4'b0100: hit_l2_way = 1;
			4'b0010: hit_l2_way = 2;
			4'b0001: hit_l2_way = 3;
			default: hit_l2_way = 0;
		endcase
	end

	assertion #("l2_cache_dir: more than one way was a hit") a(.clk(clk), 
		.test(l2_hit0 + l2_hit1 + l2_hit2 + l2_hit3 > 1));

	always @(posedge clk)
	begin
		if (!stall_pipeline)
		begin
			if (tag_pci_valid)
			begin
				if ((tag_pci_op == `PCI_STORE || tag_pci_op == `PCI_STORE_SYNC) 
					&& (cache_hit || tag_has_sm_data))
				begin
					// Update dirty bits if we are writing to a line
					case (hit_l2_way)
						0: l2_dirty_mem0[requested_l2_set] <= #1 1'b1;
						1: l2_dirty_mem1[requested_l2_set] <= #1 1'b1;
						2: l2_dirty_mem2[requested_l2_set] <= #1 1'b1;
						3: l2_dirty_mem3[requested_l2_set] <= #1 1'b1;
					endcase
				end
				else if (tag_has_sm_data)
				begin
					// Clear dirty bits if we are loading new data and not writing
					// to it.
					case (tag_sm_fill_l2_way)
						0: l2_dirty_mem0[requested_l2_set] <= #1 1'b0;
						1: l2_dirty_mem1[requested_l2_set] <= #1 1'b0;
						2: l2_dirty_mem2[requested_l2_set] <= #1 1'b0;
						3: l2_dirty_mem3[requested_l2_set] <= #1 1'b0;
					endcase
				end
	
				// Update directory (note we are doing a read in the same cycle;
				// it should fetch the previous value of this entry).  Do we need
				// an extra stage to do RMW like with cache memory?
				// We only track entries in the dcache
				if ((tag_pci_op == `PCI_LOAD || tag_pci_op == `PCI_LOAD_SYNC) 
					&& (cache_hit || tag_has_sm_data)
					&& tag_pci_unit == `UNIT_DCACHE)
				begin
					dir_valid_mem[dir_index] <= #1 1;
					dir_l1_way_mem[dir_index] <= #1 tag_pci_way;
					dir_l1_tag_mem[dir_index] <= #1 requested_l1_tag;
				end
			end

			dir_pci_valid <= #1 tag_pci_valid;
			dir_pci_unit <= #1 tag_pci_unit;
			dir_pci_strand <= #1 tag_pci_strand;
			dir_pci_op <= #1 tag_pci_op;
			dir_pci_way <= #1 tag_pci_way;
			dir_pci_address <= #1 tag_pci_address;
			dir_pci_data <= #1 tag_pci_data;
			dir_pci_mask <= #1 tag_pci_mask;
			dir_has_sm_data <= #1 tag_has_sm_data;	
			dir_sm_data <= #1 tag_sm_data;		
			dir_hit_l2_way <= #1 hit_l2_way;
			dir_replace_l2_way <= #1 tag_replace_l2_way;
			dir_l1_valid <= #1 dir_valid_mem[dir_index];
			dir_l1_way <= #1 dir_l1_way_mem[dir_index];
			dir_l1_tag <= #1 dir_l1_tag_mem[dir_index];
			dir_cache_hit <= #1 cache_hit;
			dir_replace_l2_tag <= #1 replace_l2_tag_muxed;
			dir_l2_dirty0	<= #1 l2_dirty_mem0[requested_l2_set] && tag_l2_valid0;
			dir_l2_dirty1	<= #1 l2_dirty_mem1[requested_l2_set] && tag_l2_valid0;
			dir_l2_dirty2	<= #1 l2_dirty_mem2[requested_l2_set] && tag_l2_valid0;
			dir_l2_dirty3	<= #1 l2_dirty_mem3[requested_l2_set] && tag_l2_valid0;
			dir_sm_fill_way <= #1 tag_sm_fill_l2_way;
		end
	end
endmodule
