//`define PIPELINE_ONLY

module pipeline_sim;

	reg clk;
	wire[31:0] iaddr;
	wire[31:0] idata;
	wire iaccess;
	wire icache_hit;
	wire[31:0] daddr;
	wire[511:0] ddata_to_mem;
	wire[511:0] ddata_from_mem;
	wire dwrite;
	wire daccess;
	wire[63:0] dwrite_mask;
	wire dcache_hit;
	integer i;
 	reg[1000:0] filename;
	reg[31:0] vectortmp[0:17 * 32 - 1];
	integer do_register_dump;
	integer mem_dump_start;
	integer mem_dump_length;
	reg[31:0] cache_dat;
	integer simulation_cycles;
	wire cache_load_complete;
	wire stbuf_full;
	wire processor_halt;

`ifdef PIPELINE_ONLY
	sim_l1cache l1cache(
		.clk(clk),
		.iaddress_i(iaddr),
		.idata_o(idata),
		.iaccess_i(iaccess),
		.daddress_i(daddr),
		.ddata_o(ddata_from_mem),
		.ddata_i(ddata_to_mem),
		.dwrite_i(dwrite),
		.daccess_i(daccess),
		.dwrite_mask_i(dwrite_mask),
		.dack_o(dcache_hit));
		
	assign stbuf_full = 0;
	assign cache_load_complete = 0;
	assign icache_hit = 1;
`else
	wire 			port0_read;
	wire 			port0_ack;
	wire [25:0] 	port0_addr;
	wire [511:0] 	port0_data;
	wire 			port1_write;
	wire 			port1_ack;
	wire [25:0] 	port1_addr;
	wire [511:0] 	port1_data;
	wire [63:0] 	port1_mask;
	wire 			port2_read;
	wire 			port2_ack;
	wire [25:0] 	port2_addr;
	wire [511:0] 	port2_data;

	sim_l2cache l2cache(
		.clk(clk),
		.port0_read_i(port0_read),
		.port0_ack_o(port0_ack),
		.port0_addr_i(port0_addr),
		.port0_data_o(port0_data),
		.port1_write_i(port1_write),
		.port1_ack_o(port1_ack),
		.port1_addr_i(port1_addr),
		.port1_data_i(port1_data),
		.port1_mask_i(port1_mask),
		.port2_read_i(port2_read),
		.port2_ack_o(port2_ack),
		.port2_addr_i(port2_addr),
		.port2_data_o(port2_data));

	l1_instruction_cache icache(
		.clk(clk),
		.address_i(iaddr),
		.access_i(iaccess),
		.data_o(idata),
		.cache_hit_o(icache_hit),
		.cache_load_complete_o(),
		.l2_read_o(port2_read),
		.l2_ack_i(port2_ack),
		.l2_addr_o(port2_addr),
		.l2_data_i(port2_data));

	l1_data_cache dcache(
		.clk(clk),
		.address_i(daddr),
		.data_o(ddata_from_mem),
		.data_i(ddata_to_mem),
		.write_i(dwrite),
		.access_i(daccess),
		.write_mask_i(dwrite_mask),
		.cache_hit_o(dcache_hit),
		.stbuf_full_o(stbuf_full),
		.cache_load_complete_o(cache_load_complete),
		.l2port0_read_o(port0_read),
		.l2port0_ack_i(port0_ack),
		.l2port0_addr_o(port0_addr),
		.l2port0_data_i(port0_data),
		.l2port1_write_o(port1_write),
		.l2port1_ack_i(port1_ack),
		.l2port1_addr_o(port1_addr),
		.l2port1_data_o(port1_data),
		.l2port1_mask_o(port1_mask));

`endif

	pipeline p(
		.clk(clk),
		.iaddress_o(iaddr),
		.idata_i(idata),
		.iaccess_o(iaccess),
		.icache_hit_i(icache_hit),
		.dcache_hit_i(dcache_hit),
		.daddress_o(daddr),
		.ddata_i(ddata_from_mem),
		.ddata_o(ddata_to_mem),
		.dwrite_o(dwrite),
		.daccess_o(daccess),
		.dwrite_mask_o(dwrite_mask),
		.dstbuf_full_i(stbuf_full),
		.cache_load_complete_i(cache_load_complete),
		.halt_o(processor_halt));
 
	initial
	begin
		// Load executable binary into memory
        if ($value$plusargs("bin=%s", filename))
		begin
`ifdef PIPELINE_ONLY
			$readmemh(filename, l1cache.data);
