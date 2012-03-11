//
// L1 Instruction/Data Cache
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

module l1_cache
	#(parameter UNIT_ID = 0)
	(input						clk,
	
	// To core
	input [31:0]				address_i,
	output reg[511:0]			data_o = 0,
	input [1:0]					strand_i,
	input						access_i,
	input						synchronized_i,
	output						cache_hit_o,
	output [3:0]				load_complete_strands_o,
	input[SET_INDEX_WIDTH - 1:0] store_update_set_i,
	input						store_update_i,
	output						load_collision_o,
	
	// L2 interface
	output						pci_valid_o,
	input						pci_ack_i,
	output [1:0]				pci_unit_o,
	output [1:0]				pci_strand_o,
	output [2:0]				pci_op_o,
	output [1:0]				pci_way_o,
	output [25:0]				pci_address_o,
	output [511:0]				pci_data_o,
	output [63:0]				pci_mask_o,
	input 						cpi_valid_i,
	input [1:0]					cpi_unit_i,
	input [1:0]					cpi_strand_i,
	input [1:0]					cpi_op_i,
	input 						cpi_update_i,
	input [1:0]					cpi_way_i,
	input [511:0]				cpi_data_i);
	
	parameter					TAG_WIDTH = 21;
	parameter					SET_INDEX_WIDTH = 5;
	parameter					WAY_INDEX_WIDTH = 2;
	parameter					NUM_SETS = 32;
	parameter					NUM_WAYS = 4;

	reg[1:0]					new_mru_way = 0;
	wire[1:0]					lru_way;
	reg							access_latched = 0;
	reg							synchronized_latched = 0;
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
	reg							load_collision1 = 0;
	wire[1:0]					hit_way;
	wire 						data_in_cache;
	reg[3:0]					sync_load_wait = 0;
	reg[3:0]					sync_load_complete = 0;

	wire[SET_INDEX_WIDTH - 1:0] requested_set = address_i[10:6];
	wire[TAG_WIDTH - 1:0] 		requested_tag = address_i[31:11];

	cache_tag_mem tag(
		.clk(clk),
		.address_i(address_i),
		.access_i(access_i),
		.hit_way_o(hit_way),
		.cache_hit_o(data_in_cache),
		.update_i(|load_complete_strands_o),		// If a load has completed, mark tag valid
		.invalidate_i(0),	// XXX write invalidate will affect this.
		.update_way_i(load_complete_way),
		.update_tag_i(load_complete_tag),
		.update_set_i(load_complete_set));

	always @(posedge clk)
	begin
		access_latched 			<= #1 access_i;
		synchronized_latched	<= #1 synchronized_i;
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

	// If there is a hit, move that way to the MRU.	 If there is a miss,
	// move the victim way to the MRU position so it doesn't get evicted on 
	// the next data access.
	always @*
	begin
		if (data_in_cache)
			new_mru_way = hit_way;
		else
			new_mru_way = lru_way;
	end

	// Note that we only update the LRU if there is a cache hit or a
	// read miss (where we know we will be loading a new line).  If
	// there is a write miss, we just ignore it, because this is no-write-
	// allocate
	wire update_mru = data_in_cache || (access_latched && !data_in_cache);
	
	cache_lru #(SET_INDEX_WIDTH) lru(
		.clk(clk),
		.new_mru_way(new_mru_way),
		.set_i(requested_set),
		.update_mru(update_mru),
		.lru_way_o(lru_way));

	always @(posedge clk)
	begin
		if (cpi_valid_i)
		begin
			if (load_complete_strands_o)
			begin
				case (cpi_way_i)
					0:	way0_data[load_complete_set] <= #1 cpi_data_i;
					1:	way1_data[load_complete_set] <= #1 cpi_data_i;
					2:	way2_data[load_complete_set] <= #1 cpi_data_i;
					3:	way3_data[load_complete_set] <= #1 cpi_data_i;
				endcase
			end
			else if (store_update_i)
			begin
				case (cpi_way_i)
					0:	way0_data[store_update_set_i] <= #1 cpi_data_i;
					1:	way1_data[store_update_set_i] <= #1 cpi_data_i;
					2:	way2_data[store_update_set_i] <= #1 cpi_data_i;
					3:	way3_data[store_update_set_i] <= #1 cpi_data_i;
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
		load_collision1 <= #1 (load_complete_strands_o != 0
			&& load_complete_tag == requested_tag
			&& load_complete_set == requested_set 
			&& access_i);
	end

	wire load_collision2 = load_complete_strands_o
		&& load_complete_tag == request_tag_latched
		&& load_complete_set == request_set_latched
		&& access_latched;
	assign load_collision_o = load_collision1 || load_collision2;

	// Note that a synchronized load always queues a load from the L2 cache,
	// even if the data is in the cache.
	wire queue_cache_load = (need_sync_rollback || !data_in_cache) 
		&& access_latched && !load_collision_o;

	// If we do a synchronized load and this is a cache hit, re-load
	// data into the same way.
	wire[1:0] load_way = synchronized_latched && data_in_cache ? 
		hit_way : lru_way;

	wire[3:0] sync_req_mask = (access_i && synchronized_i) ? (1 << strand_i) : 0;
	wire[3:0] sync_ack_mask = (cpi_valid_i && cpi_unit_i == UNIT_ID) ? (1 << strand_i) : 0;
	reg need_sync_rollback = 0;

	always @(posedge clk)
	begin
		sync_load_wait <= #1 (sync_load_wait | (sync_req_mask & ~sync_load_complete)) & ~sync_ack_mask;
		sync_load_complete <= #1 (sync_load_complete | sync_ack_mask) & ~sync_req_mask;
		need_sync_rollback <= #1 (sync_req_mask & ~sync_load_complete) != 0;
	end

	// Synchronized accesses always take a cache miss on the first load
	assign cache_hit_o = data_in_cache && !need_sync_rollback;

	load_miss_queue lmq(
		.clk(clk),
		.request_i(queue_cache_load),
		.synchronized_i(synchronized_latched),
		.tag_i(request_tag_latched),
		.set_i(request_set_latched),
		.victim_way_i(load_way),
		.strand_i(strand_latched),
		.load_complete_strands_o(load_complete_strands_o),
		.load_complete_set_o(load_complete_set),
		.load_complete_tag_o(load_complete_tag),
		.load_complete_way_o(load_complete_way),
		.pci_valid_o(pci_valid_o),
		.pci_ack_i(pci_ack_i),
		.pci_unit_o(pci_unit_o),
		.pci_strand_o(pci_strand_o),
		.pci_op_o(pci_op_o),
		.pci_way_o(pci_way_o),
		.pci_address_o(pci_address_o),
		.pci_data_o(pci_data_o),
		.pci_mask_o(pci_mask_o),
		.cpi_valid_i(cpi_valid_i),
		.cpi_unit_i(cpi_unit_i),
		.cpi_strand_i(cpi_strand_i),
		.cpi_op_i(cpi_op_i),
		.cpi_update_i(cpi_update_i),
		.cpi_way_i(cpi_way_i),
		.cpi_data_i(cpi_data_i));
	defparam lmq.UNIT_ID = UNIT_ID;
endmodule
