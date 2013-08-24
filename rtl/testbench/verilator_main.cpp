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
#include "Vverilator_top.h"
#include "verilated.h"

using namespace std;

vluint64_t currentTime = 0;  

int main(int argc, char **argv, char **env) 
{
	Verilated::commandArgs(argc, argv);
    Verilated::debug(0);

	Vverilator_top* top = new Vverilator_top;
	top->reset = 1;

#if VM_TRACE			// If verilator was invoked with --trace
    Verilated::traceEverOn(true);
    VL_PRINTF("Enabling waves...\n");
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("trace.vcd");
#endif

	while (!Verilated::gotFinish()) 
	{
		if (currentTime > 10)
			top->reset = 0;   // Deassert reset

		// Toggle clock
		top->clk = !top->clk;
		top->eval(); 
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
    	
	top->final();
	delete top;
	exit(0);
}
      