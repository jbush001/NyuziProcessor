#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/resource.h>
#include "core.h"

void getBasename(char *outBasename, const char *filename)
{
	const char *c = filename + strlen(filename) - 1;
	while (c > filename)
	{
		if (*c == '.')
		{
			memcpy(outBasename, filename, c - filename);
			outBasename[c - filename] = '\0';
			return;
		}
	
		c--;
	}

	strcpy(outBasename, filename);
}

int main(int argc, const char *argv[])
{
	int i;
	Core *core;
	char debugFilename[256];
    struct rlimit limit;
	int interactive = 0;

	// Enable coredumps for this process
	limit.rlim_cur = RLIM_INFINITY;
	limit.rlim_max = RLIM_INFINITY;
	setrlimit(RLIMIT_CORE, &limit);

	core = initCore();

	if (argc != 2)
	{
		printf("need to enter a image filename\n");
		return 1;
	}
	
	if (loadImage(core, argv[1]) < 0)
	{
		printf("*error reading image %s %s\n", argv[1], strerror(errno));
		return 1;
	}

	if (interactive)
	{
		getBasename(debugFilename, argv[1]);
		strcat(debugFilename, ".dbg");
		if (readDebugInfoFile() < 0)
		{
			printf("*error reading debug info file\n");
			return 1;
		}
	
		commandInterfaceReadLoop(core);
	}
	else
		runNonInteractive(core);
	
	return 0;
}
