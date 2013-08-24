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
	Vverilator_top* top = new Vverilator_top;
	top->reset = 1;

	while (!Verilated::gotFinish()) 
	{
		if (currentTime > 10)
			top->reset = 0;   // Deassert reset

		// Toggle clock
		if ((currentTime % 10) == 1)
			top->clk = 1;
		else if ((currentTime % 10) == 6)
			top->clk = 0;

		top->eval(); 
		currentTime++; 
	}
	
	top->final();
	delete top;
	exit(0);
}
      