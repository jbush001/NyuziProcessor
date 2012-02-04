//
// Data Cache
//
// This is virtually indexed/virtually tagged and non-blocking.
// This has one cycle of latency.  During each cycle, tag memory and
// the four way memory banks are accessed in parallel.  Combinational
// logic them determines which bank the result should be pulled from.
// 
// 8k: 4 ways, 32 sets, 64 bytes per line
//	   bits 0-5 (6) of address are the offset into the line
//	   bits 6-10 (5) are the set index
//	   bits 11-31 (21) are the tag
//

module l1_data_cache(
	input						clk,
	
	// To core
	input [31:0]				address_i,
	output reg[511:0]			data_o = 0,
	input						write_i,
	input [1:0]					strand_i,
	input						access_i,
	output						cache_hit_o,
	output [3:0]				load_complete_o,
	input[SET_INDEX_WIDTH - 1:0] store_complete_set_i,
	input						store_complete_i,
	
	// L2 interface
	output						pci0_valid_o,
	input						pci0_ack_i,
	output [3:0]				pci0_id_o,
	output [1:0]				pci0_op_o,
	output [1:0]				pci0_way_o,
	output [25:0]				pci0_address_o,
	output [511:0]				pci0_data_o,
	output [63:0]				pci0_mask_o,
	input 						cpi_valid_i,
	input [3:0]					cpi_id_i,
	input [1:0]					cpi_op_i,
	input 						cpi_allocate_i,
	input [1:0]					cpi_way_i,
	input [511:0]				cpi_data_i);
	
	
	parameter					TAG_WIDTH = 21;
	parameter					SET_INDEX_WIDTH = 5;
	parameter					WAY_INDEX_WIDTH = 2;
	parameter					NUM_SETS = 32;
	parameter					NUM_WAYS = 4;

	reg[1:0]					hit_way = 0;
	reg[1:0]					new_mru_way = 0;
	wire[1:0]					victim_way; // which way gets replaced
	reg							access_latched = 0;
	reg[SET_INDEX_WIDTH - 1:0]	request_set_latched = 0;
	reg[TAG_WIDTH - 1:0]		request_tag_latched = 0;
	reg[1:0]					strand_latched = 0;
	wire[1:0]					load_complete_way;
	wire[SET_INDEX_WIDTH - 1:0] load_complete_set;
	wire[TAG_WIDTH - 1:0]		load_complete_tag;
	integer						i;
	reg[511:0]					way0_data[0:NUM_SETS] /* synthesis syn_ramstyle = no_rw_check */;
	reg[511:0]					way1_data[0:NUM_SETS] /* synthesis syn_ramstyle = no_rw_check */;
	reg[511:0]					way2_data[0:NUM_SETS] /* synthesis syn_ramstyle = no_rw_check */;
	reg[511:0]					way3_data[0:NUM_SETS] /* synthesis syn_ramstyle = no_rw_check */;
	reg[511:0]					way0_read_data = 0;
	reg[511:0]					way1_read_data = 0;
	reg[511:0]					way2_read_data = 0;
	reg[511:0]					way3_read_data = 0;
	reg							load_collision = 0;
	wire[1:0]					tag_hit_way;

	wire[SET_INDEX_WIDTH - 1:0] requested_set = address_i[10:6];
	wire[TAG_WIDTH - 1:0] 		requested_tag = address_i[31:11];

	initial
	begin
		// synthesis translate_off
		for (i = 0; i < NUM_SETS; i = i + 1)
		begin
			way0_data[i] = 0;
			way1_data[i] = 0;
			way2_data[i] = 0;
			way3_data[i] = 0;
		end
		// synthesis translate_on
	end

	cache_tag_mem tag(
		.clk(clk),
		.address_i(address_i),
		.access_i(access_i),
		.hit_way_o(tag_hit_way),
		.cache_hit_o(cache_hit_o),
		.update_i(|load_complete_o),		// If a load has completed, mark tag valid
		.invalidate_i(0),	// XXX write invalidate will affect this.
		.update_way_i(load_complete_way),
		.update_tag_i(load_complete_tag),
		.update_set_i(load_complete_set));

	always @(posedge clk)
	begin
		access_latched 			<= #1 access_i;
		request_set_latched 	<= #1 requested_set;
		request_tag_latched		<= #1 requested_tag;
		way0_read_data			<= #1 way0_data[requested_set];
		way1_read_data			<= #1 way1_data[requested_set];
		way2_read_data			<= #1 way2_data[requested_set];
		way3_read_data			<= #1 way3_data[requested_set];
		strand_latched			<= #1 strand_i;
	end

	// We've fetched the value from all four ways in parallel.  Now
	// we know which way contains the data we care about, so select
	// that one.
	always @*
	begin
		case (hit_way)
			0: data_o = way0_read_data;
			1: data_o = way1_read_data;
			2: data_o = way2_read_data;
			3: data_o = way3_read_data;
		endcase
	end

	always @*
	begin
		if (load_collision)
			hit_way = load_complete_way;
		else
			hit_way = tag_hit_way;
	end

	// If there is a hit, move that way to the MRU.	 If there is a miss,
	// move the victim way to the MRU position so it doesn't get evicted on 
	// the next data access.
	always @*
	begin
		if (cache_hit_o)
			new_mru_way = hit_way;
		else
			new_mru_way = victim_way;
	end

	// Note that we only update the LRU if there is a cache hit or a
	// read miss (where we know we will be loading a new line).  If
	// there is a write miss, we just ignore it, because this is no-write-
	// allocate
	wire update_mru = cache_hit_o || (access_latched && !cache_hit_o 
		&& !write_i);
	
	cache_lru #(SET_INDEX_WIDTH) lru(
		.clk(clk),
		.new_mru_way(new_mru_way),
		.set_i(requested_set),
		.update_mru(update_mru),
		.lru_way_o(victim_way));

	always @(posedge clk)
	begin
		if (cpi_valid_i)
		begin
			if (load_complete_o)
			begin
				case (cpi_way_i)
					0:	way0_data[load_complete_set] <= #1 cpi_data_i;
					1:	way1_data[load_complete_set] <= #1 cpi_data_i;
					2:	way2_data[load_complete_set] <= #1 cpi_data_i;
					3:	way3_data[load_complete_set] <= #1 cpi_data_i;
				endcase
			end
			else if (store_complete_i && cpi_allocate_i)
			begin
				// XXX this makes a mess of things. Perhaps the set
				// should just be in the CPI data.
				case (cpi_way_i)
					0:	way0_data[store_complete_set_i] <= #1 cpi_data_i;
					1:	way1_data[store_complete_set_i] <= #1 cpi_data_i;
					2:	way2_data[store_complete_set_i] <= #1 cpi_data_i;
					3:	way3_data[store_complete_set_i] <= #1 cpi_data_i;
				endcase
			end
		end
	end

	// A bit of a kludge to work around a race condition where a request
	// is made in the same cycle a load finishes of the same line.
	// It will not be in tag ram, but if a load is initiated, we'll
	// end up with the cache data in 2 ways.
	always @(posedge clk)
	begin
		load_collision <= #1 (load_complete_o 
			&& load_complete_tag == requested_tag
			&& load_complete_set == requested_set 
			&& access_i);
	end

	wire read_cache_miss = !cache_hit_o && access_latched && !write_i;

	load_miss_queue lmq(
		.clk(clk),
		.request_i(read_cache_miss),
		.tag_i(request_tag_latched),
		.set_i(request_set_latched),
		.victim_way_i(victim_way),
		.strand_i(strand_latched),
		.load_complete_o(load_complete_o),
		.load_complete_set_o(load_complete_set),
		.load_complete_tag_o(load_complete_tag),
		.load_complete_way_o(load_complete_way),
		.pci_valid_o(pci0_valid_o),
		.pci_ack_i(pci0_ack_i),
		.pci_id_o(pci0_id_o),
		.pci_op_o(pci0_op_o),
		.pci_way_o(pci0_way_o),
		.pci_address_o(pci0_address_o),
		.pci_data_o(pci0_data_o),
		.pci_mask_o(pci0_mask_o),
		.cpi_valid_i(cpi_valid_i),
		.cpi_id_i(cpi_id_i),
		.cpi_op_i(cpi_op_i),
		.cpi_allocate_i(cpi_allocate_i),
		.cpi_way_i(cpi_way_i),
		.cpi_data_i(cpi_data_i));
endmodule
