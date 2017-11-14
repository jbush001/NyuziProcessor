


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


module rasterizer_unit_H6
    (input clock,
    input reset,
    input [3:0] reg_addr,
    input [1:0] which_unit,
    input [31:0] io_write_data,
    output reg [31:0] io_read_data,
    input io_write_en,
    input io_read_en);


reg signed [15:0] x1 [0:3]; 
reg signed [15:0] x2 [0:3]; 
reg signed [15:0] x3 [0:3]; 
reg signed [15:0] y1 [0:3]; 
reg signed [15:0] y2 [0:3]; 
reg signed [15:0] y3 [0:3]; 
reg signed [15:6] tile_x [0:3];
reg signed [15:6] tile_y [0:3];

reg [3:0] left [0:3];
reg [3:0] right [0:3];
reg [3:0] top [0:3];
reg [3:0] bot [0:3];

reg signed [15:0] A1 [0:3];
reg signed [15:0] B1 [0:3];
reg signed [15:0] A2 [0:3];
reg signed [15:0] B2 [0:3];
reg signed [15:0] A3 [0:3];
reg signed [15:0] B3 [0:3];
reg signed [31:0] C1 [0:3];
reg signed [31:0] C2 [0:3];
reg signed [31:0] C3 [0:3];
reg signed [31:0] D1 [0:3];
reg signed [31:0] D2 [0:3];
reg signed [31:0] D3 [0:3];

reg [3:0] start, advance, started;
reg [0:15] mask [0:3];
reg [3:0] mask_valid;
reg [3:0] state [0:3];
reg [3:0] done;
reg [3:0] waiting;

reg [3:0] patch_x [0:3];
reg [3:0] patch_y [0:3];
wire last_patch;


wire [3:0] skip;
reg [1:0] ncon;
wire [3:0] current_state = state[ncon];
always @(posedge clock or posedge reset) begin
    if (reset) begin
        ncon <= 0;
    end else begin
        case (ncon)
            0: begin
//                if (!skip[0]) begin
//                    ncon <= 0;
//                end else 
                if (!skip[1]) begin
                    ncon <= 1;
                end else if (!skip[2]) begin
                    ncon <= 2;
                end else if (!skip[3]) begin
                    ncon <= 3;
                end
            end
            1: begin
//                if (!skip[1]) begin
//                    ncon <= 1;
//                end else
                if (!skip[2]) begin
                    ncon <= 2;
                end else if (!skip[3]) begin
                    ncon <= 3;
                end else if (!skip[0]) begin
                    ncon <= 0;
                end
            end
            2: begin
//                if (!skip[2]) begin
//                    ncon <= 2;
//                end else 
                if (!skip[3]) begin
                    ncon <= 3;
                end else if (!skip[0]) begin
                    ncon <= 0;
                end else if (!skip[1]) begin
                    ncon <= 1;
                end
            end
            3: begin
//                if (!skip[3]) begin
//                    ncon <= 3;
//                end else 
                if (!skip[0]) begin
                    ncon <= 0;
                end else if (!skip[1]) begin
                    ncon <= 1;
                end else if (!skip[2]) begin
                    ncon <= 2;
                end
            end
        endcase
    end
end

/*genvar i;
generate
for (i=0; i<4; i=i+1) begin
    assign skip[i] = (done[i] && !start[i]) || (waiting[i] && mask_valid[i] && !advance[i]);
end
endgenerate*/
assign skip = (done & ~start) | (waiting & mask_valid & ~advance);

always @(posedge clock or posedge reset) begin
    if (reset) begin
        start <= 0;
    end else begin
        if (io_write_en && reg_addr[3]) begin
            start[which_unit] <= 1;
        end
        if (current_state != 15) begin
            start[ncon] <= 0;
        end
    end
end

