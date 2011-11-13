#include <stdio.h>
#include <getopt.h>
#include <string.h>
#include "symbol_table.h"
#include "debug_info.h"
#include "code_output.h"

int parseSourceFile(const char *filename);

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


int main(int argc, char *argv[])
{
	int c;
	char outputFile[256];
	char debugFilename[256];
	int index;
	
	while ((c = getopt(argc, argv, "o:")) != -1)
	{
		switch (c)
		{
			case 'o':
				strcpy(outputFile, optarg);
				break;
		}
	}

	if (outputFile == NULL)
	{
		printf("enter an output filename with -o\n");
		return 1;
	}

	if (index == argc)
	{
		fprintf(stderr, "No source files\n");
		return 1;
	}
	
	getBasename(debugFilename, outputFile);
	strcat(debugFilename, ".dbg");

	createSymbol("ball", SYM_KEYWORD, BRANCH_ALL);
	createSymbol("bzero", SYM_KEYWORD, BRANCH_ZERO);
	createSymbol("bfalse", SYM_KEYWORD, BRANCH_ZERO);
	createSymbol("bnzero", SYM_KEYWORD, BRANCH_NOT_ZERO);
	createSymbol("btrue", SYM_KEYWORD, BRANCH_NOT_ZERO);
	createSymbol("goto", SYM_KEYWORD, BRANCH_ALWAYS);
	createSymbol("call", SYM_KEYWORD, BRANCH_CALL);
	createSymbol("clz", SYM_KEYWORD, OP_CLZ);
	createSymbol("sftoi", SYM_KEYWORD, OP_SFTOI);
	createSymbol("sitof", SYM_KEYWORD, OP_SITOF);
	createSymbol("floor", SYM_KEYWORD, OP_FLOOR);
	createSymbol("frac", SYM_KEYWORD, OP_FRAC);
	createSymbol("reciprocal", SYM_KEYWORD, OP_RECIP);
	createSymbol("abs", SYM_KEYWORD, OP_ABS);
	createSymbol("sqrt", SYM_KEYWORD, OP_SQRT);

	createSymbol("pc", SYM_REGISTER_ALIAS, 31);
	createSymbol("link", SYM_REGISTER_ALIAS, 30);
	createSymbol("sp", SYM_REGISTER_ALIAS, 29);


	if (openDebugInfo(debugFilename) < 0)
	{
		fprintf(stderr, "error opening debug file\n");
		return 1;
	}
	
	if (openOutputFile(outputFile) < 0)
	{
		fprintf(stderr, "error opening output file\n");
		return 1;
	}

	// The first instruction is a jump to the entry point.
	debugInfoSetSourceFile("start.asm");
	codeOutputSetSourceFile("start.asm");
	emitEInstruction(createSymbol("_start", SYM_LABEL, 0), NULL, BRANCH_ALWAYS, 0);
	
	for (index = optind; index < argc; index++)
	{
		if (parseSourceFile(argv[index]) < 0)
			return 1;
	}
	
	adjustFixups();
	closeDebugInfo();
	closeOutputFile();

	dumpSymbolTable();

	return 0;
}
