// 
// Copyright 2011-2015 Jeff Bush
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

namespace {
	vluint64_t currentTime = 0;  
}

// Called whenever the $time variable is accessed.
double sc_time_stamp()
{
	return currentTime;
}

int main(int argc, char **argv, char **env) 
{
	unsigned int randomSeed;
	
	Verilated::commandArgs(argc, argv);
	Verilated::debug(0);

	// Initialize random seed.
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

	return 0;
}