always @(posedge clock) begin
    if (io_write_en) begin
        case (reg_addr[2:0])
            0: begin
                tile_x[which_unit] <= io_write_data[15:6];
                tile_y[which_unit] <= io_write_data[31:22];
            end
            2: {y1[which_unit], x1[which_unit]} <= io_write_data;
            4: {y2[which_unit], x2[which_unit]} <= io_write_data;
            6: {y3[which_unit], x3[which_unit]} <= io_write_data;
            default: ;
        endcase
    end
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        started <= 0;
    end else begin
        started <= started | start;
    end
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        advance <= 0;
    end else begin
        if (io_read_en && reg_addr[3]) begin
            advance[which_unit] <= 1;
        end
        if (current_state != 11) begin
            advance[ncon] <= 0;
        end
    end
end


wire [3:0] busy;
genvar i;
generate
for (i=0; i<4; i=i+1) begin
    assign busy[i] = ncon==i && (start[i] || state[i]<11 || state[i]==12 || (state[i]==11 && (!mask_valid[i] || advance[i])));
end
endgenerate

/*
//reg [31:0] idle_cycles [0:3];
//reg [31:0] busy_cycles [0:3];
reg [31:0] busy_cycles, idle_cycles;
reg [31:0] num_triangles [0:3];
reg [31:0] num_patches [0:3];
always @(posedge clock or posedge reset) begin
    if (reset) begin
        busy_cycles <= 0;
        idle_cycles <= 0;
        //busy_cycles[0] <= 0;
        //busy_cycles[1] <= 0;
        //busy_cycles[2] <= 0;
        //busy_cycles[3] <= 0;
        //idle_cycles[0] <= 0;
        //idle_cycles[1] <= 0;
        //idle_cycles[2] <= 0;
        //idle_cycles[3] <= 0;
        num_triangles[0] <= 0;
        num_triangles[1] <= 0;
        num_triangles[2] <= 0;
        num_triangles[3] <= 0;
        num_patches[0] <= 0;
        num_patches[1] <= 0;
        num_patches[2] <= 0;
        num_patches[3] <= 0;
    end else begin
        if (started) begin: x
            //if (skip != 4'b1111) begin
            if (busy) begin
                busy_cycles <= busy_cycles + 1;
            end else begin
                idle_cycles <= idle_cycles + 1;
            end
//             integer i;
//             for (i=0; i<4; i=i+1) begin
//                 if (skip[i]) begin
//                     idle_cycles[i] <= idle_cycles[i] + 1;
//                 end else if (i==ncon) begin
//                     if (current_state == 1) num_triangles[i] <= num_triangles[i] + 1;
//                     if (current_state == 12) num_patches[i] <= num_patches[i] + 1;
//                     busy_cycles[i] <= busy_cycles[i] + 1;
//                 end
//             end
        end
    end
end*/


