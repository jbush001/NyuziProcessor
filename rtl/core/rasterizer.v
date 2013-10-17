



/*
    For a patch-aligned row, calculate bit mask for pixels that fall 
    between edges of trapezoid.
    Most coordinates in 16.16 fixed point
*/

module compute_patch_mask(
    input signed [31:0] x1,        // left trapezoid edge
    input signed [31:0] x2,        // right trapezoid edge
    input signed [15:0] patch_x,   // screen-aligned 4x4 patch coordinage
    output [0:3] mask);

wire signed [31:0] bm0 = {patch_x[15:2], 2'd0, 16'b0};
wire signed [31:0] bm1 = {patch_x[15:2], 2'd1, 16'b0};
wire signed [31:0] bm2 = {patch_x[15:2], 2'd2, 16'b0};
wire signed [31:0] bm3 = {patch_x[15:2], 2'd3, 16'b0};

assign mask[0] = bm0>=x1 && bm0<x2;
assign mask[1] = bm1>=x1 && bm1<x2;
assign mask[2] = bm2>=x1 && bm2<x2;
assign mask[3] = bm3>=x1 && bm3<x2;

endmodule


module row_rasterizer(
    input clk,
    input reset,
    
    input load,
    input [31:0] x1_in,
    input [31:0] x2_in,
    input advance_x,
    input advance_y,
    input signed [31:0] dx1,   // left edge horizontal step for one step in y
    input signed [31:0] dx2,   // right edge horizontal step for one step in y

    output reg signed [15:0] patch_x,
    output [0:3] mask,
    output done);

reg signed [31:0] x1, x2;

wire signed [31:0] next_x1, next_x2;
assign next_x1 = x1 + dx1;
assign next_x2 = x2 + dx2;

