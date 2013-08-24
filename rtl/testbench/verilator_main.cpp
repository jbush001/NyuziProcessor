#include <stdio.h>
#include "Vgpgpu.h"
#include "verilated.h"

int main(int argc, char **argv, char **env) 
{
	Verilated::commandArgs(argc, argv);
	Vgpgpu* top = new Vgpgpu;
	while (!Verilated::gotFinish()) 
	{
		printf("cycle\n"); 
		top->eval(); 
	}
	
	delete top;
	exit(0);
}
      