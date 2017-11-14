


/*
    We use the formula Ax - By + C = 0 to represent a line.
    This makes the math a little prettier.  Also, a point is considered 
    "inside" if Ax-By+C is non-negative.  
    
    For a line (x1,y1)-(x2,y2):
    A = y2 - y1
    B = x2 - x1
    C = B*y1 - A*x1
*/


/*
    Compute a 4x4 mask for one edge.
    This takes the following inputs:
    A, B = See above
    D = Ax-By+C for the upper left corner of the patch
*/
module one_edge_mask(
    input signed [15:0] A,
    input signed [15:0] B,
    input signed [31:0] D,  // Ax-By+C corner value
    output [0:15] mask);
genvar i;
generate
for (i=0; i<16; i=i+1) begin
    wire [3:0] j = i;
    wire signed [2:0] x = j[1:0];
    wire signed [2:0] y = j[3:2];
    wire signed [31:0] corner = A*x - B*y + D;
    assign mask[i] = !corner[31];
end
endgenerate
endmodule


/*
    Compute line parameters (A,B,C) for a pair of coordinates.
    Counter-clockwise is assumed, putting non-negative points 
    "inside."
*/
module one_edge_setup(
    input signed [15:0] tile_x,  // Corner of bounding box
    input signed [15:0] tile_y,
    input signed [15:0] x1,
    input signed [15:0] y1,
    input signed [15:0] x2,
    input signed [15:0] y2,
    input signed [31:0] C_in,
    input phase,
    output signed [15:0] A_out,
    output signed [15:0] B_out,
    output signed [31:0] CD_out);   // Corner value
    
wire bias = (y1 < y2) || ((y1 == y2) && (x2 < x1));
wire [15:0] A = y2 - y1;
wire [15:0] B = x2 - x1;
//wire signed [31:0] C = B*y1 - A*x1 - $signed({1'b0, bias});
//assign D = A*tile_x - B*tile_y + C;

/* Do the math with only two multipliers */

wire signed [15:0] p, q, r, s;
wire signed [31:0] t;
wire signed [31:0] u = p*q;
wire signed [31:0] v = r*s;
wire signed [31:0] w = u - v + t;

// Computing:      D                     C
assign p = phase ? A                   : B;
assign q = phase ? tile_x              : y1;
assign r = phase ? B                   : A;
assign s = phase ? tile_y              : x1;
assign t = phase ? C_in                : {32{bias}};

assign A_out = A;
assign B_out = B;
assign CD_out = w;
endmodule

module box_left(
    input signed [15:6] tile_x,
    input signed [15:0] x1,
    input signed [15:0] x2,
    input signed [15:0] x3,
    output [3:0] min);
