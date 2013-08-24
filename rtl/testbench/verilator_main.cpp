#include <iostream>
#include "Vgpgpu.h"
#include "verilated.h"

using namespace std;

vluint64_t currentTime = 0;  

int main(int argc, char **argv, char **env) 
{
	Verilated::commandArgs(argc, argv);
	Vgpgpu* top = new Vgpgpu;
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
		cout << (int) top->axi_arvalid << endl; 
		currentTime++; 
	}
	
	top->final();
	delete top;
	exit(0);
}
      