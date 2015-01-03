// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 


//
// Display a 640x480 VGA display.  This is an AXI master that will DMA color data 
// from a memory framebuffer, hard coded at address 0x10000000 (32 BPP RGBA), 
// then send it to an ADV7123 VGA DAC with appropriate timing.
//

module vga_controller(
	input 					clk,
	input					reset,

	input                   fb_base_update_en,
	input [31:0]            fb_new_base,
	output logic            frame_toggle,

	// To DAC
	output [7:0]			vga_r,
	output [7:0]			vga_g,
	output [7:0]			vga_b,
	output 					vga_clk,
	output 					vga_blank_n,
	output 					vga_hs,
	output 					vga_vs,
	output 					vga_sync_n,
	
	// To AXI interconnect
	axi_interface.master    axi_bus);

	localparam TOTAL_PIXELS = 640 * 480;
	
	// We choose the burst length to be twice that of a CPU cache line fill 
	// to ensure we get sufficient memory bandwidth even when we are 
	// ping-ponging.
	localparam BURST_LENGTH = 64;
	localparam PIXEL_FIFO_LENGTH = 128;
	localparam DEFAULT_FB_ADDR = 32'h10000000;

	typedef enum {
		STATE_WAIT_FRAME_START,
		STATE_WAIT_FIFO_EMPTY,
		STATE_ISSUE_ADDR,
		STATE_BURST_ACTIVE
	} frame_state_t;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire		in_visible_region;	// From timing_generator of vga_timing_generator.v
	wire		new_frame;		// From timing_generator of vga_timing_generator.v
	logic		pixel_enable;		// From timing_generator of vga_timing_generator.v
	// End of automatics
	logic[31:0] vram_addr;
	wire[7:0] _ignore_alpha;
	wire pixel_fifo_empty;
	wire pixel_fifo_almost_empty;
	logic[31:0] fb_base_address;
	frame_state_t axi_state;
	logic[7:0] burst_count;
	logic[18:0] pixel_count;

	assign vga_blank_n = in_visible_region;
	assign vga_sync_n = 1'b0;	// Not used
	assign vga_clk = pixel_enable;	// This is a bid odd: using enable as external clock.

	// Buffers data to the display from SDRAM.  The enqueue threshold
	// is set to ensure there is capacity to enqueue an entire burst from memory.
	// Note that we clear the FIFO at the beginning of the vblank period to allow
	// it to resynchronize if there was an underrun.
	sync_fifo #(
		.WIDTH(32), 
		.SIZE(PIXEL_FIFO_LENGTH), 
		.ALMOST_EMPTY_THRESHOLD(PIXEL_FIFO_LENGTH - BURST_LENGTH - 1)) pixel_fifo(
		.clk(clk),
		.reset(reset),
		.flush_en(new_frame),
		.almost_full(),
		.empty(pixel_fifo_empty),
		.almost_empty(pixel_fifo_almost_empty),
		.value_o({vga_r, vga_g, vga_b, _ignore_alpha}),
		.value_i(axi_bus.rdata),
		.enqueue_en(axi_bus.rvalid),
		.full(),
		.dequeue_en(pixel_enable && in_visible_region && !pixel_fifo_empty));
		
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			fb_base_address <= DEFAULT_FB_ADDR;
			vram_addr <= DEFAULT_FB_ADDR;
			axi_state <= STATE_WAIT_FRAME_START;
			frame_toggle <= 0;
			
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			burst_count <= 8'h0;
			pixel_count <= 19'h0;
			// End of automatics
		end
		else 
		begin
			// Check for FIFO underrun
			assert(!(pixel_enable && in_visible_region && pixel_fifo_empty));
			
			if (fb_base_update_en)
				fb_base_address <= fb_new_base;
			
			unique case (axi_state)
				STATE_WAIT_FRAME_START:
				begin
					// Since we know the FIFO will be flushed with the new
					// frame, we can skip STATE_WAIT_FIFO_EMPTY.
					if (new_frame)
					begin
						axi_state <= STATE_ISSUE_ADDR;
						pixel_count <= 0;
						vram_addr <= fb_base_address;
						frame_toggle <= !frame_toggle;
					end
				end

				STATE_WAIT_FIFO_EMPTY:
				begin
					if (pixel_fifo_almost_empty)
						axi_state <= STATE_ISSUE_ADDR;
				end

				STATE_ISSUE_ADDR:
				begin
					if (axi_bus.arready)
						axi_state <= STATE_BURST_ACTIVE;				
				end

				STATE_BURST_ACTIVE:
				begin
					if (axi_bus.rvalid)
					begin
						if (burst_count == BURST_LENGTH - 1)
						begin
							burst_count <= 0;
							if (pixel_count == TOTAL_PIXELS - BURST_LENGTH)
								axi_state <= STATE_WAIT_FRAME_START;
							else
							begin
								if (pixel_fifo_almost_empty)
									axi_state <= STATE_ISSUE_ADDR;
								else
									axi_state <= STATE_WAIT_FIFO_EMPTY;
								
								vram_addr <= vram_addr + BURST_LENGTH * 4;
								pixel_count <= pixel_count + BURST_LENGTH;
							end
						end	
						else
							burst_count <= burst_count + 1;
					end
				end

				default: axi_state <= STATE_WAIT_FRAME_START;
			endcase
		end
	end
	
	assign axi_bus.rready = 1'b1;	// We always have enough room when a request is made.
	assign axi_bus.arlen = BURST_LENGTH - 1;
	assign axi_bus.arvalid = axi_state == STATE_ISSUE_ADDR;
	assign axi_bus.araddr = vram_addr;

	vga_timing_generator timing_generator(
		/*AUTOINST*/
					      // Outputs
					      .vga_vs		(vga_vs),
					      .vga_hs		(vga_hs),
					      .in_visible_region(in_visible_region),
					      .pixel_enable	(pixel_enable),
					      .new_frame	(new_frame),
					      // Inputs
					      .clk		(clk),
					      .reset		(reset));
endmodule


// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
