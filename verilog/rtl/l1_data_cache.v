//
// Data Cache
//
// This is virtually indexed/virtually tagged and non-blocking.
// It is write-thru/no-write allocate.
// The cache is pipelined and has two cycles of latency overall. In the first 
// cycle, the line index is issued to tag ram.	Tag ram has one cycle of latency. 
// In the second cycle, the results from tag RAM are checked to see if any of the 
// ways have the data. A cache_hit signal will be returned.
// If there is a cache hit, the address will be issued to the cache data RAM.
// The cache data RAM has one cycle of latency
// For a memory write, the write data and address will be issued to a store 
// buffer in the second cycle.
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
	output [511:0]				data_o,
	input [511:0]				data_i,
	input						write_i,
	input [1:0]					strand_i,
	input						access_i,
	input [63:0]				write_mask_i,
	output						cache_hit_o,
	output						stbuf_full_o,
	output [3:0]				load_complete_o,
	
	// L2 interface
	output						pci0_valid_o,
	input						pci0_ack_i,
	output [3:0]				pci0_id_o,
	output [1:0]				pci0_op_o,
	output [1:0]				pci0_way_o,
	output [25:0]				pci0_address_o,
	output [511:0]				pci0_data_o,
	output [63:0]				pci0_mask_o,
	output						pci1_valid_o,
	input						pci1_ack_i,
	output [3:0]				pci1_id_o,
	output [1:0]				pci1_op_o,
	output [1:0]				pci1_way_o,
	output [25:0]				pci1_address_o,
	output [511:0]				pci1_data_o,
	output [63:0]				pci1_mask_o,
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
	reg[511:0]					cache_data = 0;
	wire[511:0]					stbuf_data;
	wire[63:0]					stbuf_mask;
	reg[WAY_INDEX_WIDTH - 1:0]	tag_update_way = 0;
	reg[SET_INDEX_WIDTH - 1:0]	tag_update_set = 0;
	wire[1:0]					load_complete_way;
	wire[SET_INDEX_WIDTH - 1:0] load_complete_set;
	wire[TAG_WIDTH - 1:0]		load_complete_tag;
	wire[SET_INDEX_WIDTH - 1:0] store_complete_set;
	integer						i;
	reg[511:0]					data[0:NUM_SETS * NUM_WAYS - 1];
	reg							load_collision = 0;
	wire						tag_hit;
	wire[1:0]					tag_hit_way;
	wire						store_complete;

	wire[SET_INDEX_WIDTH - 1:0] requested_set = address_i[10:6];
	wire[TAG_WIDTH - 1:0] 		requested_tag = address_i[31:11];

	initial
	begin
		// synthesis translate_off
		for (i = 0; i < NUM_SETS * NUM_WAYS; i = i + 1)
			data[i] = 0;
		
		// synthesis translate_on
	end

	always @*
	begin
		if (invalidate_tag)
		begin
			// Beginning of load.  Invalidate line that will be loaded into.
			tag_update_way = victim_way;
			tag_update_set = request_set_latched;
		end
		else
		begin
			// End of load, store new tag and set valid
			tag_update_way = load_complete_way;
			tag_update_set = load_complete_set;
		end
	end

	wire invalidate_tag = read_cache_miss;
	
	cache_tag_mem tag(
		.clk(clk),
		.address_i(address_i),
		.access_i(access_i),
		.hit_way_o(tag_hit_way),
		.cache_hit_o(tag_hit),
		.update_i(|load_complete_o),		// If a load has completed, mark tag valid
		.invalidate_i(invalidate_tag),
		.update_way_i(tag_update_way),
		.update_tag_i(load_complete_tag),
		.update_set_i(tag_update_set));

	assign cache_hit_o = tag_hit || load_collision;
	always @*
	begin
		if (load_collision)
			hit_way = load_complete_way;
		else
			hit_way = tag_hit_way;
	end

	always @(posedge clk)
	begin
		access_latched			<= #1 access_i;
		request_set_latched		<= #1 requested_set;
		request_tag_latched		<= #1 requested_tag;
		strand_latched			<= #1 strand_i;
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
	
	wire update_mru = cache_hit_o || (access_latched && ~cache_hit_o 
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
				data[{ cpi_way_i, load_complete_set }] <= #1 cpi_data_i;
			else if (store_complete && cpi_allocate_i)
				data[{ cpi_way_i, store_complete_set }] <= #1 cpi_data_i;
		end

		cache_data <= #1 data[{ hit_way, request_set_latched }];
	end

	always @(posedge clk)
	begin
		if (write_i)
		begin
			$display("l1d cache write, address %x mask %x data %x",
				address_i, write_mask_i, data_i);
		end	
	end

	// A bit of a kludge to work around a race condition where a request
	// is made in the same cycle a load finishes of the same line.
	// It will not be in tag ram, but if a load is initiated, we'll
	// end up with the cache data in 2 ways.
//	always @(posedge clk)
//	begin
//		load_collision <= #1 load_complete_o 
//			&& load_complete_tag == requested_tag
//			&& load_complete_set == requested_set 
//			&& access_i;
//	end

	wire read_cache_miss = !cache_hit_o && access_latched && !write_i;
	
	store_buffer stbuf(
		.clk(clk),
		.store_complete_o(store_complete),
		.store_complete_set_o(store_complete_set),
		.tag_i(request_tag_latched),
		.set_i(request_set_latched),
		.data_i(data_i),
		.write_i(write_i && !stbuf_full_o),
		.mask_i(write_mask_i),
		.data_o(stbuf_data),
		.mask_o(stbuf_mask),
		.full_o(stbuf_full_o),
		.pci_valid_o(pci1_valid_o),
		.pci_ack_i(pci1_ack_i),
		.pci_id_o(pci1_id_o),
		.pci_op_o(pci1_op_o),
		.pci_way_o(pci1_way_o),
		.pci_address_o(pci1_address_o),
		.pci_data_o(pci1_data_o),
		.pci_mask_o(pci1_mask_o),
		.cpi_valid_i(cpi_valid_i),
		.cpi_id_i(cpi_id_i),
		.cpi_op_i(cpi_op_i),
		.cpi_allocate_i(cpi_allocate_i),
		.cpi_way_i(cpi_way_i),
		.cpi_data_i(cpi_data_i));

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

	mask_unit mu(
		.mask_i(stbuf_mask),
		.data0_i(stbuf_data),
		.data1_i(cache_data),
		.result_o(data_o));
endmodule
