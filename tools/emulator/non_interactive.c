//
// Non-interactive test runner just produces register traces and memory dumps
//

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/poll.h>
#include <stdarg.h>
#include "core.h"
#include "debug_info.h"

void runNonInteractive(Core *core)
{
	int i;

	enableTracing(core);
	for (i = 0; i < 20; i++)
	{
		if (!runQuantum(core))
			break;
	}
}
