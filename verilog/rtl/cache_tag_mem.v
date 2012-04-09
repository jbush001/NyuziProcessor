//
// Cache tag memory. This assumes 4 ways, but has a parameterizable number 
// of sets.  This stores both a valid bit for each cache line and the tag
// (the upper bits of the virtual address).  It handles checking for a cache
// hit and updating the tags when data is laoded from memory.
// Since there are four ways, there are also four separate tag RAM blocks, which 
// the address is issued to in parallel. 
//

module cache_tag_mem
	#(parameter						TAG_WIDTH = 21,
	parameter						SET_INDEX_WIDTH = 5,
	parameter						NUM_SETS = 32)

	(input 							clk,
	input[31:0]						address_i,
	input							access_i,
	output reg[1:0]					hit_way_o = 0,
	output							cache_hit_o,
	input							update_i,
	input							invalidate_i,
	input[1:0]						update_way_i,
	input[TAG_WIDTH - 1:0]			update_tag_i,
	input[SET_INDEX_WIDTH - 1:0]	update_set_i);

	localparam					NUM_WAYS = 4;
	localparam					WAY_INDEX_WIDTH = 2;

	reg[TAG_WIDTH - 1:0]		tag_mem0[0:NUM_SETS - 1];
	reg							valid_mem0[0:NUM_SETS - 1];
	reg[TAG_WIDTH - 1:0]		tag_mem1[0:NUM_SETS - 1];
	reg							valid_mem1[0:NUM_SETS - 1];
	reg[TAG_WIDTH - 1:0]		tag_mem2[0:NUM_SETS - 1];
	reg							valid_mem2[0:NUM_SETS - 1];
	reg[TAG_WIDTH - 1:0]		tag_mem3[0:NUM_SETS - 1];
	reg							valid_mem3[0:NUM_SETS - 1];
	reg[TAG_WIDTH - 1:0]		tag0 = 0;
	reg[TAG_WIDTH - 1:0]		tag1 = 0;
	reg[TAG_WIDTH - 1:0]		tag2 = 0;
	reg[TAG_WIDTH - 1:0]		tag3 = 0;
	reg							valid0 = 0;
	reg							valid1 = 0;
	reg							valid2 = 0;
	reg							valid3 = 0;
	reg							access_latched = 0;
	reg[TAG_WIDTH - 1:0]		request_tag_latched = 0;
	integer						i;

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
	end

	wire[SET_INDEX_WIDTH - 1:0]	requested_set_index = address_i[10:6];
	wire[TAG_WIDTH - 1:0] requested_tag = address_i[31:11];

	always @(posedge clk)
	begin
		tag0 				<= #1 tag_mem0[requested_set_index];
		valid0 				<= #1 valid_mem0[requested_set_index];
		tag1 				<= #1 tag_mem1[requested_set_index];
		valid1 				<= #1 valid_mem1[requested_set_index];
		tag2 				<= #1 tag_mem2[requested_set_index];
		valid2 				<= #1 valid_mem2[requested_set_index];
		tag3 				<= #1 tag_mem3[requested_set_index];
		valid3 				<= #1 valid_mem3[requested_set_index];
		access_latched 		<= #1 access_i;
		request_tag_latched	<= #1 requested_tag;
	end

	wire hit0 = tag0 == request_tag_latched && valid0;
	wire hit1 = tag1 == request_tag_latched && valid1;
	wire hit2 = tag2 == request_tag_latched && valid2;
	wire hit3 = tag3 == request_tag_latched && valid3;

	always @*
	begin
		if (hit0)
			hit_way_o = 0;
		else if (hit1)
			hit_way_o = 1;
		else if (hit2)
			hit_way_o = 2;
		else
			hit_way_o = 3;
	end

	assign cache_hit_o = (hit0 || hit1 || hit2 || hit3) && access_latched;

	always @(posedge clk)
	begin
		if (update_i)
		begin
			// When we finish loading a line, we mark it as valid and
			// update tag RAM
			case (update_way_i)
				0:
				begin
					valid_mem0[update_set_i] <= #1 1;
					tag_mem0[update_set_i] <= #1 update_tag_i;
				end
				
				1: 
				begin
					valid_mem1[update_set_i] <= #1 1; 
					tag_mem1[update_set_i] <= #1 update_tag_i;
				end
				
				2:
				begin
					valid_mem2[update_set_i] <= #1 1;
					tag_mem2[update_set_i] <= #1 update_tag_i;
				end

				3:
				begin
					valid_mem3[update_set_i] <= #1 1;
					tag_mem3[update_set_i] <= #1 update_tag_i;
				end
			endcase
		end
		else if (invalidate_i)
		begin
			case (update_way_i)
				0: valid_mem0[update_set_i] <= #1 0;
				1: valid_mem1[update_set_i] <= #1 0; 
				2: valid_mem2[update_set_i] <= #1 0;
				3: valid_mem3[update_set_i] <= #1 0;
			endcase
		end
	end

	assertion #("more than one way was a hit") a(.clk(clk), 
		.test(hit0 + hit1 + hit2 + hit3 > 1));
endmodule
