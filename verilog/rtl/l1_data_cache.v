//
// Data Cache
//
// This is virtually indexed/virtually tagged and non-blocking.
// It is write-thru/no-write allocate.
// The cache is pipelined and has two cycles of latency overall. In the first 
// cycle, the line index is issued to tag ram.  Tag ram has one cycle of latency. 
// In the second cycle, the results from tag RAM are checked to see if any of the 
// ways have the data. A cache_hit signal will be returned.
// If there is a cache hit, the address will be issued to the cache data RAM.
// The cache data RAM has one cycle of latency
// For a memory write, the write data and address will be issued to a store 
// buffer in the second cycle.
// 
// 8k: 4 ways, 32 sets, 64 bytes per line
//     bits 0-5 (6) of address are the offset into the line
//     bits 6-10 (5) are the set index
//     bits 11-31 (21) are the tag
//

module l1_data_cache(
	input						clk,
	
	// To core
	input [31:0]				address_i,
	output reg[511:0]			data_o = 0,
	input [511:0]				data_i,
	input						write_i,
	input [1:0]					strand_i,
	input						access_i,
	input [63:0]				write_mask_i,
	output 						cache_hit_o,
	output						stbuf_full_o,
	output 						cache_load_complete_o,
	output						l2port0_read_o,
	input						l2port0_ack_i,
	output [25:0]				l2port0_addr_o,
	input [511:0]				l2port0_data_i,
	output						l2port1_write_o,
	input						l2port1_ack_i,
	output [25:0]				l2port1_addr_o,
	output [511:0]				l2port1_data_o,
	output [63:0]				l2port1_mask_o);
	
	parameter					TAG_WIDTH = 21;
	parameter					SET_INDEX_WIDTH = 5;
	parameter					WAY_INDEX_WIDTH = 2;
	parameter					NUM_SETS = 32;
	parameter					NUM_WAYS = 4;

	wire[1:0]					hit_way;
	reg[1:0]					new_mru_way = 0;
	reg[SET_INDEX_WIDTH + WAY_INDEX_WIDTH - 1:0] cache_data_addr = 0;
	wire[1:0]					victim_way;	// which way gets replaced
	reg							access_latched = 0;
	reg[SET_INDEX_WIDTH - 1:0]	request_set_latched = 0;
	reg[TAG_WIDTH - 1:0]		request_tag_latched = 0;
	wire[511:0]					cache_data;
	wire[511:0]					stbuf_data;
	wire[63:0]					stbuf_mask;
	reg [TAG_WIDTH - 1:0] 		load_tag = 0;
	reg [WAY_INDEX_WIDTH - 1:0] load_way = 0;
	reg [SET_INDEX_WIDTH - 1:0] load_set = 0;
	reg 						l2_load_pending = 0;
	wire 						l2_load_complete;
	reg[WAY_INDEX_WIDTH - 1:0] 	tag_update_way = 0;
	reg[SET_INDEX_WIDTH - 1:0] 	tag_update_set = 0;
	integer						i;

	wire[SET_INDEX_WIDTH - 1:0] requested_set = address_i[10:6];
	wire[TAG_WIDTH - 1:0] requested_tag = address_i[31:11];

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

	wire invalidate_tag = read_cache_miss && !l2_load_pending;
	
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
		cache_data_addr 		<= #1 { hit_way, request_set_latched };
		request_tag_latched		<= #1 requested_tag;
	end

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
	
	wire update_mru = cache_hit_o || (access_latched && ~cache_hit_o 
		&& !write_i);
	
	cache_lru #(SET_INDEX_WIDTH) lru(
		.clk(clk),
		.new_mru_way(new_mru_way),
		.set_i(requested_set),
		.update_mru(update_mru),
		.lru_way_o(victim_way));

	wire mem_port0_write = !stbuf_full_o && write_i && cache_hit_o;
    wire mem_port1_write = l2_load_pending && l2port0_ack_i;

	//
	// Data access stage
	//
	mem512 #(NUM_SETS * NUM_WAYS, 7) cache_mem(
		.clk(clk),

		// Port 0 is for reading or writing cache data
		.port0_addr_i({ hit_way, request_set_latched }),
		.port0_data_i(data_i),
		.port0_data_o(cache_data),
		.port0_write_i(mem_port0_write),
		.port0_byte_enable_i(write_mask_i),

		// Port 1 is for transfers from the L2 cache
		.port1_addr_i({ load_way, load_set }),
		.port1_data_i(l2port0_data_i),	// for L2 read
		.port1_data_o(),			// unused	
		.port1_write_i(mem_port1_write));

	store_buffer stbuf(
		.clk(clk),
		.addr_i({ request_tag_latched, request_set_latched }),
		.data_i(data_i),
		.write_i(write_i && !stbuf_full_o),
		.mask_i(write_mask_i),
		.data_o(stbuf_data),
		.mask_o(stbuf_mask),
		.full_o(stbuf_full_o),
		.l2_write_o(l2port1_write_o),
		.l2_ack_i(l2port1_ack_i),
		.l2_addr_o(l2port1_addr_o),
		.l2_data_o(l2port1_data_o),
		.l2_mask_o(l2port1_mask_o));

	always @*
	begin
		// Store buffer data could be a subset of the whole cache line.
		// As such, we need to look at the mask and mix individual byte
		// lanes.
		data_o = {
			stbuf_mask[63] ? stbuf_data[511:504] : cache_data[511:504],
			stbuf_mask[62] ? stbuf_data[503:496] : cache_data[503:496],
			stbuf_mask[61] ? stbuf_data[495:488] : cache_data[495:488],
			stbuf_mask[60] ? stbuf_data[487:480] : cache_data[487:480],
			stbuf_mask[59] ? stbuf_data[479:472] : cache_data[479:472],
			stbuf_mask[58] ? stbuf_data[471:464] : cache_data[471:464],
			stbuf_mask[57] ? stbuf_data[463:456] : cache_data[463:456],
			stbuf_mask[56] ? stbuf_data[455:448] : cache_data[455:448],
			stbuf_mask[55] ? stbuf_data[447:440] : cache_data[447:440],
			stbuf_mask[54] ? stbuf_data[439:432] : cache_data[439:432],
			stbuf_mask[53] ? stbuf_data[431:424] : cache_data[431:424],
			stbuf_mask[52] ? stbuf_data[423:416] : cache_data[423:416],
			stbuf_mask[51] ? stbuf_data[415:408] : cache_data[415:408],
			stbuf_mask[50] ? stbuf_data[407:400] : cache_data[407:400],
			stbuf_mask[49] ? stbuf_data[399:392] : cache_data[399:392],
			stbuf_mask[48] ? stbuf_data[391:384] : cache_data[391:384],
			stbuf_mask[47] ? stbuf_data[383:376] : cache_data[383:376],
			stbuf_mask[46] ? stbuf_data[375:368] : cache_data[375:368],
			stbuf_mask[45] ? stbuf_data[367:360] : cache_data[367:360],
			stbuf_mask[44] ? stbuf_data[359:352] : cache_data[359:352],
			stbuf_mask[43] ? stbuf_data[351:344] : cache_data[351:344],
			stbuf_mask[42] ? stbuf_data[343:336] : cache_data[343:336],
			stbuf_mask[41] ? stbuf_data[335:328] : cache_data[335:328],
			stbuf_mask[40] ? stbuf_data[327:320] : cache_data[327:320],
			stbuf_mask[39] ? stbuf_data[319:312] : cache_data[319:312],
			stbuf_mask[38] ? stbuf_data[311:304] : cache_data[311:304],
			stbuf_mask[37] ? stbuf_data[303:296] : cache_data[303:296],
			stbuf_mask[36] ? stbuf_data[295:288] : cache_data[295:288],
			stbuf_mask[35] ? stbuf_data[287:280] : cache_data[287:280],
			stbuf_mask[34] ? stbuf_data[279:272] : cache_data[279:272],
			stbuf_mask[33] ? stbuf_data[271:264] : cache_data[271:264],
			stbuf_mask[32] ? stbuf_data[263:256] : cache_data[263:256],
			stbuf_mask[31] ? stbuf_data[255:248] : cache_data[255:248],
			stbuf_mask[30] ? stbuf_data[247:240] : cache_data[247:240],
			stbuf_mask[29] ? stbuf_data[239:232] : cache_data[239:232],
			stbuf_mask[28] ? stbuf_data[231:224] : cache_data[231:224],
			stbuf_mask[27] ? stbuf_data[223:216] : cache_data[223:216],
			stbuf_mask[26] ? stbuf_data[215:208] : cache_data[215:208],
			stbuf_mask[25] ? stbuf_data[207:200] : cache_data[207:200],
			stbuf_mask[24] ? stbuf_data[199:192] : cache_data[199:192],
			stbuf_mask[23] ? stbuf_data[191:184] : cache_data[191:184],
			stbuf_mask[22] ? stbuf_data[183:176] : cache_data[183:176],
			stbuf_mask[21] ? stbuf_data[175:168] : cache_data[175:168],
			stbuf_mask[20] ? stbuf_data[167:160] : cache_data[167:160],
			stbuf_mask[19] ? stbuf_data[159:152] : cache_data[159:152],
			stbuf_mask[18] ? stbuf_data[151:144] : cache_data[151:144],
			stbuf_mask[17] ? stbuf_data[143:136] : cache_data[143:136],
			stbuf_mask[16] ? stbuf_data[135:128] : cache_data[135:128],
			stbuf_mask[15] ? stbuf_data[127:120] : cache_data[127:120],
			stbuf_mask[14] ? stbuf_data[119:112] : cache_data[119:112],
			stbuf_mask[13] ? stbuf_data[111:104] : cache_data[111:104],
			stbuf_mask[12] ? stbuf_data[103:96] : cache_data[103:96],
			stbuf_mask[11] ? stbuf_data[95:88] : cache_data[95:88],
			stbuf_mask[10] ? stbuf_data[87:80] : cache_data[87:80],
			stbuf_mask[9] ? stbuf_data[79:72] : cache_data[79:72],
			stbuf_mask[8] ? stbuf_data[71:64] : cache_data[71:64],
			stbuf_mask[7] ? stbuf_data[63:56] : cache_data[63:56],
			stbuf_mask[6] ? stbuf_data[55:48] : cache_data[55:48],
			stbuf_mask[5] ? stbuf_data[47:40] : cache_data[47:40],
			stbuf_mask[4] ? stbuf_data[39:32] : cache_data[39:32],
			stbuf_mask[3] ? stbuf_data[31:24] : cache_data[31:24],
			stbuf_mask[2] ? stbuf_data[23:16] : cache_data[23:16],
			stbuf_mask[1] ? stbuf_data[15:8] : cache_data[15:8],
			stbuf_mask[0] ? stbuf_data[7:0] : cache_data[7:0]
		};
	end

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

	assign l2port0_read_o = l2_load_pending;
	assign l2port0_addr_o = { load_tag, load_set };
	wire read_cache_miss = !cache_hit_o && access_latched && !write_i;
	assign l2_load_complete = l2_load_pending && l2port0_ack_i;

	// Either a store buffer operation has finished or cache line load 
	// complete
	assign cache_load_complete_o = l2_load_complete || l2port1_ack_i;
endmodule