`else
            $readmemh(filename, l2cache.data);
`endif

		end
        else
        begin
            $display("error opening file");
            $finish;
        end

		do_register_dump = 0;

		// If initial values are passed for scalar registers, load those now
		if ($value$plusargs("initial_regs=%s", filename))
		begin
			$readmemh(filename, vectortmp);
			for (i = 0; i < 31; i = i + 1)		// ignore PC
				p.srf.registers[i] = vectortmp[i];

			for (i = 0; i < 32; i = i + 1)
			begin
				p.vrf.lane15[i] = vectortmp[(i + 2) * 16];
				p.vrf.lane14[i] = vectortmp[(i + 2) * 16 + 1];
				p.vrf.lane13[i] = vectortmp[(i + 2) * 16 + 2];
				p.vrf.lane12[i] = vectortmp[(i + 2) * 16 + 3];
				p.vrf.lane11[i] = vectortmp[(i + 2) * 16 + 4];
				p.vrf.lane10[i] = vectortmp[(i + 2) * 16 + 5];
				p.vrf.lane9[i] = vectortmp[(i + 2) * 16 + 6];
				p.vrf.lane8[i] = vectortmp[(i + 2) * 16 + 7];
				p.vrf.lane7[i] = vectortmp[(i + 2) * 16 + 8];
				p.vrf.lane6[i] = vectortmp[(i + 2) * 16 + 9];
				p.vrf.lane5[i] = vectortmp[(i + 2) * 16 + 10];
				p.vrf.lane4[i] = vectortmp[(i + 2) * 16 + 11];
				p.vrf.lane3[i] = vectortmp[(i + 2) * 16 + 12];
				p.vrf.lane2[i] = vectortmp[(i + 2) * 16 + 13];
				p.vrf.lane1[i] = vectortmp[(i + 2) * 16 + 14];
				p.vrf.lane0[i] = vectortmp[(i + 2) * 16 + 15];
			end
			
			do_register_dump = 1;
		end

		// Open a trace file
		if ($value$plusargs("trace=%s", filename))
		begin
			$dumpfile(filename);
			$dumpvars(100, p);
`ifdef PIPELINE_ONLY
			$dumpvars(100, l1cache);
`else
			$dumpvars(100, l2cache);
			$dumpvars(100, dcache);
			$dumpvars(100, icache);
`endif
		end
	
		// Run simulation for some number of cycles
		if (!$value$plusargs("simcycles=%d", simulation_cycles))
			simulation_cycles = 500;

		clk = 0;
		for (i = 0; i < simulation_cycles * 2 && !processor_halt; i = i + 1)
			#5 clk = ~clk;

		if (processor_halt)
			$display("***HALTED***");

		if (do_register_dump)
		begin
			$display("REGISTERS:");
			// Dump the registers
			for (i = 0; i < 32; i = i + 1)
				$display("%08x", p.srf.registers[i]);
	
			for (i = 0; i < 32; i = i + 1)
			begin
				$display("%08x", p.vrf.lane15[i]);
				$display("%08x", p.vrf.lane14[i]);
				$display("%08x", p.vrf.lane13[i]);
				$display("%08x", p.vrf.lane12[i]);
				$display("%08x", p.vrf.lane11[i]);
				$display("%08x", p.vrf.lane10[i]);
				$display("%08x", p.vrf.lane9[i]);
				$display("%08x", p.vrf.lane8[i]);
				$display("%08x", p.vrf.lane7[i]);
				$display("%08x", p.vrf.lane6[i]);
				$display("%08x", p.vrf.lane5[i]);
				$display("%08x", p.vrf.lane4[i]);
				$display("%08x", p.vrf.lane3[i]);
				$display("%08x", p.vrf.lane2[i]);
				$display("%08x", p.vrf.lane1[i]);
				$display("%08x", p.vrf.lane0[i]);
			end
		end
		
		// This doesn't really work right with the cache
		if ($value$plusargs("memdumpbase=%x", mem_dump_start)
			&& $value$plusargs("memdumplen=%x", mem_dump_length))
		begin
			$display("MEMORY:");
			for (i = 0; i < mem_dump_length; i = i + 4)
			begin
`ifdef PIPELINE_ONLY
				cache_dat = l1cache.data[(mem_dump_start + i) / 4];
`else
				cache_dat = l2cache.data[(mem_dump_start + i) / 4];
`endif
				$display("%02x", cache_dat[31:24]);
				$display("%02x", cache_dat[23:16]);
				$display("%02x", cache_dat[15:8]);
				$display("%02x", cache_dat[7:0]);
			end
		end
	end
endmodule
