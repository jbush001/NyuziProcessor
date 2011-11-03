module text_display(
	input wire 				clk,
	output reg[3:0] 		red_o,
	output reg[3:0] 		green_o,
	output reg[3:0] 		blue_o,
	output wire 			vsync_o,
	output wire 			hsync_o,
	input wire[7:0] 		char_i,
	input 					char_avail_i);

	wire[9:0] 				x_coord;
	wire[9:0] 				y_coord;
	reg[7:0] 				chcode;
	wire[7:0] 				chline;
	wire[6:0] 				chx;
	wire[6:0] 				chy;
	wire[12:0] 				chram_read_index;
	wire[12:0] 				chram_write_index;
	wire 					character_active;
	reg[6:0] 				cursor_x;
	reg[6:0] 				cursor_y;
	reg[4:0] 				blink;
	wire 					in_visible_region;
	reg[7:0] 				text_ram[0:4799];
	reg						dotclk;

	always @(posedge clk)
		dotclk = ~dotclk;

	vga_timing_generator vtg(
		.dotclk(dotclk),
		.vsync_o(vsync_o),
		.hsync_o(hsync_o),
		.in_visible_region(in_visible_region),
		.x_coord(x_coord),
		.y_coord(y_coord));

	character_rom chrom(
		.code_i({ chcode, y_coord[2:0] }), 
		.line_o(chline));

	assign chx = x_coord[9:3];
	assign chy = y_coord[9:3];
	assign chram_read_index = { chy, 4'b0000 } + { chy, 6'b000000 } + chx;
	assign chram_write_index = { cursor_y, 4'b0000 } + { cursor_y, 6'b000000 } 
		+ cursor_x;

	always @(posedge dotclk)
		chcode <= text_ram[chram_read_index]; 

	always @(posedge clk)
	begin
		if (char_avail_i)
		begin
			text_ram[chram_write_index] <= char_i;
			if (cursor_x != 80 && char_i != 'h10)
				cursor_x <= cursor_x + 1;
			else
			begin
				cursor_x <= 0;
				if (cursor_y != 60)
					cursor_y <= cursor_y + 1;
				else
					cursor_y <= 0;
			end
		end
	end

	assign character_active = ((chline >> x_coord[2:0]) & 1) != 0;
	assign cursor_active = chx == cursor_x && chy == cursor_y
		&& blink[4] && (x_coord[0] ^ y_coord[0]);

	always @(posedge dotclk)
	begin
		if (x_coord == 0 && y_coord == 0)
			blink <= blink + 1;
	end
	
	always @(posedge dotclk)
	begin
		if ((cursor_active ^ character_active) && in_visible_region)
		begin
			red_o <= 0;
			green_o <= 4'b1111;
			blue_o <= 0;
		end
		else
		begin
			red_o <= 0;
			green_o <= 0;
			blue_o <= 0;
		end
	end
endmodule
