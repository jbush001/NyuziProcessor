//
// Two-way arbiter (subcomponent of arbiter4)
//

module arbiter2(
	input 			lru,
	input[1:0]		request,
	output[1:0]		grant);

	assign grant = lru 
		? { request[1] && !request[0], request[0] }
		: { request[1], request[0] && !request[1] };
endmodule
