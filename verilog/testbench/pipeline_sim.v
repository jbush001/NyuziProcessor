`include "timescale.v"

module pipeline_sim;

	reg clk;
	wire[31:0] iaddr;
	wire[31:0] idata;
	wire iaccess;
	wire[31:0] daddr;
	wire[31:0] ddata_to_mem;
	wire[31:0] ddata_from_mem;
	wire dwrite;
	wire daccess;
	wire[3:0] dsel;
	wire dack;

	sim_cache cache(
		.clk(clk),
		.iaddress_i(iaddr),
		.idata_o(idata),
		.iaccess_i(iaccess),
		.daddress_i(daddr),
		.ddata_o(ddata_from_mem),
		.ddata_i(ddata_to_mem),
		.dwrite_i(dwrite),
		.daccess_i(daccess),
		.dsel_i(dsel),
		.dack_o(dack));

	pipeline p(
		.clk(clk),
		.iaddress_o(iaddr),
		.idata_i(idata),
		.iaccess_o(iaccess),
		.dcache_hit_i(dack),
		.daddress_o(daddr),
		.ddata_i(ddata_from_mem),
		.ddata_o(ddata_to_mem),
		.dwrite_o(dwrite),
		.daccess_o(daccess),
		.dsel_o(dsel));

	integer i;
 	reg[1000:0] filename;
	reg[31:0] vectortmp[0:16 * 32];
	integer do_dump;
 
	initial
	begin
		// Load executable binary into memory
        if ($value$plusargs("bin=%s", filename))
            $readmemh(filename, cache.data);
        else
        begin
            $display("error opening file");
            $finish;
        end

		do_dump = 0;

		// If initial values are passed for scalar registers, load those now
		if ($value$plusargs("sreg=%s", filename))
		begin
			$readmemh(filename, p.srf.registers);
			do_dump = 1;
		end

		// Likewise for vector registers
		if ($value$plusargs("vreg=%s", filename))
		begin
			$readmemh(filename, vectortmp);
			for (i = 0; i < 32; i = i + 1)
			begin
				p.vrf.lane15[i] = vectortmp[i * 16];
				p.vrf.lane14[i] = vectortmp[i * 16 + 1];
				p.vrf.lane13[i] = vectortmp[i * 16 + 2];
				p.vrf.lane12[i] = vectortmp[i * 16 + 3];
				p.vrf.lane11[i] = vectortmp[i * 16 + 4];
				p.vrf.lane10[i] = vectortmp[i * 16 + 5];
				p.vrf.lane9[i] = vectortmp[i * 16 + 6];
				p.vrf.lane8[i] = vectortmp[i * 16 + 7];
				p.vrf.lane7[i] = vectortmp[i * 16 + 8];
				p.vrf.lane6[i] = vectortmp[i * 16 + 9];
				p.vrf.lane5[i] = vectortmp[i * 16 + 10];
				p.vrf.lane4[i] = vectortmp[i * 16 + 11];
				p.vrf.lane3[i] = vectortmp[i * 16 + 12];
				p.vrf.lane2[i] = vectortmp[i * 16 + 13];
				p.vrf.lane1[i] = vectortmp[i * 16 + 14];
				p.vrf.lane0[i] = vectortmp[i * 16 + 15];
			end
			
			do_dump = 1;
		end

		// Open a trace file
		if ($value$plusargs("trace=%s", filename))
		begin
			$dumpfile(filename);
			$dumpvars(100, p);
			$dumpvars(100, cache);
		end
	
		// Run simulation for some number of cycles
		clk = 0;
		for (i = 0; i < 500; i = i + 1)
			#5 clk = ~clk;

		if (do_dump)
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
	end
endmodule
