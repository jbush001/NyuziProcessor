`include "timescale.v"

module strand_select_stage(
	input					clk,
	input [31:0] 			instruction_i,
	output reg[31:0]		instruction_o,
	input [31:0]			pc_i,
	output reg[31:0]		pc_o,
	output reg[3:0]			lane_select_o,
	input					flush_i,
	output                  stall_o);

    reg                     vec_mem_transfer_active_ff;
    reg                     vec_mem_transfer_active_nxt;
    reg[3:0]                lane_select_nxt;
    assign                  stall_o = vec_mem_transfer_active_nxt;

	initial
	begin
		instruction_o = 0;
		lane_select_o = 0;
		pc_o = 0;
		vec_mem_transfer_active_ff = 0;
		vec_mem_transfer_active_nxt = 0;
		lane_select_nxt = 0;
	end

    // In order to handle vector memory transfers, we need to synthesize
    // instructions for each lane here with the additional lane_select_o field
    // set appropriately.
    always @*
    begin
        if (vec_mem_transfer_active_ff)
        begin
            lane_select_nxt = lane_select_o + 1;
            if (lane_select_nxt == 4'b1111)
                vec_mem_transfer_active_nxt = 0;
        end
        else
        begin
            if (instruction_i[31:30] == 2'b10 && instruction_i[28:25] >= 4'b0110)
                vec_mem_transfer_active_nxt = 1;
            else
                vec_mem_transfer_active_nxt = 0;
                
            lane_select_nxt = 0;
        end
    end

	always @(posedge clk)
	begin
		if (flush_i)
		begin
			instruction_o 		        <= #1 0;	// NOP
			pc_o				        <= #1 0;
			vec_mem_transfer_active_ff  <= #1 0;
			lane_select_o               <= #1 0;
		end
		else
		begin
			instruction_o 	        	<= #1 instruction_i;
			pc_o			        	<= #1 pc_i;
			vec_mem_transfer_active_ff  <= #1 vec_mem_transfer_active_nxt;
			lane_select_o               <= #1 lane_select_nxt;
		end
	end
	
endmodule
