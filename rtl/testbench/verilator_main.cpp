// 
// Copyright 2013 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
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


