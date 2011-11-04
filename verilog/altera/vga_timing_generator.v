module vga_timing_generator(
	input dotclk, 
	output reg vsync_o, 
	output reg hsync_o, 
	output in_visible_region, 
	output [9:0] x_coord, 
	output [9:0] y_coord);

	// 640x480 @60 hz.  Pixel clock = 25.175 Mhz Vert Refresh = 31.46875 kHz
	// Horizontal timing:
	// front porch 16 clocks
	// sync pulse 96 clocks
	// back porch 48 clocks
	// visible area 640 clocks
	// total 800 clocks
	//
	// Vertical timing:
	// front porch 10 lines
	// sync pulse 2 lines
	// back porch 33 lines
	// visible area 480 lines
	// total 525 lines
	parameter HSYNC_START = 16;						// Front Porch
	parameter HSYNC_END = HSYNC_START + 96;
	parameter HVISIBLE_START = HSYNC_END + 48;		// Back Porch
	parameter HVISIBLE_END = HVISIBLE_START + 640;
	parameter VSYNC_START = 10;						// Front Porch
	parameter VSYNC_END = VSYNC_START + 2;
	parameter VVISIBLE_START = VSYNC_END + 33;		// Back Porch
	parameter VVISIBLE_END = VVISIBLE_START + 480;
	
	reg hvisible;
	reg vvisible;
	reg[10:0] horizontal_counter;
	reg[10:0] vertical_counter;
	
	assign in_visible_region = hvisible && vvisible;
	assign x_coord = horizontal_counter - HVISIBLE_START;
	assign y_coord = vertical_counter - VVISIBLE_START;
	
	initial
	begin
		vsync_o = 0; 
		hsync_o = 0; 
		hvisible = 0;
		vvisible = 0;
		horizontal_counter = 0;
		vertical_counter = 0;
	end

	always @(posedge dotclk)
	begin
		// Counters
		if (horizontal_counter == HVISIBLE_END)
		begin
			horizontal_counter <= 0;
			hvisible <= 0;
			if (vertical_counter == VVISIBLE_END)
			begin
				vvisible <= 0;
				vertical_counter <= 0;
			end
			else 
				vertical_counter <= vertical_counter + 1;
		end
		else
			horizontal_counter <= horizontal_counter + 1;

		if (vertical_counter == VSYNC_START)
			vsync_o <= 0;
		else if (vertical_counter == VSYNC_END)
			vsync_o <= 1;
		else if (vertical_counter == VVISIBLE_START)
			vvisible <= 1;

		if (horizontal_counter == HSYNC_START)
			hsync_o <= 0;
		else if (horizontal_counter == HSYNC_END)
			hsync_o <= 1;
		else if (horizontal_counter == HVISIBLE_START)
			hvisible <= 1;
	end
endmodule
