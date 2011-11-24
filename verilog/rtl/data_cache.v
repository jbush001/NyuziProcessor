//
// Data Cache
//
// This is virtually indexed/virtually tagged, write-back, and non-blocking.
// 
// 8k: 4 ways, 32 sets, 64 bytes per line
//     bits 0-5 (6) of address are the offset into the line
//     bits 6-10 (5) are the set index
//     bits 11-31 (21) are the tag
//

module data_cache(
	input						clk,
	
	// To core
	input [31:0]				address_i,
	output [511:0]				data_o,
	input[511:0]				data_i,
	input						write_i,
	input						access_i,
	input[63:0]					write_mask_i,
	output 						cache_hit_o,
	output reg					cache_load_complete_o,

	// To L2 Cache
	output						l2_write_o,
	output						l2_read_o,
	input						l2_ack_i,
	output reg[31:0]			l2_addr_o,
	input[511:0]				l2_data_i,
	output[511:0]				l2_data_o);
	
	parameter					TAG_WIDTH = 21;
	parameter					SET_INDEX_WIDTH = 5;
	parameter					WAY_INDEX_WIDTH = 2;
	parameter					NUM_SETS = 32;
	parameter					NUM_WAYS = 4;

	wire[SET_INDEX_WIDTH - 1:0]	requested_set_index;
	wire[TAG_WIDTH - 1:0]		requested_tag;

	reg[TAG_WIDTH - 1:0]		tag_mem0[0:NUM_SETS - 1];
	reg							valid_mem0[0:NUM_SETS - 1];
	reg[TAG_WIDTH - 1:0]		tag_mem1[0:NUM_SETS - 1];
	reg							valid_mem1[0:NUM_SETS - 1];
	reg[TAG_WIDTH - 1:0]		tag_mem2[0:NUM_SETS - 1];
	reg							valid_mem2[0:NUM_SETS - 1];
	reg[TAG_WIDTH - 1:0]		tag_mem3[0:NUM_SETS - 1];
	reg							valid_mem3[0:NUM_SETS - 1];
	reg[TAG_WIDTH - 1:0]		tag0;
	reg[TAG_WIDTH - 1:0]		tag1;
	reg[TAG_WIDTH - 1:0]		tag2;
	reg[TAG_WIDTH - 1:0]		tag3;
	reg							valid0;
	reg							valid1;
	reg							valid2;
	reg							valid3;
	reg							hit0;
	reg							hit1;
	reg							hit2;
	reg							hit3;
	reg							dirty[0:NUM_SETS * NUM_WAYS - 1];
	reg[1:0]					hit_way;
	reg[1:0]					new_mru_way;
	reg[SET_INDEX_WIDTH + WAY_INDEX_WIDTH - 1:0]	cache_data_addr;
	reg[2:0]					lru[0:NUM_SETS - 1];
	reg[2:0]					old_lru_bits;
	wire[2:0]					new_lru_bits;
	wire[1:0]					victim_way;	// which way gets replaced

	reg							access_latched;
	reg[SET_INDEX_WIDTH - 1:0]	set_index_latched;
	reg[TAG_WIDTH - 1:0]		request_tag_latched;
	reg[TAG_WIDTH - 1:0]		victim_tag_latched;

	wire[TAG_WIDTH - 1:0]		l2_request_tag;
	wire[SET_INDEX_WIDTH - 1:0]	l2_set_index;
	wire[1:0]					l2_way;
	wire[TAG_WIDTH - 1:0]		l2_victim_tag;

	// Cache miss FIFO
	wire						request_fifo_empty;
	wire						head_is_dirty;
	
	// L2 access state machine
	parameter					STATE_IDLE = 0;
	parameter					STATE_L2_READ = 1;
	parameter					STATE_L2_WRITE = 2;
	
	reg[1:0]					state_ff;
	reg[1:0]					state_nxt;
	reg							valid_nxt;
	integer						i;
	wire                        mem_port0_write;
	wire                        mem_port1_write;

	initial
	begin
		for (i = 0; i < NUM_SETS; i = i + 1)
		begin
			tag_mem0[i] = 0;
			tag_mem1[i] = 0;
			tag_mem2[i] = 0;
			tag_mem3[i] = 0;
			valid_mem0[i] = 0;
			valid_mem1[i] = 0;
			valid_mem2[i] = 0;
			valid_mem3[i] = 0;
		end	
		
		for (i = 0; i < NUM_SETS * NUM_WAYS; i = i + 1)
			dirty[i] = 0;
			
		for (i = 0; i < NUM_SETS; i = i + 1)
			lru[i] = 0;
		
		l2_addr_o = 0;
		tag0 = 0;
		tag1 = 0;
		tag2 = 0;
		tag3 = 0;
		valid0 = 0;
		valid1 = 0;
		valid2 = 0;
		valid3 = 0;
		hit0 = 0;
		hit1 = 0;
		hit2 = 0;
		hit3 = 0;
		hit_way = 0;
		new_mru_way = 0;
		cache_data_addr = 0;
		old_lru_bits = 0;
		access_latched = 0;
		set_index_latched = 0;
		request_tag_latched = 0;
		victim_tag_latched = 0;
		state_ff = 0;
		state_nxt = 0;
		valid_nxt = 0;
		cache_load_complete_o = 0;
	end
	
	//
	// Tag check 
	//
	
	assign requested_set_index = address_i[10:6];
	assign requested_tag = address_i[31:11];

	always @(posedge clk)
	begin
		tag0 		<= #1 tag_mem0[requested_set_index];
		valid0 		<= #1 valid_mem0[requested_set_index];
		tag1 		<= #1 tag_mem1[requested_set_index];
		valid1 		<= #1 valid_mem1[requested_set_index];
		tag2 		<= #1 tag_mem2[requested_set_index];
		valid2 		<= #1 valid_mem2[requested_set_index];
		tag3 		<= #1 tag_mem3[requested_set_index];
		valid3 		<= #1 valid_mem3[requested_set_index];
	end

	always @(posedge clk)
	begin
		access_latched 			<= #1 access_i;
		set_index_latched 		<= #1 requested_set_index;
		cache_data_addr 		<= #1 { hit_way, set_index_latched };
		request_tag_latched		<= #1 requested_tag;
	end

	always @*
	begin
		hit0 = tag0 == request_tag_latched && valid0;
		hit1 = tag1 == request_tag_latched && valid1;
		hit2 = tag2 == request_tag_latched && valid2;
		hit3 = tag3 == request_tag_latched && valid3;
	end

	assign cache_hit_o = (hit0 || hit1 || hit2 || hit3) && access_latched;

	// synthesis translate_off
	always @(posedge clk)
	begin
		if (hit0 + hit1 + hit2 + hit3 > 1)
		begin
			$display("Error: more than one way was a hit");
			$finish;
		end
	end
	// synthesis translate_on

	always @*
	begin
		if (hit0)
			hit_way = 0;
		else if (hit1)
			hit_way = 1;
		else if (hit2)
			hit_way = 2;
		else
			hit_way = 3;
	end

	// 
	// LRU Update
	//
	
	// If there is a hit, move that way to the beginning.  If there is a miss,
	// move the victim way to the LRU position so it doesn't get evicted on 
	// the next data access.
	always @*
	begin
		if (cache_hit_o)
			new_mru_way = hit_way;
		else
			new_mru_way = victim_way;
	end

	pseudo_lru l(
		.lru_bits_i(old_lru_bits),
		.lru_index_o(victim_way),
		.new_mru_index_i(new_mru_way),	
		.lru_bits_o(new_lru_bits));

	always @(posedge clk)
	begin
		old_lru_bits <= #1 lru[requested_set_index];
		if (access_latched)
			lru[set_index_latched] <= #1 new_lru_bits;
	end

	always @(posedge clk)
	begin
		case (victim_way)
			0: victim_tag_latched <= #1 tag0;
			1: victim_tag_latched <= #1 tag1;
			2: victim_tag_latched <= #1 tag2;
			3: victim_tag_latched <= #1 tag3;
		endcase	
	end

	assign mem_port0_write = write_i && cache_hit_o;
    assign mem_port1_write = state_ff == STATE_L2_READ && l2_ack_i;

	//
	// Data access stage
	//
	mem512 #(NUM_SETS * NUM_WAYS, 7) cache_mem(
		.clk(clk),
		.port0_addr_i({ hit_way, set_index_latched}),
		.port0_data_i(data_i),
		.port0_data_o(data_o),
		.port0_write_i(mem_port0_write),
		.port0_byte_enable_i(write_mask_i),
		.port1_addr_i({ l2_way, l2_set_index }),
		.port1_data_i(l2_data_i),	// for L2 read
		.port1_data_o(l2_data_o),	// for L2 writeback
		.port1_write_i(mem_port1_write));
		
	always @(posedge clk)
	begin
		if (access_latched)
		begin
			if (cache_hit_o && write_i)
				dirty[cache_data_addr] <= #1 1'b1;
		end

		if (state_ff == STATE_L2_WRITE)
			dirty[{ l2_way, l2_set_index }] <= #1 1'b0;
	end
	
	//
	// Cache miss handling logic.  Drives transferring data between
	// L1 and L2 cache.
	// This is broken right now because it does not check if duplicate
	// cache loads are queued.  Because the way is allocated when the
	// item is queued, this will result in the same data being loaded
	// into multiple ways, which will have all kinds of undefined behaviors.
	//
	sync_fifo #(TAG_WIDTH + TAG_WIDTH + WAY_INDEX_WIDTH + SET_INDEX_WIDTH) request_fifo(
		.clk(clk),
		.full_o(),
		.enqueue_i(!cache_hit_o && access_latched),
		.value_i({ victim_tag_latched, request_tag_latched, victim_way, set_index_latched}),
		.empty_o(request_fifo_empty),
		.dequeue_i(state_ff != STATE_IDLE && state_nxt == STATE_IDLE),
		.value_o({ l2_victim_tag, l2_request_tag, l2_way, l2_set_index }));

	assign head_is_dirty = dirty[{ l2_way, l2_set_index }];

	// Cache state next
	always @*
	begin
		case (state_ff)
			STATE_IDLE:
			begin
				if (!request_fifo_empty)
				begin
					if (head_is_dirty)
						state_nxt = STATE_L2_WRITE;
					else
						state_nxt = STATE_L2_READ;
				end
				else
					state_nxt = STATE_IDLE;
			end
			
			STATE_L2_WRITE:
			begin
				if (l2_ack_i)
					state_nxt = STATE_L2_READ;
				else
					state_nxt = STATE_L2_WRITE;
			end

			STATE_L2_READ:
			begin
				if (l2_ack_i)
					state_nxt = STATE_IDLE;
				else
					state_nxt = STATE_L2_READ;
			end
		endcase
	end
	
	assign l2_write_o = state_nxt == STATE_L2_WRITE;
	assign l2_read_o = state_nxt == STATE_L2_READ;
	
	// l2_addr_o
	always @*
	begin
		if (state_nxt == STATE_L2_WRITE)
			l2_addr_o = { l2_victim_tag, l2_set_index, 6'd0  };
		else // STATE_L2_READ or don't care
			l2_addr_o = { l2_request_tag, l2_set_index, 6'd0 };
	end
	
	// Update valid bits
	always @(posedge clk)
	begin
		if (state_ff != STATE_IDLE && state_nxt == STATE_IDLE)
		begin
			// When we finish loading a line, we mark it as valid and
			// update tag RAM
			case (l2_way)
				0:
				begin
					valid_mem0[l2_set_index] <= #1 1;
					tag_mem0[l2_set_index] <= #1 l2_request_tag;
				end
				
				1: 
				begin
					valid_mem1[l2_set_index] <= #1 1; 
					tag_mem1[l2_set_index] <= #1 l2_request_tag;
				end
				
				2:
				begin
					valid_mem2[l2_set_index] <= #1 1;
					tag_mem2[l2_set_index] <= #1 l2_request_tag;
				end

				3:
				begin
					valid_mem3[l2_set_index] <= #1 1;
					tag_mem3[l2_set_index] <= #1 l2_request_tag;
				end
			endcase
		end
		else if (state_ff == STATE_IDLE && state_nxt != STATE_IDLE)
		begin
			// When we begin loading a line, we mark it is non-valid
			// Note that there is a potential race condition, because
			// the top level could have read the valid bit in the same cycle.
			// However, because we take more than a cycle to reload the line,
			// we know they'll finish before we change the value.  By marking
			// this as non-valid, we prevent any future races.
			case (l2_way)
				0: valid_mem0[l2_set_index] <= #1 0;
				1: valid_mem1[l2_set_index] <= #1 0; 
				2: valid_mem2[l2_set_index] <= #1 0;
				3: valid_mem3[l2_set_index] <= #1 0;
			endcase
		end
	end
	
	always @(posedge clk)
	begin
		if (state_ff == STATE_L2_READ && l2_ack_i)
			cache_load_complete_o <= #1 1;
		else
			cache_load_complete_o <= #1 0;
	
	end
	
	always @(posedge clk)
		state_ff <= #1 state_nxt;
	
endmodule
