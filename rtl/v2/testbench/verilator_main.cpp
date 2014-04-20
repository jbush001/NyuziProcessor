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
	Verilated::commandArgs(argc, argv);
    Verilated::debug(0);

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


