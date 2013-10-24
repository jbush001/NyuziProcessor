

module point_in_triangle(
    input signed [31:0] A1,
    input signed [31:0] B1,
    input signed [31:0] C1,
    input signed [31:0] A2,
    input signed [31:0] B2,
    input signed [31:0] C2,
    input signed [31:0] A3,
    input signed [31:0] B3,
    input signed [31:0] C3,
    input signed [15:0] x,
    input signed [15:0] y,
    output inside_triangle);

wire signed [47:0] a1 = A1*x;
wire signed [47:0] b1 = B1*y;
wire signed [47:0] c1 = C1;
wire signed [47:0] a2 = A2*x;
wire signed [47:0] b2 = B2*y;
wire signed [47:0] c2 = C2;
wire signed [47:0] a3 = A3*x;
wire signed [47:0] b3 = B3*y;
wire signed [47:0] c3 = C3;

wire signed [47:0] edge1 = a1 + b1 + c1;
wire signed [47:0] edge2 = a2 + b2 + c2;
wire signed [47:0] edge3 = a3 + b3 + c3;

assign inside_triangle = edge1[47] && edge2[47] && edge3[47];

endmodule


module mask_in_triangle(
    input signed [31:0] A1,
    input signed [31:0] B1,
    input signed [31:0] C1,
    input signed [31:0] A2,
    input signed [31:0] B2,
    input signed [31:0] C2,
    input signed [31:0] A3,
    input signed [31:0] B3,
    input signed [31:0] C3,
    input signed [15:0] x,
    input signed [15:0] y,
    output [0:15] mask);

genvar i;
generate
    for (i=0; i<16; i=i+1) begin: make_mask
        point_in_triangle pit(A1, B1, C1, A2, B2, C2, A3, B3, C3, (i&3)+x, (3&(i>>2))+y, mask[i]);
    end
endgenerate

endmodule


module min4(
    input signed [31:0] a,
    input signed [31:0] b,
    input signed [31:0] c,
    input signed [31:0] clip_edge,
    input do_clip,
    output signed [31:0] min);
wire signed [31:0] m1 = (a<b) ? a : b;
wire signed [31:0] m2 = (m1<c) ? m1 : c;
assign min = (do_clip && clip_edge > m2) ? clip_edge : m2;
endmodule

module max4(
    input signed [31:0] a,
    input signed [31:0] b,
    input signed [31:0] c,
    input signed [31:0] clip_edge,
    input do_clip,
    output signed [31:0] max);
wire signed [31:0] m1 = (a>b) ? a : b;
wire signed [31:0] m2 = (m1>c) ? m1 : c;
assign max = (do_clip && clip_edge < m2) ? clip_edge : m2;
endmodule


module rasterizer
    #(parameter BASE_ADDRESS = 0)
    (input clk,
    input reset,
    input [31:0] io_address,
    input [31:0] io_write_data,
    output reg [31:0] io_read_data,
    input io_write_en,
    output waiting,     // Active but waiting on software to pop a patch
    output active,      // Doing useful work
    output unused);     // Inactive

reg signed [31:0] x1, y1, x2, y2, x3, y3;
reg signed [15:0] left, right, top, bot;    // Clipping is inclusive on the bot and right!
reg enable, advance, clip;
wire busy, valid;
wire [0:15] mask;

// These are probably all wrong
wire signed [31:0] A1, B1, C1, A2, B2, C2, A3, B3, C3;
assign A1 = y2-y1;
assign B1 = x1-x2;
wire [63:0] c1 = x2*y1 - x1*y2;
assign C1 = c1 >> 16;
assign A2 = y3-y2;
assign B2 = x2-x3;
wire [63:0] c2 = x3*y2 - x2*y3;
assign C2 = c2 >> 16;
assign A3 = y1-y3;
assign B3 = x3-x1;
wire [63:0] c3 = x1*y3 - x3*y1;
assign C3 = c3 >> 16;

wire [31:0] min_y, max_y, min_x, max_x;
min4 min4y(y1, y2, y3, {top, 16'b0}, clip, min_y);
min4 min4x(x1, x2, x3, {left, 16'b0}, clip, min_x);
max4 max4y(y1, y2, y3, {bot, 16'b0}, clip, max_y);
max4 max4x(x1, x2, x3, {right, 16'b0}, clip, max_x);

reg [15:0] patch_x, patch_y;

wire[4:0] io_reg_index = (io_address - BASE_ADDRESS) >> 2;

always @(posedge clk, posedge reset) begin
    if (reset) begin
        {x1, y1, x2, y2, x3, y3, advance, enable, top, bot, left, right, clip} <= 0;
    end else begin
        advance <= 0;
        if (io_write_en) begin
            case (io_reg_index)
                0: x1 <= io_write_data;
                1: y1 <= io_write_data;
                2: x2 <= io_write_data;
                3: y2 <= io_write_data;
                4: x3 <= io_write_data;
                5: y3 <= io_write_data;
                6: advance <= io_write_data[0];
                7: begin
                    enable <= io_write_data[0];
                    if (io_write_data[0]) begin
                        patch_x <= {min_x[31:18], 2'b0};
                        patch_y <= {min_y[31:18], 2'b0};
                    end
                end
                8: left <= io_write_data;
                9: top <= io_write_data;
               10: right <= io_write_data;
               11: bot <= io_write_data;
               12: clip <= io_write_data[0];
            endcase
        end
    end
end

always @(busy, valid, mask, patch_x, patch_y, io_reg_index) begin
    io_read_data = 0;
    case (io_reg_index)
        0: io_read_data = {busy, valid};
        1: io_read_data = mask;
        2: io_read_data = patch_x;
        3: io_read_data = patch_y;
    endcase
end

mask_in_triangle mit(A1, B1, C1, A2, B2, C2, A3, B3, C3, patch_x, patch_y, mask);

wire y_in_range = {patch_y, 16'b0} <= max_y;
wire x_in_range = {patch_x, 16'b0} <= max_x;
assign busy = y_in_range;
assign valid = busy && mask && x_in_range;
wire auto_advance = busy && (!mask || !x_in_range) && enable;

assign active = advance || io_write_en;
assign waiting = enable && !active;
assign unused = !enable && !active;

always @(posedge clk) begin
    if (advance || auto_advance) begin
        if (x_in_range) begin
            patch_x <= patch_x + 4;
        end else begin
            patch_x <= {min_x[31:18], 2'b0};
            patch_y <= patch_y + 4;
        end
    end
end

endmodule



