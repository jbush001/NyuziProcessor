module fpga_target(
	input clk50,
	input key0,
	input sw0,
	output [3:0] red_o,
	output [3:0] green_o,
	output [3:0] blue_o,
	output vsync_o,
	output hsync_o);

	wire[7:0] _debug_char;
	wire _charavail;
	reg charavail;
	wire[31:0] ddata_to_mem;
	wire[31:0] ddata_from_mem;
	wire[31:0] iaddr;
	wire[31:0] daddr;
	wire[31:0] idata;
	wire[3:0] dsel;
	wire dreq;
	wire dwrite;
	wire ireq;
	reg dack;
	wire coreclk;
	reg oneshot;
	reg[2:0] debounce;
	reg[31:0] latched_data_address;
	reg latched_dreq;
	
	initial
	begin
		charavail = 0;
		dack = 0;
		debounce = 0;
		oneshot = 0;
		latched_data_address = 0;
		latched_dreq = 0;
	end

	dp_ram ram(
		.address_a(iaddr[14:2]),
		.address_b(latched_data_address[14:2]),
		.byteena_b(dsel),
		.clock(coreclk),
		.data_a(0),
		.data_b(ddata_to_mem),
		.wren_a(0),
		.wren_b(latched_dreq && dwrite && ~charavail),
		.q_a(idata),
		.q_b(ddata_from_mem));

	always @(posedge coreclk)
	begin
		latched_data_address <= daddr;	// XXX one cycle of latency for tag check
		latched_dreq <= dreq;
	end
		
	pipeline pip(
		.clk(coreclk),
		.iaddress_o(iaddr),
		.idata_i(idata),
		.iaccess_o(ireq),
		.daddress_o(daddr),
		.daccess_o(dreq),
		.dcache_hit_i(dack),
		.dwrite_o(dwrite),
		.dsel_o(dsel),
		.ddata_o(ddata_to_mem),
		.ddata_i(ddata_from_mem));
	
	text_display td(
		.clk(clk50),
		.red_o(red_o),
		.green_o(green_o),
		.blue_o(blue_o),
		.vsync_o(vsync_o),
		.hsync_o(hsync_o),
		.char_i(_debug_char),
		.char_avail_i(_charavail));

	always @(posedge coreclk)
	begin
		dack <= dreq;
	end

	always @*
	begin
		if (daddr == 32'ha0000000 && dreq && dwrite)
			charavail = 1;
		else
			charavail = 0;
	end

	reg toggle1;
	reg toggle2;

	assign coreclk = sw0 ? oneshot : clk50;

	always @(posedge clk50)
	begin
		debounce <= { debounce[1:0], key0 };
		oneshot <= ~debounce[2] & debounce[1];
	end

	reg[5:0] display_state;
	initial
		display_state = 0;
	
	always @(posedge clk50)
	begin
		if (display_state == 0)
		begin
			if (oneshot)
				display_state <= 1;
		end
		else
		begin
			if (display_state == 49)
				display_state <= 0;
			else
				display_state <= display_state + 1;
		end
	end

	function[7:0] tohex;
		input[3:0] val;
		
		begin
			if (val > 9)
				tohex = (val - 8'd10 + 8'h41);
			else
				tohex = val + 8'h30;
		end
	endfunction

	assign _debug_char = sw0 ? debug_char : ddata_to_mem[31:24];
	assign _charavail = sw0 ? display_state != 0 : charavail;
	reg[7:0] debug_char;

	always @*
	begin
		case (display_state)
			1:	debug_char = tohex(iaddr[31:28]);
			2:	debug_char = tohex(iaddr[27:24]);
			3:	debug_char = tohex(iaddr[23:20]);
			4:	debug_char = tohex(iaddr[19:16]);
			5:	debug_char = tohex(iaddr[15:12]);
			6:	debug_char = tohex(iaddr[11:8]);
			7:	debug_char = tohex(iaddr[7:4]);
			8:	debug_char = tohex(iaddr[3:0]);


			10:	debug_char = tohex(idata[31:28]);
			11:	debug_char = tohex(idata[27:24]);
			12:	debug_char = tohex(idata[23:20]);
			13:	debug_char = tohex(idata[19:16]);
			14:	debug_char = tohex(idata[15:12]);
			15:	debug_char = tohex(idata[11:8]);
			16:	debug_char = tohex(idata[7:4]);
			17:	debug_char = tohex(idata[3:0]);

			19:	debug_char = tohex(daddr[31:28]);
			20:	debug_char = tohex(daddr[27:24]);
			21:	debug_char = tohex(daddr[23:20]);
			22:	debug_char = tohex(daddr[19:16]);
			23:	debug_char = tohex(daddr[15:12]);
			24:	debug_char = tohex(daddr[11:8]);
			25:	debug_char = tohex(daddr[7:4]);
			26:	debug_char = tohex(daddr[3:0]);

			28:	debug_char = tohex(ddata_to_mem[31:28]);
			29:	debug_char = tohex(ddata_to_mem[27:24]);
			30:	debug_char = tohex(ddata_to_mem[23:20]);
			31:	debug_char = tohex(ddata_to_mem[19:16]);
			32:	debug_char = tohex(ddata_to_mem[15:12]);
			33:	debug_char = tohex(ddata_to_mem[11:8]);
			34:	debug_char = tohex(ddata_to_mem[7:4]);
			35:	debug_char = tohex(ddata_to_mem[3:0]);


			37:	debug_char = tohex(ddata_from_mem[31:28]);
			38:	debug_char = tohex(ddata_from_mem[27:24]);
			39:	debug_char = tohex(ddata_from_mem[23:20]);
			40:	debug_char = tohex(ddata_from_mem[19:16]);
			41:	debug_char = tohex(ddata_from_mem[15:12]);
			42:	debug_char = tohex(ddata_from_mem[11:8]);
			43:	debug_char = tohex(ddata_from_mem[7:4]);
			44:	debug_char = tohex(ddata_from_mem[3:0]);



			46: debug_char = dreq ? 'h31 : 'h30;

			48: debug_char = dwrite ? 'h31 : 'h30;
			49: debug_char = 'h10;
			default: debug_char = 0;
		endcase
	end

endmodule