always @(*) begin
    io_read_data = 0;
    case (reg_addr[2:0])
        0: begin
            io_read_data[31:16] = {tile_y[which_unit], patch_y[which_unit], 2'b0};
            io_read_data[15:0]  = {tile_x[which_unit], patch_x[which_unit], 2'b0};
        end
        2: begin
            io_read_data[15:0] = mask[which_unit];
            io_read_data[16] = done[which_unit] && !start[which_unit];
            io_read_data[17] = mask_valid[which_unit];
        end
        //4: io_read_data = idle_cycles[which_unit];
        //5: io_read_data = busy_cycles[which_unit];
        /*4: io_read_data = idle_cycles;
        5: io_read_data = busy_cycles;
        6: io_read_data = num_triangles[which_unit];
        7: io_read_data = num_patches[which_unit];*/
    endcase
end


reg [2:0] reset_state;
always @(posedge clock or posedge reset) begin
    if (reset) begin
        reset_state <= 0;
    end else begin
        if (!reset_state[2]) reset_state <= reset_state + 1;
    end
end

// Manage state transitions
always @(posedge clock) begin
    if (!reset_state[2]) begin
        state[reset_state[1:0]] <= 15;
        done[reset_state[1:0]] <= 1;
        waiting[reset_state[1:0]] <= 0;
    end else begin
        if (state[ncon]==15 && start[ncon]) begin
            state[ncon] <= 0;
            done[ncon] <= 0;
        end else if (current_state < 10) begin
            state[ncon] <= current_state + 1;
        end else if (current_state == 10) begin
            state[ncon] <= 11;
            waiting[ncon] <= 1;
        end else if (current_state == 11) begin
            if (!mask_valid[ncon] || advance[ncon]) begin
                state[ncon] <= 12;
                waiting[ncon] <= 0;
            end
        end else if (current_state == 12) begin
            if (last_patch) begin
                state[ncon] <= 15;
                done[ncon] <= 1;
            end else begin
                state[ncon] <= 8;
            end
        end
    end
end


// Bounding box setup
wire [3:0] min_val;
box_left bl(
    .tile_x(current_state[0] ? tile_y[ncon] : tile_x[ncon]),
    .x1    (current_state[0] ? y1[ncon] : x1[ncon]),
    .x2    (current_state[0] ? y2[ncon] : x2[ncon]),
    .x3    (current_state[0] ? y3[ncon] : x3[ncon]),
    .min   (min_val));
wire [3:0] max_val;
box_right br(
    .tile_x(current_state[0] ? tile_y[ncon] : tile_x[ncon]),
    .x1    (current_state[0] ? y1[ncon] : x1[ncon]),
    .x2    (current_state[0] ? y2[ncon] : x2[ncon]),
    .x3    (current_state[0] ? y3[ncon] : x3[ncon]),
    .max   (max_val));

always @(posedge clock) begin
    if (current_state == 0) begin
        left[ncon] <= min_val;
        right[ncon] <= max_val;
    end
    if (current_state == 1) begin
        top[ncon] <= min_val;
        bot[ncon] <= max_val;
    end
end


// Line setup
reg signed [15:0] setup_x1, setup_y1, setup_x2, setup_y2;
reg signed [31:0] setup_C_in;
always @(*) begin
    case (current_state[2:1])
        1: begin
            setup_x1 = x1[ncon];
            setup_y1 = y1[ncon];
            setup_x2 = x2[ncon];
            setup_y2 = y2[ncon];
            setup_C_in = C1[ncon];
        end
        2: begin
            setup_x1 = x2[ncon];
            setup_y1 = y2[ncon];
            setup_x2 = x3[ncon];
            setup_y2 = y3[ncon];
            setup_C_in = C2[ncon];
        end
        default: begin
            setup_x1 = x3[ncon];
            setup_y1 = y3[ncon];
            setup_x2 = x1[ncon];
            setup_y2 = y1[ncon];
            setup_C_in = C3[ncon];
        end
    endcase
end

wire signed [15:0] A_out, B_out;
wire signed [31:0] CD_out;
one_edge_setup oes(
    .tile_x({tile_x[ncon],left[ncon],2'b0}),
    .tile_y({tile_y[ncon],top[ncon],2'b0}),
    .x1(setup_x1),
    .y1(setup_y1),
    .x2(setup_x2),
    .y2(setup_y2),
    .C_in(setup_C_in),
    .phase(current_state[0]),
    .A_out(A_out),
    .B_out(B_out),
    .CD_out(CD_out));

always @(posedge clock) begin
    case (current_state)
        2: begin
            A1[ncon] <= A_out;
            B1[ncon] <= B_out;
            //C1 <= CD_out;
        end
        //3: C1 <= CD_out;
        4: begin
            A2[ncon] <= A_out;
            B2[ncon] <= B_out;
            //C2 <= CD_out;
        end
        //5: C2 <= CD_out;
        6: begin
            A3[ncon] <= A_out;
            B3[ncon] <= B_out;
            //C3 <= CD_out;
        end
        //7: C3 <= CD_out;
    endcase
end


// Compute masks
reg signed [15:0] edge_A, edge_B;
reg signed [31:0] edge_D;

always @(*) begin
    case (current_state[1:0])
        0: begin
            edge_A = A1[ncon];
            edge_B = B1[ncon];
            edge_D = D1[ncon];
        end
        1: begin
            edge_A = A2[ncon];
            edge_B = B2[ncon];
            edge_D = D2[ncon];
        end
        default: begin
            edge_A = A3[ncon];
            edge_B = B3[ncon];
            edge_D = D3[ncon];
        end
    endcase
end

wire [0:15] edge_mask;
one_edge_mask oem(edge_A, edge_B, edge_D, edge_mask);

wire [0:15] combined_mask = edge_mask & mask[ncon];

always @(posedge clock) begin
    case (current_state)
        8: mask[ncon] <= edge_mask;
        9: mask[ncon] <= combined_mask;
        10: mask[ncon] <= combined_mask;
    endcase
end
always @(posedge clock) begin
    if (current_state == 10) begin
        mask_valid[ncon] <= combined_mask != 0;
    end else if (current_state != 11) begin
        mask_valid[ncon] <= 0;
    end
end



// Update C and D values
wire at_right = patch_x[ncon] >= right[ncon];

reg signed [15:0] update_A, update_B;
reg signed [31:0] update_C, update_D;

always @(*) begin
    case (current_state[1:0])
        0: begin
            update_A = A1[ncon]<<2;
            update_B = B1[ncon]<<2;
            update_C = C1[ncon];
            update_D = D1[ncon];
        end
        1: begin
            update_A = A2[ncon]<<2;
            update_B = B2[ncon]<<2;
            update_C = C2[ncon];
            update_D = D2[ncon];
        end
        default: begin
            update_A = A3[ncon]<<2;
            update_B = B3[ncon]<<2;
            update_C = C3[ncon];
            update_D = D3[ncon];
        end
    endcase
end

wire signed [31:0] new_C = update_C - update_B;
wire signed [31:0] new_D = update_D + update_A;

always @(posedge clock) begin
    case (current_state)
        2,3: begin
            C1[ncon] <= CD_out;
            D1[ncon] <= CD_out;
        end
        4,5: begin
            C2[ncon] <= CD_out;
            D2[ncon] <= CD_out;
        end
        6,7: begin
            C3[ncon] <= CD_out;
            D3[ncon] <= CD_out;
        end
        8: begin
            if (at_right) begin
                C1[ncon] <= new_C;
                D1[ncon] <= new_C;
            end else begin
                D1[ncon] <= new_D;
            end
        end
        9: begin
            if (at_right) begin
                C2[ncon] <= new_C;
                D2[ncon] <= new_C;
            end else begin
                D2[ncon] <= new_D;
            end
        end
        10: begin
            if (at_right) begin
                C3[ncon] <= new_C;
                D3[ncon] <= new_C;
            end else begin
                D3[ncon] <= new_D;
            end
        end
    endcase
end


// Update coordinates
wire at_bottom = patch_y[ncon] >= bot[ncon];
assign last_patch = at_bottom && at_right;

always @(posedge clock) begin
    if (current_state == 2) begin
        patch_x[ncon] <= left[ncon];
        patch_y[ncon] <= top[ncon];
    end else if (current_state == 12) begin
        if (at_right) begin
            patch_x[ncon] <= left[ncon];
            patch_y[ncon] <= patch_y[ncon] + 1;
        end else begin
            patch_x[ncon] <= patch_x[ncon] + 1;
        end
    end
end

endmodule

module rasterizer_H6
    #(parameter BASE_ADDRESS = 1)
    (input clock,
    input reset,
    input [3:0] io_address,
    input [31:0] io_write_data,
    output reg [31:0] io_read_data,
    input io_write_en,
    input io_read_en);

wire [31:0] data_l;
reg [5:0] io_address_r;
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

rasterizer_unit_H6 ru0 (clock, reset, io_address_r[3:0], io_address_r[5:4], 
    io_write_data_r, data_l, io_write_en_r, io_read_en_r);

endmodule

/*module rasterizer_H6
    #(parameter BASE_ADDRESS = 1)
    (input clock,
    input reset,
    input [31:0] io_address,
    input [31:0] io_write_data,
    output reg [31:0] io_read_data,
    input io_write_en,
    input io_read_en);

wire [1:0] which_unit = io_address[7:6];
wire valid_io = io_address[31:8] == BASE_ADDRESS;
wire [3:0] reg_addr = io_address[5:2];

wire read0 = io_read_en && valid_io;
wire write0 = io_write_en && valid_io;

rasterizer_unit_H6 ru0 (clock, reset, reg_addr, which_unit, io_write_data, io_read_data, write0, read0);

endmodule*/

