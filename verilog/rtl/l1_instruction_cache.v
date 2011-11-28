//
// Instruction Cache
//
// This is virtually indexed/virtually tagged and non-blocking.
// This has one cycle of latency.  During each cycle, tag memory and
// the four way memory banks are accessed in parallel.  Combinational
// logic them determines which bank the result should be pulled from.
// 
// 8k: 4 ways, 32 sets, 64 bytes per line
//     bits 0-5 (6) of address are the offset into the line
//     bits 6-10 (5) are the set index
//     bits 11-31 (21) are the tag
//

module l1_instruction_cache(
	input						clk,
	
	// To core
	input [31:0]				address_i,
	input						access_i,
	output reg[511:0]			data_o,
	output 						cache_hit_o,
	output 						cache_load_complete_o,
	output						l2_read_o,
	input						l2_ack_i,
	output [25:0]				l2_addr_o,
	input[511:0]				l2_data_i);
	
	parameter					TAG_WIDTH = 21;
	parameter					SET_INDEX_WIDTH = 5;
	parameter					WAY_INDEX_WIDTH = 2;
	parameter					NUM_SETS = 32;
	parameter					NUM_WAYS = 4;

	wire[SET_INDEX_WIDTH - 1:0]	requested_set;
	wire[TAG_WIDTH - 1:0]		requested_tag;

	wire[1:0]					hit_way;
	reg[1:0]					new_mru_way;
	wire[1:0]					victim_way;	// which way gets replaced
	reg							access_latched;
	reg[SET_INDEX_WIDTH - 1:0]	request_set_latched;
	reg[TAG_WIDTH - 1:0]		request_tag_latched;
	reg [TAG_WIDTH - 1:0] 		load_tag;
	reg [WAY_INDEX_WIDTH - 1:0] load_way;
	reg [SET_INDEX_WIDTH - 1:0] load_set;
	reg 						l2_load_pending;
	wire 						read_cache_miss;
	wire 						l2_load_complete;
	wire						invalidate_tag;
	reg[WAY_INDEX_WIDTH - 1:0] 	tag_update_way;
	reg[SET_INDEX_WIDTH - 1:0] 	tag_update_set;
	wire						update_mru;
	reg[511:0]					data_set0[0:NUM_SETS];
	reg[511:0]					data_set1[0:NUM_SETS];
	reg[511:0]					data_set2[0:NUM_SETS];
	reg[511:0]					data_set3[0:NUM_SETS];
	reg[511:0]					set0_value;
	reg[511:0]					set1_value;
	reg[511:0]					set2_value;
	reg[511:0]					set3_value;
	integer						i;

	initial
	begin
		data_o = 0;
		new_mru_way = 0;
		access_latched = 0;
		request_set_latched = 0;
		request_tag_latched = 0;
		load_tag = 0;
		load_way = 0;
		load_set = 0;
		l2_load_pending = 0;
		for (i = 0; i < NUM_SETS; i = i + 1)
		begin
			data_set0[i] = 0;
			data_set1[i] = 0;
			data_set2[i] = 0;
			data_set3[i] = 0;
		end
		
		set0_value = 0;
		set1_value = 0;
		set2_value = 0;
		set3_value = 0;
	end

	assign requested_set = address_i[10:6];
	assign requested_tag = address_i[31:11];
	
	assign invalidate_tag = read_cache_miss && !l2_load_pending;
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
			tag_update_way = load_way;
			tag_update_set = load_set;
		end
	end

	cache_tag_mem tag(
		.clk(clk),
		.address_i(address_i),
		.access_i(access_i),
		.hit_way_o(hit_way),
		.cache_hit_o(cache_hit_o),
		.update_i(l2_load_complete),
		.invalidate_i(invalidate_tag),
		.update_way_i(tag_update_way),
		.update_tag_i(load_tag),
		.update_set_i(tag_update_set));

	always @(posedge clk)
	begin
		access_latched 			<= #1 access_i;
		request_set_latched 	<= #1 requested_set;
		request_tag_latched		<= #1 requested_tag;
		set0_value				<= #1 data_set0[requested_set];
		set1_value				<= #1 data_set1[requested_set];
		set2_value				<= #1 data_set2[requested_set];
		set3_value				<= #1 data_set3[requested_set];
	end

	// We've fetched the value from all four ways in parallel.  Now
	// we know which way contains the data we care about, so select
	// that one.
	always @*
	begin
		case (hit_way)
			0: data_o = set0_value;
			1: data_o = set1_value;
			2: data_o = set2_value;
			3: data_o = set3_value;
		endcase
	end
	
	// FIXME: add a 16 way mux to select the appropriate instruction word

	// If there is a hit, move that way to the MRU.  If there is a miss,
	// move the victim way to the MRU position so it doesn't get evicted on 
	// the next data access.
	always @*
	begin
		if (cache_hit_o)
			new_mru_way = hit_way;
		else
			new_mru_way = victim_way;
	end

	assign update_mru = cache_hit_o || (access_latched && ~cache_hit_o);
	
	cache_lru #(SET_INDEX_WIDTH) lru(
		.clk(clk),
		.new_mru_way(new_mru_way),
		.set_i(requested_set),
		.update_mru(update_mru),
		.lru_way_o(victim_way));

	//
	// Cache miss handling logic.  Drives transferring data between
	// L1 and L2 cache.
	//
	always @(posedge clk)
	begin
		if (read_cache_miss)
		begin
			load_tag <= #1 request_tag_latched;	
			load_way <= #1 victim_way;	
			load_set <= #1 request_set_latched;
			l2_load_pending <= #1 1;
		end
		else if (l2_load_complete)
			l2_load_pending <= #1 0;		
	end

	assign l2_read_o = l2_load_pending;
	assign l2_addr_o = { load_tag, load_set };
	assign read_cache_miss = !cache_hit_o && access_latched;
	assign l2_load_complete = l2_load_pending && l2_ack_i;

	always @(posedge clk)
	begin
		if (l2_load_complete)
		begin
			// Store the retrieved values
			case (load_way)
				0:	data_set0[load_set] <= #1 l2_data_i;
				1:	data_set1[load_set] <= #1 l2_data_i;
				2:	data_set2[load_set] <= #1 l2_data_i;
				3:	data_set3[load_set] <= #1 l2_data_i;
			endcase
		end
	end

	// Either a store buffer operation has finished or cache line load 
	// complete
	assign cache_load_complete_o = l2_load_complete;
endmodule
