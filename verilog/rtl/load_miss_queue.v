module load_miss_queue
	#(parameter						TAG_WIDTH = 21,
	parameter						SET_INDEX_WIDTH = 5,
	parameter						WAY_INDEX_WIDTH = 2)

	(input							clk,
	input							request_i,
	input [TAG_WIDTH - 1:0]			tag_i,
	input [SET_INDEX_WIDTH - 1:0]	set_i,
	input [1:0]						victim_way_i,
	input [1:0]						strand_i,
	output [3:0]					cache_load_complete_o,
	output [1:0]					load_complete_way_o,
	output [SET_INDEX_WIDTH - 1:0]	load_complete_set_o,
	output [TAG_WIDTH - 1:0]		load_complete_tag_o,
	output							l2_read_o,
	input							l2_ack_i,
	output [25:0]					l2_addr_o,
	input [511:0]					l2_data_i);

	reg [TAG_WIDTH - 1:0] 			load_tag = 0;
	reg [WAY_INDEX_WIDTH - 1:0] 	load_way = 0;
	reg [SET_INDEX_WIDTH - 1:0]		load_set = 0;
	reg 							l2_load_pending = 0;

	wire l2_load_complete = l2_load_pending && l2_ack_i;

	always @(posedge clk)
	begin
		if (request_i)
		begin
			load_tag <= #1 tag_i;	
			load_way <= #1 victim_way_i;	
			load_set <= #1 set_i;
			l2_load_pending <= #1 1;
		end
		else if (l2_load_complete)
			l2_load_pending <= #1 0;		
	end

	assign l2_read_o = l2_load_pending;
	assign l2_addr_o = { load_tag, load_set };
	assign load_complete_tag_o = load_tag;
	assign load_complete_set_o = load_set;
	assign load_complete_way_o = load_way;

	assign cache_load_complete_o = {4{l2_load_complete}};
endmodule
