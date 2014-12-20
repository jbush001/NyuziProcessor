//
// Copyright (C) 2014 Jeff Bush
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

#include <iostream>
#include "Vverilator_tb.h"
#include "verilated.h"
#if VM_TRACE
#include <verilated_vcd_c.h>  
#endif
using namespace std;

vluint64_t currentTime = 0;  

double sc_time_stamp()
{
	return currentTime;
}

int main(int argc, char **argv, char **env) 
{
	unsigned int randomSeed;
	
	Verilated::commandArgs(argc, argv);
	Verilated::debug(0);

    if (VL_VALUEPLUSARGS_II(32 ,"randseed=",'d', randomSeed))
		srand48(randomSeed);
	else
	{
		time_t t1;
		time(&t1);
		srand48((long) t1);
		VL_PRINTF("Random seed is %li\n", t1);
	}
	
	Verilated::randReset(2);	// Initialize all registers to random

	Vverilator_tb* testbench = new Vverilator_tb;
	testbench->reset = 1;

#if VM_TRACE			// If verilator was invoked with --trace
	Verilated::traceEverOn(true);
	VL_PRINTF("Enabling waves...\n");
	VerilatedVcdC* tfp = new VerilatedVcdC;
	testbench->trace(tfp, 99);
	tfp->open("trace.vcd");
#endif

	while (!Verilated::gotFinish()) 
	{
		if (currentTime > 10)
			testbench->reset = 0;   // Deassert reset
		
		// Toggle clock
		testbench->clk = !testbench->clk;
		testbench->eval(); 
#if VM_TRACE
		if (tfp) 
			tfp->dump(currentTime);	// Create waveform trace for this timestamp
#endif

		currentTime++; 
	}
	
#if VM_TRACE
	if (tfp) 
		tfp->close();
#endif
    	
	testbench->final();
	delete testbench;
	exit(0);
}

// This is invoked directly from verilator_tb, as there isn't a builtin method
// to write binary data in verilog.
void fputw(IData fileid, int value)
{
	FILE *fp = VL_CVT_I_FP(fileid);

	int swapped = ((value & 0xff000000) >> 24)
		| ((value & 0x00ff0000) >> 8)
		| ((value & 0x0000ff00) << 8)
		| ((value & 0x000000ff) << 24);

	fwrite(&swapped, 1, 4, fp);
}


