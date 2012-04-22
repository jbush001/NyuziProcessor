//
// Level 2 Cache
// 

`include "l2_cache.h"

module l2_cache
	#(parameter					NUM_CORES = 1)

	(input						clk,
	input						pci_valid_i,
	output 						pci_ack_o,
	input [1:0]					pci_unit_i,
	input [1:0]					pci_strand_i,
	input [2:0]					pci_op_i,
	input [1:0]					pci_way_i,
	input [25:0]				pci_address_i,
	input [511:0]				pci_data_i,
	input [63:0]				pci_mask_i,
	output reg					cpi_valid_o = 0,
	output reg					cpi_status_o = 0,
	output reg[1:0]				cpi_unit_o = 0,
	output reg[1:0]				cpi_strand_o = 0,
	output reg[1:0]				cpi_op_o = 0,
	output reg					cpi_update_o = 0,
	output reg[1:0]				cpi_way_o = 0,
	output reg[511:0]			cpi_data_o = 0,

	// System memory interface
	output reg[31:0]			addr_o = 0,
	output reg 					request_o = 0,
	input 						ack_i,
	output reg					write_o,
	input [31:0]				data_i,
	output [31:0]				data_o);



	localparam					L1_SET_INDEX_WIDTH = 5;
	localparam					L1_NUM_SETS = 32;
	localparam					L1_NUM_WAYS = 4;
	localparam					L1_TAG_WIDTH = 32 - L1_SET_INDEX_WIDTH - 6;

	localparam					L2_SET_INDEX_WIDTH = 5;
	localparam					L2_NUM_SETS = 32;
	localparam					L2_NUM_WAYS = 4;
	localparam					L2_TAG_WIDTH = 32 - L2_SET_INDEX_WIDTH - 6;
	localparam					L2_CACHE_ADDR = L2_SET_INDEX_WIDTH + 2;

	integer i;		


	wire[L2_SET_INDEX_WIDTH - 1:0] requested_set_index2;

	initial
	begin
		for (i = 0; i < NUM_DIR_ENTRIES; i = i + 1)
		begin
			dir_valid_mem[i] = 0;
			dir_way_mem[i] = 0;
			dir_tag_mem[i] = 0;
		end

		for (i = 0; i < L2_NUM_SETS; i = i + 1)
		begin
			tag_mem0[i] = 0;
			tag_mem1[i] = 0;
			tag_mem2[i] = 0;
			tag_mem3[i] = 0;
			valid_mem0[i] = 0;
			valid_mem1[i] = 0;
			valid_mem2[i] = 0;
			valid_mem3[i] = 0;
			dirty_mem0[i] = 0;
			dirty_mem1[i] = 0;
			dirty_mem2[i] = 0;
			dirty_mem3[i] = 0;
		end	
	end

	wire stall_pipeline;
	wire smq_data_ready;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire		arb_has_sm_data;	// From l2_cache_arb of l2_cache_arb.v
	wire [25:0]	arb_pci_address;	// From l2_cache_arb of l2_cache_arb.v
	wire [511:0]	arb_pci_data;		// From l2_cache_arb of l2_cache_arb.v
	wire [63:0]	arb_pci_mask;		// From l2_cache_arb of l2_cache_arb.v
	wire [2:0]	arb_pci_op;		// From l2_cache_arb of l2_cache_arb.v
	wire [1:0]	arb_pci_strand;		// From l2_cache_arb of l2_cache_arb.v
	wire [1:0]	arb_pci_unit;		// From l2_cache_arb of l2_cache_arb.v
	wire		arb_pci_valid;		// From l2_cache_arb of l2_cache_arb.v
	wire [1:0]	arb_pci_way;		// From l2_cache_arb of l2_cache_arb.v
	wire [511:0]	arb_sm_data;		// From l2_cache_arb of l2_cache_arb.v
	wire [1:0]	arb_sm_fill_way;	// From l2_cache_arb of l2_cache_arb.v
	// End of automatics

	l2_cache_arb l2_cache_arb(/*AUTOINST*/
				  // Outputs
				  .pci_ack_o		(pci_ack_o),
				  .arb_pci_valid	(arb_pci_valid),
				  .arb_pci_unit		(arb_pci_unit[1:0]),
				  .arb_pci_strand	(arb_pci_strand[1:0]),
				  .arb_pci_op		(arb_pci_op[2:0]),
				  .arb_pci_way		(arb_pci_way[1:0]),
				  .arb_pci_address	(arb_pci_address[25:0]),
				  .arb_pci_data		(arb_pci_data[511:0]),
				  .arb_pci_mask		(arb_pci_mask[63:0]),
				  .arb_has_sm_data	(arb_has_sm_data),
				  .arb_sm_data		(arb_sm_data[511:0]),
				  .arb_sm_fill_way	(arb_sm_fill_way[1:0]),
				  // Inputs
				  .clk			(clk),
				  .stall_pipeline	(stall_pipeline),
				  .pci_valid_i		(pci_valid_i),
				  .pci_unit_i		(pci_unit_i[1:0]),
				  .pci_strand_i		(pci_strand_i[1:0]),
				  .pci_op_i		(pci_op_i[2:0]),
				  .pci_way_i		(pci_way_i[1:0]),
				  .pci_address_i	(pci_address_i[25:0]),
				  .pci_data_i		(pci_data_i[511:0]),
				  .pci_mask_i		(pci_mask_i[63:0]),
				  .smq_pci_unit		(smq_pci_unit[1:0]),
				  .smq_pci_strand	(smq_pci_strand[1:0]),
				  .smq_pci_op		(smq_pci_op[2:0]),
				  .smq_pci_way		(smq_pci_way[1:0]),
				  .smq_pci_address	(smq_pci_address[25:0]),
				  .smq_pci_data		(smq_pci_data[511:0]),
				  .smq_pci_mask		(smq_pci_mask[63:0]),
				  .smq_load_buffer_vec	(smq_load_buffer_vec[511:0]),
				  .smq_data_ready	(smq_data_ready),
				  .smq_fill_way		(smq_fill_way[1:0]));

	////////////////////////////////////////////////////////////////
	// Stage 1: Tag Issue
	//  Issue address to tag ram and check LRU
	////////////////////////////////////////////////////////////////

	reg						stg1_pci_valid = 0;
	reg[1:0]				stg1_pci_unit = 0;
	reg[1:0]				stg1_pci_strand = 0;
	reg[2:0]				stg1_pci_op = 0;
	reg[1:0]				stg1_pci_way = 0;
	reg[25:0]				stg1_pci_address = 0;
	reg[511:0]				stg1_pci_data = 0;
	reg[63:0]				stg1_pci_mask = 0;
	reg						stg1_has_sm_data = 0;
	reg[511:0]				stg1_sm_data = 0;
	reg[1:0]				stg1_sm_fill_way = 0;
	reg[1:0] 				stg1_replace_way = 0;
	wire[1:0] 				stg1_hit_way;
	reg[L2_TAG_WIDTH - 1:0]	stg1_tag0 = 0;
	reg[L2_TAG_WIDTH - 1:0]	stg1_tag1 = 0;
	reg[L2_TAG_WIDTH - 1:0]	stg1_tag2 = 0;
	reg[L2_TAG_WIDTH - 1:0]	stg1_tag3 = 0;
	reg						stg1_valid0 = 0;
	reg						stg1_valid1 = 0;
	reg						stg1_valid2 = 0;
	reg						stg1_valid3 = 0;

	// Memories
	reg[L2_TAG_WIDTH - 1:0]	tag_mem0[0:L2_NUM_SETS - 1];
	reg						valid_mem0[0:L2_NUM_SETS - 1];
	reg[L2_TAG_WIDTH - 1:0]	tag_mem1[0:L2_NUM_SETS - 1];
	reg						valid_mem1[0:L2_NUM_SETS - 1];
	reg[L2_TAG_WIDTH - 1:0]	tag_mem2[0:L2_NUM_SETS - 1];
	reg						valid_mem2[0:L2_NUM_SETS - 1];
	reg[L2_TAG_WIDTH - 1:0]	tag_mem3[0:L2_NUM_SETS - 1];
	reg						valid_mem3[0:L2_NUM_SETS - 1];

	wire[L2_SET_INDEX_WIDTH - 1:0] requested_set_index1 = arb_pci_address[6 + L2_SET_INDEX_WIDTH - 1:6];
	wire[L2_TAG_WIDTH - 1:0] requested_tag1 = arb_pci_address[L2_TAG_WIDTH - L2_SET_INDEX_WIDTH:0];
	wire[1:0] lru_way;

	cache_lru #(L2_SET_INDEX_WIDTH, L2_NUM_SETS) lru(
		.clk(clk),
		.new_mru_way(stg1_sm_fill_way),
		.set_i(stg1_has_sm_data ? stg1_sm_fill_way : requested_set_index2),
		.update_mru(stg1_pci_valid),
		.lru_way_o(lru_way));

	always @(posedge clk)
	begin
		if (!stall_pipeline)
		begin
			if (arb_pci_valid)
				$display("arb_: op = %d", arb_pci_op);

			stg1_pci_valid <= #1 arb_pci_valid;
			stg1_pci_unit <= #1 arb_pci_unit;
			stg1_pci_strand <= #1 arb_pci_strand;
			stg1_pci_op <= #1 arb_pci_op;
			stg1_pci_way <= #1 arb_pci_way;
			stg1_pci_address <= #1 arb_pci_address;
			stg1_pci_data <= #1 arb_pci_data;
			stg1_pci_mask <= #1 arb_pci_mask;
			stg1_has_sm_data <= #1 arb_has_sm_data;	
			stg1_sm_data <= #1 arb_sm_data;
			stg1_replace_way <= #1 lru_way;
			stg1_tag0 	<= #1 tag_mem0[requested_set_index1];
			stg1_valid0 <= #1 valid_mem0[requested_set_index1];
			stg1_tag1 	<= #1 tag_mem1[requested_set_index1];
			stg1_valid1 <= #1 valid_mem1[requested_set_index1];
			stg1_tag2 	<= #1 tag_mem2[requested_set_index1];
			stg1_valid2 <= #1 valid_mem2[requested_set_index1];
			stg1_tag3 	<= #1 tag_mem3[requested_set_index1];
			stg1_valid3 <= #1 valid_mem3[requested_set_index1];
			stg1_sm_fill_way <= #1 arb_sm_fill_way;
			if (arb_has_sm_data)
			begin
				// Update tag memory if this is a restarted request
				$display("update tag memory way %d set %d tag %x", arb_sm_fill_way,
					requested_set_index1, requested_tag1);
				case (arb_sm_fill_way)
					0:
					begin
						valid_mem0[requested_set_index1] <= #1 1;
						tag_mem0[requested_set_index1] <= #1 requested_tag1;
					end

					1:
					begin
						valid_mem1[requested_set_index1] <= #1 1;
						tag_mem1[requested_set_index1] <= #1 requested_tag1;
					end

					2:
					begin
						valid_mem2[requested_set_index1] <= #1 1;
						tag_mem2[requested_set_index1] <= #1 requested_tag1;
					end

					3:				
					begin
						valid_mem3[requested_set_index1] <= #1 1;
						tag_mem3[requested_set_index1] <= #1 requested_tag1;
					end
				endcase
			end
		end
	end

	////////////////////////////////////////////////////////////////
	// Stage 2: Tag check, directory issue
	////////////////////////////////////////////////////////////////

	// Directory key is { l2_way, l2_set }
	// Directory entries are: valid, l1_way, tag
	localparam NUM_DIR_ENTRIES = L2_NUM_SETS * L2_NUM_WAYS * NUM_CORES;
	localparam DIR_INDEX_WIDTH = $clog2(NUM_DIR_ENTRIES);

	reg			stg2_pci_valid = 0;
	reg[1:0]	stg2_pci_unit = 0;
	reg[1:0]	stg2_pci_strand = 0;
	reg[2:0]	stg2_pci_op = 0;
	reg[1:0]	stg2_pci_way = 0;
	reg[25:0]	stg2_pci_address = 0;
	reg[511:0]	stg2_pci_data = 0;
	reg[63:0]	stg2_pci_mask = 0;
	reg			stg2_has_sm_data = 0;
	reg[511:0]	stg2_sm_data = 0;
	reg[1:0] 	stg2_hit_way = 0;
	reg[1:0] 	stg2_replace_way = 0;
	reg 		stg2_cache_hit = 0;
	reg[L2_TAG_WIDTH - 1:0] stg2_replace_tag = 0;
	reg[NUM_CORES - 1:0] stg2_dir_valid = 0;
	reg[NUM_CORES * 2 - 1:0] stg2_dir_way = 0;
	reg[NUM_CORES * L1_TAG_WIDTH - 1:0] stg2_dir_tag = 0;
	reg[L2_SET_INDEX_WIDTH - 1:0] stg2_request_set = 0;

	// Memories (need to create directory entries for each core, currently hard-coded to one)
	reg dir_valid_mem[0:NUM_DIR_ENTRIES - 1];
	reg[1:0] dir_way_mem[0:NUM_DIR_ENTRIES - 1];
	reg[L1_TAG_WIDTH - 1:0] dir_tag_mem[0:NUM_DIR_ENTRIES - 1];
	reg	dirty_mem0[0:L2_NUM_SETS - 1];
	reg	dirty_mem1[0:L2_NUM_SETS - 1];
	reg	dirty_mem2[0:L2_NUM_SETS - 1];
	reg	dirty_mem3[0:L2_NUM_SETS - 1];

	wire hit0 = stg1_tag0 == requested_tag2 && stg1_valid0;
	wire hit1 = stg1_tag1 == requested_tag2 && stg1_valid1;
	wire hit2 = stg1_tag2 == requested_tag2 && stg1_valid2;
	wire hit3 = stg1_tag3 == requested_tag2 && stg1_valid3;
	wire stg1_cache_hit = hit0 || hit1 || hit2 || hit3;
	wire[DIR_INDEX_WIDTH:0] dir_index = stg1_cache_hit ? stg1_hit_way : stg1_replace_way;
	wire[L2_TAG_WIDTH - 1:0] requested_tag2 = stg1_pci_address[L2_TAG_WIDTH - L2_SET_INDEX_WIDTH:0];

	reg[L2_TAG_WIDTH - 1:0] replace_tag_muxed = 0;
	reg stg2_dirty0 = 0;
	reg stg2_dirty1 = 0;
	reg stg2_dirty2 = 0;
	reg stg2_dirty3 = 0;

	assign requested_set_index2 = stg2_pci_address[6 + L2_SET_INDEX_WIDTH - 1:6];

	always @*
	begin
		case (stg1_replace_way)
			0: replace_tag_muxed = stg1_tag0;
			1: replace_tag_muxed = stg1_tag1;
			2: replace_tag_muxed = stg1_tag2;
			3: replace_tag_muxed = stg1_tag3;
		endcase
	end

	reg[1:0] hit_way = 0;
	always @*
	begin
		case ({hit0, hit1, hit2, hit3})
			4'b1000: hit_way = 0;
			4'b0100: hit_way = 1;
			4'b0010: hit_way = 2;
			4'b0001: hit_way = 3;
			default: hit_way = 0;
		endcase
	end

	always @(posedge clk)
	begin
		if (stg1_pci_valid)
			$display("stg1: op = %d", stg1_pci_op);

		if (!stall_pipeline)
		begin
			if (stg1_pci_valid)
			begin
				if ((stg1_pci_op == `PCI_STORE || stg1_pci_op == `PCI_STORE_SYNC) 
					&& (stg1_cache_hit || stg1_has_sm_data))
				begin
					$display("set dirty bit");
					// Update dirty bits if we are writing to a line
					case (hit_way)
						0: dirty_mem0[requested_set_index2] <= 1'b1;
						1: dirty_mem1[requested_set_index2] <= 1'b1;
						2: dirty_mem2[requested_set_index2] <= 1'b1;
						3: dirty_mem3[requested_set_index2] <= 1'b1;
					endcase
				end
				else if (stg2_has_sm_data)
				begin
					// Clear dirty bits if we are loading new data and not writing
					// to it.
					$display("clear dirty bit");
					case (hit_way)
						0: dirty_mem0[requested_set_index2] <= 1'b0;
						1: dirty_mem1[requested_set_index2] <= 1'b0;
						2: dirty_mem2[requested_set_index2] <= 1'b0;
						3: dirty_mem3[requested_set_index2] <= 1'b0;
					endcase
				end
	
				// Update directory (note we are doing a read in the same cycle;
				// it should fetch the previous value of this entry).  Do we need
				// an extra stage to do RMW like with cache memory?
				if ((stg1_cache_hit || stg1_has_sm_data)
					&& (stg1_pci_op == `PCI_LOAD || stg1_pci_op == `PCI_LOAD_SYNC))
				begin
					dir_valid_mem[dir_index] <= #1 1;
					dir_way_mem[dir_index] <= #1 stg1_pci_way;
					dir_tag_mem[dir_index] <= #1 requested_tag2;
				end
			end

			stg2_pci_valid <= #1 stg1_pci_valid;
			stg2_pci_unit <= #1 stg1_pci_unit;
			stg2_pci_strand <= #1 stg1_pci_strand;
			stg2_pci_op <= #1 stg1_pci_op;
			stg2_pci_way <= #1 stg1_pci_way;
			stg2_pci_address <= #1 stg1_pci_address;
			stg2_pci_data <= #1 stg1_pci_data;
			stg2_pci_mask <= #1 stg1_pci_mask;
			stg2_has_sm_data <= #1 stg1_has_sm_data;	
			stg2_sm_data <= #1 stg1_sm_data;		
			stg2_hit_way <= #1 stg1_hit_way;
			stg2_replace_way <= #1 stg1_replace_way;
			stg2_dir_valid <= #1 dir_valid_mem[dir_index];
			stg2_dir_way <= #1 dir_way_mem[dir_index];
			stg2_dir_tag <= #1 dir_tag_mem[dir_index];
			stg2_cache_hit <= #1 stg1_cache_hit;
			stg2_hit_way <= #1 hit_way;
			stg2_replace_tag <= #1 replace_tag_muxed;
			stg2_dirty0	<= #1 dirty_mem0[requested_set_index2];
			stg2_dirty1	<= #1 dirty_mem1[requested_set_index2];
			stg2_dirty2	<= #1 dirty_mem2[requested_set_index2];
			stg2_dirty3	<= #1 dirty_mem3[requested_set_index2];
		end
	end

	////////////////////////////////////////////////////////////////
	// Stage 3: Directory Check, Cache memory read issue	
	//  - Check/Update dirty bits
 	////////////////////////////////////////////////////////////////

	reg			stg3_pci_valid = 0;
	reg[1:0]	stg3_pci_unit = 0;
	reg[1:0]	stg3_pci_strand = 0;
	reg[2:0]	stg3_pci_op = 0;
	reg[1:0]	stg3_pci_way = 0;
	reg[25:0]	stg3_pci_address = 0;
	reg[511:0]	stg3_pci_data = 0;
	reg[63:0]	stg3_pci_mask = 0;
	reg 		stg3_has_sm_data = 0;
	reg[511:0] 	stg3_sm_data = 0;
	reg[1:0] 	stg3_hit_way = 0;
	reg[1:0] 	stg3_replace_way = 0;
	reg 		stg3_cache_hit = 0;
	reg[NUM_CORES - 1:0] stg3_dir_valid = 0;
	reg[NUM_CORES * 2 - 1:0] stg3_dir_way = 0;
	reg[NUM_CORES * L1_TAG_WIDTH - 1:0] stg3_dir_tag = 0;
	reg[L2_SET_INDEX_WIDTH - 1:0] stg3_request_set = 0;
	reg[L2_CACHE_ADDR - 1:0]  stg3_cache_mem_addr = 0;
	reg[511:0] stg3_cache_mem_result = 0;
	reg[L2_TAG_WIDTH - 1:0] stg3_replace_tag = 0;

	// Memories
	reg[511:0] cache_mem[0:L2_NUM_SETS * L2_NUM_WAYS - 1];	

	wire[L2_CACHE_ADDR - 1:0] cache_mem_addr = stg2_cache_hit ? { stg2_hit_way, stg2_request_set }
		: { stg2_replace_way, stg2_request_set };

	reg stg3_replace_is_dirty = 0;
	reg replace_is_dirty_muxed = 0;
	always @*
	begin
		case (stg2_replace_way)
			0: replace_is_dirty_muxed = stg2_dirty0;
			1: replace_is_dirty_muxed = stg2_dirty1;
			2: replace_is_dirty_muxed = stg2_dirty2;
			3: replace_is_dirty_muxed = stg2_dirty3;
		endcase
	end

	always @(posedge clk)
	begin
		if (stg2_pci_valid)
			$display("stg2: op = %d", stg2_pci_op);

		if (!stall_pipeline)
		begin
			stg3_pci_valid <= #1 stg2_pci_valid;
			stg3_pci_unit <= #1 stg2_pci_unit;
			stg3_pci_strand <= #1 stg2_pci_strand;
			stg3_pci_op <= #1 stg2_pci_op;
			stg3_pci_way <= #1 stg2_pci_way;
			stg3_pci_address <= #1 stg2_pci_address;
			stg3_pci_data <= #1 stg2_pci_data;
			stg3_pci_mask <= #1 stg2_pci_mask;
			stg3_has_sm_data <= #1 stg2_has_sm_data;	
			stg3_sm_data <= #1 stg2_sm_data;	
			stg3_hit_way <= #1 stg2_hit_way;
			stg3_replace_way <= #1 stg2_replace_way;
			stg3_cache_hit <= #1 stg2_cache_hit;
			stg3_dir_valid <= #1 stg2_dir_valid;
			stg3_dir_way <= #1 stg2_dir_way;
			stg3_dir_tag <= #1 stg2_dir_tag;
			stg3_request_set <= #1 stg2_request_set;
			stg3_replace_tag <= #1 stg2_replace_tag;
			stg3_replace_is_dirty <= #1 replace_is_dirty_muxed;
			stg3_cache_mem_addr <= #1 cache_mem_addr;
			if (stg2_has_sm_data)
				stg3_cache_mem_result <= #1 stg2_sm_data;
			else
				stg3_cache_mem_result <= #1 cache_mem[cache_mem_addr];
		end
	end	

	
	////////////////////////////////////////////////////////////////
	// Stage 4: Cache memory write issue
	// This is where most of the magic happens
	// - For writes, combine the requested write data with the
	//   previous data in the line.  Otherwise just pass data 
	//   through.
	////////////////////////////////////////////////////////////////

	reg			stg4_pci_valid = 0;
	reg[1:0]	stg4_pci_unit = 0;
	reg[1:0]	stg4_pci_strand = 0;
	reg[2:0]	stg4_pci_op = 0;
	reg[1:0]	stg4_pci_way = 0;
	reg[25:0]	stg4_pci_address = 0;
	reg[511:0]	stg4_pci_data = 0;
	reg[63:0]	stg4_pci_mask = 0;
	wire[511:0] masked_write_data;
	reg 		stg4_cache_hit = 0;
	reg[511:0] 	stg4_data = 0;
	reg[NUM_CORES - 1:0] stg4_dir_valid = 0;
	reg[NUM_CORES * 2 - 1:0] stg4_dir_way = 0;
	reg[NUM_CORES * L1_TAG_WIDTH - 1:0] stg4_dir_tag = 0;
	reg 		stg4_has_sm_data = 0;

	mask_unit mu(
		.mask_i(stg3_pci_mask), 
		.data0_i(stg3_pci_data), 
		.data1_i(stg3_cache_mem_result), 
		.result_o(masked_write_data));
	

	// XXXXX Need to bypass store data from XXXXXXX

	always @(posedge clk)
	begin
		if (stg3_pci_valid)
			$display("stg3: op = %d", stg3_pci_op);

		if (!stall_pipeline)
		begin
			stg4_pci_valid <= #1 stg3_pci_valid;
			stg4_pci_unit <= #1 stg3_pci_unit;
			stg4_pci_strand <= #1 stg3_pci_strand;
			stg4_pci_op <= #1 stg3_pci_op;
			stg4_pci_way <= #1 stg3_pci_way;
			stg4_pci_address <= #1 stg3_pci_address;
			stg4_pci_data <= #1 stg3_pci_data;
			stg4_pci_mask <= #1 stg3_pci_mask;
			stg4_has_sm_data <= #1 stg3_has_sm_data;
			stg4_dir_valid <= #1 stg3_dir_valid;
			stg4_dir_way <= #1 stg3_dir_way;
			stg4_dir_tag <= #1 stg3_dir_tag;
			stg4_cache_hit <= #1 stg3_cache_hit;
			stg4_pci_op <= #1 stg3_pci_op;
			if ((stg3_pci_op == `PCI_STORE || stg3_pci_op == `PCI_STORE_SYNC) && stg3_cache_hit)
			begin
				// This is a store
				$display("store to %x <= %x", stg3_cache_mem_addr,
					masked_write_data);
				stg4_data <= #1 masked_write_data;
				cache_mem[stg3_cache_mem_addr] <= #1 masked_write_data;
			end
			else
			begin
				// This is a load
				stg4_data <= #1 stg3_cache_mem_result;		

				// If we have read data from system memory, update the
				// cache line now.
				if (stg3_has_sm_data)
				begin
					$display("updating cache memory from sm: %x", stg3_sm_data);
					cache_mem[stg3_cache_mem_addr] <= #1 stg3_sm_data;
				end
			end
		end
	end

	////////////////////////////////////////////////////////////////
	// Stage 5: Response
	// Send a response on the CPI interface
	// - Cache Read Hit: send an acknowledgement.
	// - Cache Write Hit: send an acknowledgement and the new contents
	//   of the line.  If there are lines in other cores that match,
	//   need to send write updates for those.  
	// - Cache miss: don't send anything.
	////////////////////////////////////////////////////////////////

	reg[1:0] response_op = 0;

	always @*
	begin
		case (stg4_pci_op)
			`PCI_LOAD: response_op = `CPI_LOAD_ACK;
			`PCI_STORE: response_op = `CPI_STORE_ACK;
			`PCI_FLUSH: response_op = 0;
			`PCI_INVALIDATE: response_op = 0;
			`PCI_LOAD_SYNC: response_op = `CPI_LOAD_ACK;
			`PCI_STORE_SYNC: response_op = `CPI_STORE_ACK;
			default: response_op = 0;
		endcase
	end

	always @(posedge clk)
	begin
		if (stg4_pci_valid)
			$display("stg4: op = %d", stg4_pci_op);

		if (stg4_pci_valid && (stg4_cache_hit || stg4_has_sm_data))
		begin
			cpi_valid_o <= #1 stg4_pci_valid;
			cpi_status_o <= #1 1;
			cpi_unit_o <= #1 stg4_pci_unit;
			cpi_strand_o <= #1 stg4_pci_strand;
			cpi_op_o <= #1 response_op;	
			cpi_update_o <= #1 stg4_dir_valid;	
			cpi_way_o <= #1 stg4_dir_way;
			cpi_data_o <= #1 stg4_data;	
		end
		else
			cpi_valid_o <= #1 0;
	end

	////////////////////////////////////////////////////////////////
	// System Memory Interface 
	// State machine interacts with system memory to move data to
	// and from the L2 cache.  Stage 4 puts things into the queue,
	// when they are finished, they go back into stage one of the 
	// pipeline through an arbiter.
	////////////////////////////////////////////////////////////////

	wire[10:6]		smqi_set_index = stg3_pci_address[10:6];
	wire			smqi_writeback_enable = stg3_replace_is_dirty && stg3_pci_valid && stg3_cache_hit;
	wire[25:0]		smqi_writeback_address = { stg3_replace_tag, smqi_set_index };

	wire[1:0]		smq_replace_way;
	wire[511:0]		smq_writeback_data;	
	wire 			smq_writeback_enable;
	wire[25:0]		smq_writeback_address;
	wire[1:0]		smq_pci_unit;				
	wire[1:0]		smq_pci_strand;
	wire[2:0]		smq_pci_op;
	wire[1:0]		smq_pci_way;
	wire[25:0]		smq_pci_address;
	wire[511:0]		smq_pci_data;
	wire[63:0]		smq_pci_mask;
	wire[1:0]		smq_fill_way;

	wire smq_can_enqueue;
	wire want_smqi_enqueue = stg3_pci_valid && !stg3_cache_hit && !stg3_has_sm_data;
	wire smqi_enable = want_smqi_enqueue && smq_can_enqueue;
	assign stall_pipeline = want_smqi_enqueue && !smq_can_enqueue;
	wire smq_valid;
	reg transaction_complete = 0;

	sync_fifo #(1152, 4, 2) smq(
		.clk(clk),
		.flush_i(1'b0),
		.can_enqueue_o(smq_can_enqueue),
		.enqueue_i(smqi_enable),
		.value_i(
			{ 
				stg3_replace_way,			// which way to fill
				stg3_cache_mem_result,	// Old line to writeback
				smqi_writeback_enable,	// Replace line is dirty and valid
				smqi_writeback_address,	// Old address
				stg3_pci_unit,
				stg3_pci_strand,
				stg3_pci_op,
				stg3_pci_way,
				stg3_pci_address,
				stg3_pci_data,
				stg3_pci_mask
			}),
		.can_dequeue_o(smq_valid),
		.dequeue_i(transaction_complete),
		.value_o(
			{ 
				smq_fill_way,
				smq_writeback_data,
				smq_writeback_enable,
				smq_writeback_address,
				smq_pci_unit,
				smq_pci_strand,
				smq_pci_op,
				smq_pci_way,
				smq_pci_address,
				smq_pci_data,
				smq_pci_mask
			}));

	localparam STATE_IDLE = 0;
	localparam STATE_WRITEBACK = 1;
	localparam STATE_READ = 2;
	localparam STATE_WAIT_ISSUE = 3;

	localparam BURST_LENGTH = 16;	// 4 bytes per transfer, cache line is 64 bytes

	reg[1:0] state_ff = 0;
	reg[1:0] state_nxt = 0;
	reg[3:0] burst_offset_ff = 0;
	reg[3:0] burst_offset_nxt = 0;
	reg[31:0] smq_load_buffer[0:15];
	wire[511:0] smq_load_buffer_vec = {
		smq_load_buffer[0],
		smq_load_buffer[1],
		smq_load_buffer[2],
		smq_load_buffer[3],
		smq_load_buffer[4],
		smq_load_buffer[5],
		smq_load_buffer[6],
		smq_load_buffer[7],
		smq_load_buffer[8],
		smq_load_buffer[9],
		smq_load_buffer[10],
		smq_load_buffer[11],
		smq_load_buffer[12],
		smq_load_buffer[13],
		smq_load_buffer[14],
		smq_load_buffer[15]
	};

	assign smq_data_ready = state_ff == STATE_WAIT_ISSUE;

	always @*
	begin
		state_nxt = state_ff;
		transaction_complete = 0;
		burst_offset_nxt = burst_offset_ff;
		request_o = 0;

		case (state_ff)
			STATE_IDLE:
			begin
				if (smq_valid)
				begin
					if (smq_writeback_enable)
						state_nxt = STATE_WRITEBACK;
					else
						state_nxt = STATE_READ;
				end
			end

			STATE_WRITEBACK:
			begin
				request_o = 1;
				
				if (ack_i)
				begin
					if (burst_offset_ff == BURST_LENGTH - 1)
						state_nxt = STATE_READ;

					burst_offset_nxt = burst_offset_ff + 1;
				end
			end
	
			STATE_READ:
			begin
				request_o = 1;
				if (ack_i)
				begin
					if (burst_offset_ff == BURST_LENGTH - 1)
						state_nxt = STATE_WAIT_ISSUE;

					burst_offset_nxt = burst_offset_ff + 1;
				end
			end

			STATE_WAIT_ISSUE:
			begin
				// Make sure the response is in the pipeline
				state_nxt = STATE_IDLE;
				transaction_complete = 1;
			end
		endcase
	end

	always @(posedge clk)
	begin
		if (state_ff == STATE_READ)
			smq_load_buffer[burst_offset_ff] <= data_i;
	end

	assign data_o = smq_writeback_data >> (burst_offset_ff * 32); 


	always @(posedge clk)
	begin
		if (state_ff != state_nxt)
		begin
			$write("state is now ");
			case (state_nxt)
				STATE_IDLE: $display("STATE_IDLE");
				STATE_WRITEBACK: $display("STATE_WRITEBACK");
				STATE_READ: $display("STATE_READ");
				STATE_WAIT_ISSUE: $display("STATE_WAIT_ISSUE");
			endcase
		end

		state_ff <= #1 state_nxt;
		burst_offset_ff <= #1 burst_offset_nxt;
	end

endmodule
