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
	input [31:0]				address_i,
	input						access_i,
	output [31:0]				data_o,
	output 						cache_hit_o,
	output 						cache_load_complete_o,
	output						pci_valid_o,
	input						pci_ack_i,
	output [3:0]				pci_id_o,
	output [1:0]				pci_op_o,
	output [1:0]				pci_way_o,
	output [25:0]				pci_address_o,
	output [511:0]				pci_data_o,
	output [63:0]				pci_mask_o,
	input 						cpi_valid_i,
	input [3:0]					cpi_id_i,
	input [1:0]					cpi_op_i,
	input [1:0]					cpi_way_i,
	input [511:0]				cpi_data_i);
	
	parameter					TAG_WIDTH = 21;
	parameter					SET_INDEX_WIDTH = 5;
	parameter					WAY_INDEX_WIDTH = 2;
	parameter					NUM_SETS = 32;
	parameter					NUM_WAYS = 4;

	parameter					STATE_IDLE = 0;
	parameter					STATE_WAIT_L2_ACK = 1;
	parameter					STATE_L2_ISSUED = 2;

	wire[1:0]					hit_way;
	reg[1:0]					new_mru_way = 0;
	wire[1:0]					victim_way;	// which way gets replaced
	reg							access_latched = 0;
	reg[SET_INDEX_WIDTH - 1:0]	request_set_latched = 0;
	reg[TAG_WIDTH - 1:0]		request_tag_latched = 0;
	reg[3:0]					request_lane_latched = 0;
	reg [TAG_WIDTH - 1:0] 		load_tag = 0;
	reg [SET_INDEX_WIDTH - 1:0] load_set = 0;
	reg [1:0]					load_way = 0;
	reg[511:0]					way0_data[0:NUM_SETS] /* synthesis syn_ramstyle = no_rw_check */;
	reg[511:0]					way1_data[0:NUM_SETS] /* synthesis syn_ramstyle = no_rw_check */;
	reg[511:0]					way2_data[0:NUM_SETS] /* synthesis syn_ramstyle = no_rw_check */;
	reg[511:0]					way3_data[0:NUM_SETS] /* synthesis syn_ramstyle = no_rw_check */;
	reg[511:0]					way0_read_data = 0;
	reg[511:0]					way1_read_data = 0;
	reg[511:0]					way2_read_data = 0;
	reg[511:0]					way3_read_data = 0;
	reg[511:0]					fetched_line = 0;
	reg							load_collision = 0;
	reg[1:0]					load_state_ff = STATE_IDLE;
	reg[1:0]					load_state_nxt = STATE_IDLE;
	integer						i;

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

	wire[TAG_WIDTH - 1:0] requested_tag = address_i[31:11];
	wire[SET_INDEX_WIDTH - 1:0] requested_set = address_i[10:6];
	wire[3:0] requested_lane = address_i[5:2];

	// A bit of a kludge to work around a race condition where a request
	// is made in the same cycle a load finishes of the same line.
	// It will not be in tag ram, but if a load is initiated, we'll
	// end up with the cache data in 2 ways.
	always @(posedge clk)
	begin
		load_collision <= #1 l2_load_complete 
			&& load_tag == requested_tag
			&& load_set == requested_set 
			&& access_i;
	end

	wire l2_load_complete = load_state_ff == STATE_L2_ISSUED && cpi_valid_i
		&& cpi_id_i[3:2] == 0 && cpi_op_i == 0;	// I am unit 0


	// XXX bug: cache_hit will be zero in the case of a load collision.
	// the instruction fetch unit will retry later, but it is a wasted cycle
	cache_tag_mem tag(
		.clk(clk),
		.address_i(address_i),
		.access_i(access_i),
		.hit_way_o(hit_way),
		.cache_hit_o(cache_hit_o),
		.update_i(l2_load_complete),
		.invalidate_i(0),		// XXX Invalidate command from cache will invalidate.
		.update_way_i(cpi_way_i),
		.update_tag_i(load_tag),
		.update_set_i(load_set));

	always @(posedge clk)
	begin
		access_latched 			<= #1 access_i;
		request_set_latched 	<= #1 requested_set;
		request_tag_latched		<= #1 requested_tag;
		request_lane_latched	<= #1 requested_lane;
		way0_read_data			<= #1 way0_data[requested_set];
		way1_read_data			<= #1 way1_data[requested_set];
		way2_read_data			<= #1 way2_data[requested_set];
		way3_read_data			<= #1 way3_data[requested_set];
	end

	// We've fetched the value from all four ways in parallel.  Now
	// we know which way contains the data we care about, so select
	// that one.
	always @*
	begin
		case (hit_way)
			0: fetched_line = way0_read_data;
			1: fetched_line = way1_read_data;
			2: fetched_line = way2_read_data;
			3: fetched_line = way3_read_data;
		endcase
	end
	
	lane_select_mux lsm(
		.value_i(fetched_line),
		.lane_select_i(request_lane_latched),
		.value_o(data_o));

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

	// Note that we only update the LRU if there is a cache hit or a
	// read miss (where we know we will be loading a new line).
	wire update_mru = cache_hit_o || (access_latched && !cache_hit_o);
	
	cache_lru #(SET_INDEX_WIDTH) lru(
		.clk(clk),
		.new_mru_way(new_mru_way),
		.set_i(requested_set),
		.update_mru(update_mru),
		.lru_way_o(victim_way));

	//
	// Latch which line we need to request from L2
	//
	always @(posedge clk)
	begin
		if (read_cache_miss)
		begin
			load_tag <= #1 request_tag_latched;	
			load_set <= #1 request_set_latched;
			load_way <= #1 victim_way;
		end
	end

	assign pci_way_o = load_way;
	assign pci_address_o = { load_tag, load_set };
	wire read_cache_miss = !cache_hit_o && access_latched 
		&& load_state_ff == STATE_IDLE && !load_collision;
	assign pci_valid_o = load_state_ff == STATE_WAIT_L2_ACK;
	assign pci_id_o = 0;
	assign pci_op_o = 0;	// load
	assign pci_mask_o = 0;
	assign pci_data_o = 0;

	always @*
	begin
		load_state_nxt = load_state_ff;
	
		case (load_state_ff)
			STATE_IDLE:
			begin
				if (read_cache_miss)
					load_state_nxt = STATE_WAIT_L2_ACK;
			end
			
			STATE_WAIT_L2_ACK:
			begin
				if (pci_ack_i)
					load_state_nxt = STATE_L2_ISSUED;
			end

			STATE_L2_ISSUED:
			begin
				if (l2_load_complete)
					load_state_nxt = STATE_IDLE;
			end
		endcase
	end

	always @(posedge clk)
	begin
		if (l2_load_complete)
		begin
			// Store the retrieved values
			case (cpi_way_i)
				0:	way0_data[load_set] <= #1 cpi_data_i;
				1:	way1_data[load_set] <= #1 cpi_data_i;
				2:	way2_data[load_set] <= #1 cpi_data_i;
				3:	way3_data[load_set] <= #1 cpi_data_i;
			endcase
		end
		
		load_state_ff <= #1 load_state_nxt;
	end

	assign cache_load_complete_o = l2_load_complete;
endmodule