wire signed [15:2] left  = {tile_x, 4'b0};
wire signed [15:2] right = {tile_x, 4'b1111};
reg signed [15:2] min_x;
always @(*) begin
    min_x = x1[15:2];
    if ($signed(x2[15:2]) < min_x) min_x = x2[15:2];
    if ($signed(x3[15:2]) < min_x) min_x = x3[15:2];
    if (right < min_x) min_x = right;
    if (left > min_x) min_x = left;
    min_x = min_x - left;
    min = min_x[5:2];
end
endmodule

module box_right(
    input signed [15:6] tile_x,
    input signed [15:0] x1,
    input signed [15:0] x2,
    input signed [15:0] x3,
    output [3:0] max);
wire signed [15:2] left  = {tile_x, 4'b0};
wire signed [15:2] right = {tile_x, 4'b1111};
reg signed [15:2] max_x;
always @(*) begin
    max_x = x1[15:2];
    if ($signed(x2[15:2]) > max_x) max_x = x2[15:2];
    if ($signed(x3[15:2]) > max_x) max_x = x3[15:2];
    if (right < max_x) max_x = right;
    if (left > max_x) max_x = left;
    max_x = max_x - left;
    max = max_x[5:2];
end
endmodule


/*
    States:
     0 - Compute bounding box left and right
     1 - Compute bounding box top and bottom
     2 - Setup line 1, computing A, B, C
     3 - Setup line 1, computing D=Ax-By+C for upper left corner
     4 - Setup line 2, computing A, B, C
     5 - Setup line 3, computing D=Ax-By+C for upper left corner
     6 - Setup line 3, computing A, B, C
     7 - Setup line 3, computing D=Ax-By+C for upper left corner
     8 - Compute mask for line 1, compute next D
     9 - Compute mask for line 2, accumulate combined mask, compute next D
    10 - Compute mask for line 3, accumulate combined mask, compute next D
    11 - On blank mask, go to 12, otherwise wait for advance then go to 12
    12 - Advance coordinates; if done go to 15, else 8
    15 - Idle, go to 0 on start

    When at left edge, store D-4*B for advancing down
*/


module rasterizer_unit_H5
    (input clock,
    input reset,
    input [3:0] reg_addr,
    input [31:0] io_write_data,
    output reg [31:0] io_read_data,
    input io_write_en,
    input io_read_en);


reg signed [15:0] x1, y1, x2, y2, x3, y3;
reg signed [15:6] tile_x, tile_y;

reg [3:0] left, right, top, bot;

reg signed [15:0] A1, B1, A2, B2, A3, B3;
reg signed [31:0] C1, C2, C3;
reg signed [31:0] D1, D2, D3;

reg start, advance, started;
reg [0:15] mask;
reg mask_valid;
reg [3:0] state;

reg [3:0] patch_x, patch_y;
wire done;

always @(posedge clock) begin
    start <= 0;
    if (io_write_en) begin
        case (reg_addr[2:0])
            0: begin
                tile_x <= io_write_data[15:6];
                tile_y <= io_write_data[31:22];
            end
            2: {y1, x1} <= io_write_data;
            4: {y2, x2} <= io_write_data;
            6: {y3, x3} <= io_write_data;
            default: ;
        endcase
        start <= reg_addr[3];
    end
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        started <= 0;
    end else begin
        if (start) started <= 1;
    end
end

always @(posedge clock) begin
    advance <= 0;
    if (io_read_en) begin
        advance <= reg_addr[3];
    end
end


/*reg [31:0] idle_cycles, busy_cycles;
wire busy = start || state < 11 || state == 12 || advance || (state == 11 && !mask_valid);
always @(posedge clock or posedge reset) begin
    if (reset) begin
        busy_cycles <= 0;
        idle_cycles <= 0;
    end else begin
        if (started) begin
            if (busy) begin
                busy_cycles <= busy_cycles + 1;
            end else begin
                idle_cycles <= idle_cycles + 1;
            end
        end
    end
end*/

wire [31:0] status;
assign status[15:0] = mask;
assign status[16] = state == 15;
assign status[17] = mask_valid;
assign status[31:18] = 0;

always @(*) begin
    io_read_data = 0;
    case (reg_addr[2:0])
        0: begin
            io_read_data[31:16] = {tile_y, patch_y, 2'b0};
            io_read_data[15:0]  = {tile_x, patch_x, 2'b0};
        end
        2: io_read_data = status;
        //4: io_read_data = idle_cycles;
        //5: io_read_data = busy_cycles;
    endcase
end


// Manage state transitions
always @(posedge clock or posedge reset) begin
    if (reset) begin
        state <= 15;
    end else begin
        if (start) begin
            state <= 0;
        end else if (state < 11) begin
            state <= state + 1;
        end else if (state == 11) begin
            if (!mask_valid || advance) begin
                state <= 12;
            end
        end else if (state == 12) begin
            if (done) begin
                state <= 15;
            end else begin
                state <= 8;
            end
        end
    end
end


// Bounding box setup
wire [3:0] min_val;
box_left bl(
    .tile_x(state[0] ? tile_y : tile_x),
    .x1    (state[0] ? y1 : x1),
    .x2    (state[0] ? y2 : x2),
    .x3    (state[0] ? y3 : x3),
    .min   (min_val));
wire [3:0] max_val;
box_right br(
    .tile_x(state[0] ? tile_y : tile_x),
    .x1    (state[0] ? y1 : x1),
    .x2    (state[0] ? y2 : x2),
    .x3    (state[0] ? y3 : x3),
    .max   (max_val));

always @(posedge clock) begin
    if (state == 0) begin
        left <= min_val;
        right <= max_val;
    end
    if (state == 1) begin
        top <= min_val;
        bot <= max_val;
    end
end


// Line setup
reg signed [15:0] setup_x1, setup_y1, setup_x2, setup_y2;
reg signed [31:0] setup_C_in;
always @(*) begin
    case (state[2:1])
        1: begin
            setup_x1 = x1;
            setup_y1 = y1;
            setup_x2 = x2;
            setup_y2 = y2;
            setup_C_in = C1;
        end
        2: begin
            setup_x1 = x2;
            setup_y1 = y2;
            setup_x2 = x3;
            setup_y2 = y3;
            setup_C_in = C2;
        end
        default: begin
            setup_x1 = x3;
            setup_y1 = y3;
            setup_x2 = x1;
            setup_y2 = y1;
            setup_C_in = C3;
        end
    endcase
end

wire signed [15:0] A_out, B_out;
wire signed [31:0] CD_out;
one_edge_setup oes(
    .tile_x({tile_x,left,2'b0}),
    .tile_y({tile_y,top,2'b0}),
    .x1(setup_x1),
    .y1(setup_y1),
    .x2(setup_x2),
    .y2(setup_y2),
    .C_in(setup_C_in),
    .phase(state[0]),
    .A_out(A_out),
    .B_out(B_out),
    .CD_out(CD_out));

always @(posedge clock) begin
    case (state)
        2: begin
            A1 <= A_out;
            B1 <= B_out;
            //C1 <= CD_out;
        end
        //3: C1 <= CD_out;
        4: begin
            A2 <= A_out;
            B2 <= B_out;
            //C2 <= CD_out;
        end
        //5: C2 <= CD_out;
        6: begin
            A3 <= A_out;
            B3 <= B_out;
            //C3 <= CD_out;
        end
        //7: C3 <= CD_out;
    endcase
end


// Compute masks
reg signed [15:0] edge_A, edge_B;
reg signed [31:0] edge_D;

always @(*) begin
    case (state[1:0])
        0: begin
            edge_A = A1;
            edge_B = B1;
            edge_D = D1;
        end
        1: begin
            edge_A = A2;
            edge_B = B2;
            edge_D = D2;
        end
        default: begin
            edge_A = A3;
            edge_B = B3;
            edge_D = D3;
        end
    endcase
end

wire [0:15] edge_mask;
one_edge_mask oem(edge_A, edge_B, edge_D, edge_mask);

wire [0:15] combined_mask = edge_mask & mask;

always @(posedge clock) begin
    case (state)
        8: mask <= edge_mask;
        9: mask <= combined_mask;
        10: mask <= combined_mask;
    endcase
    if (state == 10) begin
        mask_valid <= combined_mask != 0;
    end else if (state != 11) begin
        mask_valid <= 0;
    end
end



// Update C and D values
wire at_right = patch_x >= right;

reg signed [15:0] update_A, update_B;
reg signed [31:0] update_C, update_D;

always @(*) begin
    case (state[1:0])
        0: begin
            update_A = A1<<2;
            update_B = B1<<2;
            update_C = C1;
            update_D = D1;
        end
        1: begin
            update_A = A2<<2;
            update_B = B2<<2;
            update_C = C2;
            update_D = D2;
        end
        default: begin
            update_A = A3<<2;
            update_B = B3<<2;
            update_C = C3;
            update_D = D3;
        end
    endcase
end

wire signed [31:0] new_C = update_C - update_B;
wire signed [31:0] new_D = update_D + update_A;

always @(posedge clock) begin
    case (state)
        2,3: begin
            C1 <= CD_out;
            D1 <= CD_out;
        end
        4,5: begin
            C2 <= CD_out;
            D2 <= CD_out;
        end
        6,7: begin
            C3 <= CD_out;
            D3 <= CD_out;
        end
        8: begin
            if (at_right) begin
                C1 <= new_C;
                D1 <= new_C;
            end else begin
                D1 <= new_D;
            end
        end
        9: begin
            if (at_right) begin
                C2 <= new_C;
                D2 <= new_C;
            end else begin
                D2 <= new_D;
            end
        end
        10: begin
            if (at_right) begin
                C3 <= new_C;
                D3 <= new_C;
            end else begin
                D3 <= new_D;
            end
        end
    endcase
end


// Update coordinates
wire at_bottom = patch_y >= bot;
assign done = at_bottom && at_right;

always @(posedge clock) begin
    if (state == 2) begin
        patch_x <= left;
        patch_y <= top;
    end else if (state == 12) begin
        if (at_right) begin
            patch_x <= left;
            patch_y <= patch_y + 1;
        end else begin
            patch_x <= patch_x + 1;
        end
    end
end

endmodule


module rasterizer_H5
    #(parameter BASE_ADDRESS = 1)
    (input clock,
    input reset,
    input [3:0] io_address,
    input [31:0] io_write_data,
    output reg [31:0] io_read_data,
    input io_write_en,
    input io_read_en);

wire [31:0] data_l;
reg [3:0] io_address_r;
reg [31:0] io_write_data_r;
reg io_write_en_r, io_read_en_r;

// A layer of registers between the logic and the I/O pads; might need more.
always @(posedge clock) begin
    io_address_r <= io_address;
    io_write_data_r <= io_write_data;
    io_write_en_r <= io_write_en;
    io_read_en_r <= io_read_en;
    io_read_data <= data_l;
end

rasterizer_unit_H5 ru0 (clock, reset, io_address_r, io_write_data_r, data_l, io_write_en_r, io_read_en_r);

endmodule


/*module rasterizer_H5
    #(parameter BASE_ADDRESS = 1)
    (input clock,
    input reset,
    input [31:0] io_address,
    input [31:0] io_write_data,
    output reg [31:0] io_read_data,
    input io_write_en,
    input io_read_en);

reg [31:0] data0, data1, data2, data3;


wire [1:0] which_unit = io_address[7:6];
wire valid_io = io_address[31:8] == BASE_ADDRESS;
wire [3:0] reg_addr = io_address[5:2];

wire read0 = io_read_en && valid_io && which_unit==0;
wire read1 = io_read_en && valid_io && which_unit==1;
wire read2 = io_read_en && valid_io && which_unit==2;
wire read3 = io_read_en && valid_io && which_unit==3;
wire write0 = io_write_en && valid_io && which_unit==0;
wire write1 = io_write_en && valid_io && which_unit==1;
wire write2 = io_write_en && valid_io && which_unit==2;
wire write3 = io_write_en && valid_io && which_unit==3;

rasterizer_unit_H5 ru0 (clock, reset, reg_addr, io_write_data, data0, write0, read0);
rasterizer_unit_H5 ru1 (clock, reset, reg_addr, io_write_data, data1, write1, read1);
rasterizer_unit_H5 ru2 (clock, reset, reg_addr, io_write_data, data2, write2, read2);
rasterizer_unit_H5 ru3 (clock, reset, reg_addr, io_write_data, data3, write3, read3);

always @(*) begin
    case (which_unit)
        0: io_read_data = data0;
        1: io_read_data = data1;
        2: io_read_data = data2;
        3: io_read_data = data3;
    endcase
end

endmodule*/