always @(posedge clk, posedge reset) begin
    if (reset) begin
        {x1, x2, patch_x} <= 0;
    end else begin
        if (load) begin
            x1 <= x1_in;
            x2 <= x2_in;
            patch_x <= {x1_in[31:18], 2'b0};
        end else if (advance_y) begin
            x1 <= next_x1;
            x2 <= next_x2;
            patch_x <= {next_x1[31:18], 2'b0};
        end else if (advance_x) begin
            patch_x <= patch_x + 4;
        end
    end
end

wire signed [31:0] extended_patch_x = {patch_x, 16'b0};
assign done = extended_patch_x >= x2;

compute_patch_mask cpm(
    .x1(x1),
    .x2(x2),
    .patch_x(patch_x),
    .mask(mask));

endmodule



// Write address space:
// 0 -- x1
// 1 -- x2
// 2 -- dx1
// 3 -- dx2
// 4 -- y
// 5 -- height
// 6 -- action (1=advance)

// Read address space
// 0 -- status (0=idle, 1=??, 2=busy, 3=valid)
// 1 -- mask
// 2 -- patch_x
// 3 -- patch_y

module rasterizer
	#(parameter BASE_ADDRESS = 0)
	
	(input clk, 
    input reset,
    
    input [31:0] io_address,
    input [31:0] io_write_data,
    output reg [31:0] io_read_data,
    input io_write_en);  
    

// I/O interface and registers
reg signed [31:0] dx1, dx2, x1, x2;
reg signed [15:0] patch_y;
reg signed [15:0] y, h;
reg signed [15:0] clip_left, clip_right;
reg recalc, advance, enable;
reg [2:0] recalc_addr;

wire [0:15] mask;
wire signed [15:0] patch_x;
reg [15:0] n_rows;
wire [0:3] done;
wire all_done = &done;
wire busy = n_rows != 0;
wire valid;
wire signed [15:0] row_patch_x [0:3];
wire [0:3] row_masks [0:3];

wire[4:0] io_reg_index = (io_address - BASE_ADDRESS) >> 2;

always @(posedge clk, posedge reset) begin
    if (reset) begin
        {x1, x2, dx1, dx2, y, h, recalc, advance, enable, clip_left, clip_right} <= 0;
    end else begin
        recalc <= 0;
        advance <= 0;
        if (io_write_en) begin
            case (io_reg_index)
            	0: x1 <= io_write_data;
            	1: x2 <= io_write_data;
            	2: dx1 <= io_write_data;
            	3: dx2 <= io_write_data;
            	4: y <= io_write_data;
            	5: h <= io_write_data;
            	6: advance <= io_write_data[0];
				7: enable <= io_write_data[0];
				8: clip_left <= io_write_data;
				9: clip_right <= io_write_data;
            endcase
            recalc_addr <= io_reg_index;
            if (io_reg_index<6) recalc <= 1;
        end
    end
end

always @(busy, valid, mask, patch_x, patch_y, mask,
        row_patch_x[0], row_patch_x[2], row_patch_x[2], row_patch_x[3],
        row_masks[0], row_masks[1], row_masks[2], row_masks[3], done, io_reg_index) begin
    io_read_data = 0;
    case (io_reg_index)
        0: io_read_data = {busy, valid};
        1: io_read_data = mask;
        2: io_read_data = patch_x;
        3: io_read_data = patch_y;
        4: io_read_data = {row_patch_x[0], row_patch_x[1]};
        5: io_read_data = {row_patch_x[2], row_patch_x[3]};
        6: io_read_data = {row_masks[0], row_masks[1], row_masks[2], row_masks[3]};
        7: io_read_data = done;
    endcase
end


wire [0:3] row_advance_x, row_advance_y;
wire signed [15:0] top_y, bot_y;

// Top and bottom scanlines of trapezoid
assign top_y = y;
assign bot_y = y + h - 1;

// Setup logic
always @(posedge clk or posedge reset) begin
    if (reset) begin
        {patch_y, n_rows} <= 0;
    end else begin
        if (recalc) begin
            // Top of patch and number of rows of patches
            patch_y <= {top_y[15:2], 2'b0};
            n_rows <= bot_y[15:2] - top_y[15:2] + 1;            
        end else if (row_advance_y[0]) begin
            n_rows <= n_rows - 1;
            patch_y <= patch_y + 4;
        end
    end
end


// Adjust x1, x2 to top of patch_y
// y correction factor is equal to -y_in[1:0];
wire signed [31:0] x1_corrected, x2_corrected;
assign x1_corrected = x1 - y[1:0] * dx1;
assign x2_corrected = x2 - y[1:0] * dx2;

wire signed [31:0] x1_stepped [0:3];
wire signed [31:0] x2_stepped [0:3];

assign x1_stepped[0] = x1_corrected;
assign x1_stepped[1] = x1_corrected + dx1;
assign x1_stepped[2] = x1_corrected + dx1 + dx1;
assign x1_stepped[3] = x1_corrected + dx1 + dx1 + dx1;
assign x2_stepped[0] = x2_corrected;
assign x2_stepped[1] = x2_corrected + dx2;
assign x2_stepped[2] = x2_corrected + dx2 + dx2;
assign x2_stepped[3] = x2_corrected + dx2 + dx2 + dx2;

genvar i;
generate
    for (i=0; i<4; i=i+1) begin
        row_rasterizer r(
            .clk(clk),
            .reset(reset),
            .advance_x(row_advance_x[i]),
            .advance_y(row_advance_y[i]),
            .load(recalc),
            .x1_in(x1_stepped[i]),
            .x2_in(x2_stepped[i]),
            .dx1(dx1 * 4),
            .dx2(dx2 * 4),
            .patch_x(row_patch_x[i]),
            .mask(row_masks[i]),
            .done(done[i]));
    end
endgenerate


reg signed [15:0] min_patch_x;
always @(row_patch_x[0], row_patch_x[1], row_patch_x[2], row_patch_x[3]) begin: mp
    integer i;
    min_patch_x = row_patch_x[0];
    for (i=1; i<4; i=i+1) begin
        if (row_patch_x[i] < min_patch_x) min_patch_x = row_patch_x[i];
    end
end

assign patch_x = min_patch_x;

wire [0:3] in_range;
assign in_range[0] = patch_y >= top_y && patch_y <= bot_y;
assign in_range[1] = patch_y+1 >= top_y && patch_y+1 <= bot_y;
assign in_range[2] = patch_y+2 >= top_y && patch_y+2 <= bot_y;
assign in_range[3] = patch_y+3 >= top_y && patch_y+3 <= bot_y;

assign valid = !all_done && mask && patch_x>=clip_left && patch_x<clip_right;
wire step = advance || (enable && !valid && busy);

assign mask[ 0: 3] = row_masks[0] & {4{row_patch_x[0] == min_patch_x && in_range[0]}};
assign mask[ 4: 7] = row_masks[1] & {4{row_patch_x[1] == min_patch_x && in_range[1]}};
assign mask[ 8:11] = row_masks[2] & {4{row_patch_x[2] == min_patch_x && in_range[2]}};
assign mask[12:15] = row_masks[3] & {4{row_patch_x[3] == min_patch_x && in_range[3]}};

assign row_advance_x[0] = !done[0] && row_patch_x[0] == min_patch_x && step;
assign row_advance_x[1] = !done[1] && row_patch_x[1] == min_patch_x && step;
assign row_advance_x[2] = !done[2] && row_patch_x[2] == min_patch_x && step;
assign row_advance_x[3] = !done[3] && row_patch_x[3] == min_patch_x && step;

assign row_advance_y = {4{all_done && patch_y <= bot_y && step}};

endmodule



/*
module top;


reg clk, reset;
reg setup, advance;
reg [31:0] x1, x2, dx1, dx2;
reg [15:0] y, h;

wire [15:0] patch_x, patch_y;
wire [0:15] mask;
wire valid, busy;
    
rasterizer r(
    .clk(clk),
    .reset(reset),
    .setup(setup),
    .advance(advance),
    .x1_in(x1),
    .x2_in(x2),
    .dx1_in(dx1),
    .dx2_in(dx2),
    .y_in(y),
    .height_in(h),
    .patch_x(patch_x),
    .patch_y(patch_y),
    .mask(mask),
    .out_valid(valid),
    .busy(busy));

initial begin
    clk = 0;
    forever begin
        #5;
        clk = !clk;
    end
end

initial begin
    $dumpfile("cpu.vcd");
    $dumpvars;
    
    setup = 0;
    advance = 0;

    reset = 1;
    #100;
    reset = 0;
    @(posedge clk); #1;
    
    x1 = 32'h00050000;
    x2 = 32'h00060000;
    dx1 = -32'h00008000;
    dx2 = 32'h00008000;
    y = 2;
    h = 7;
    setup = 1;
    @(posedge clk); #1;
    setup = 0;
    
    @(posedge clk); #1;
    advance = 1;
    
    while (busy) begin
        @(posedge clk); #1;
    end
    $finish;
end

always @(posedge clk) begin
    if (valid && advance) begin
        $display("x=%d, y=%d", patch_x, patch_y);
        $display("  %4b", mask[ 0: 3]);
        $display("  %4b", mask[ 4: 7]);
        $display("  %4b", mask[ 8:11]);
        $display("  %4b", mask[12:15]);
    end
end

endmodule
*/

