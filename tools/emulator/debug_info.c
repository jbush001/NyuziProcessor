#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "debug_info.h"

//
// XXX copied from debug_info.c in assembler.  Should probably find a good
//  central header for this.
//
// The file consists of
//   FileHeader
//   LineRun[]
//   source paths (each null delimited)
//
struct DebugFileHeader
{
	int magic;
	int numLineRuns;
	int stringTableSize;
};

struct LineRun
{
	unsigned int startAddress;
	int length;		// Number of instructions (each instruction is 4 bytes)
	int filenameIndex;
	int startLine;
};

static struct LineRun *lineRunTable;
static int lineRunTableLength;
static char *stringTable;
static int stringTableSize;

int readDebugInfoFile(const char *path)
{
	FILE *file;
	struct DebugFileHeader header;
	
	file = fopen(path, "rb");
	if (file == NULL)
		return -1;
	
	if (fread(&header, sizeof(header), 1, file) != 1)
		return -1;

	lineRunTable = malloc(sizeof(struct LineRun) * header.numLineRuns);
	lineRunTableLength = header.numLineRuns;
	if (fread(lineRunTable, sizeof(struct LineRun), header.numLineRuns, file) != header.numLineRuns)
		return -1;
		
	stringTable = malloc(sizeof(char*) * header.stringTableSize);
	if (fread(stringTable, header.stringTableSize, 1, file) != 1)
		return -1;

	stringTableSize = header.stringTableSize;
	fclose(file);

	return 0;
}

void getCurrentFunction(int pc, char *outName, int length)
{
	strlcpy(outName, "main", length);
}

static struct LineRun *findRunByAddress(unsigned int pc)
{
	// Perform a binary search to find the record that contains this PC.
	unsigned int low = 0;
	unsigned int high = lineRunTableLength - 1;
	do
	{
		int mid = (low + high) / 2;
		struct LineRun *run = &lineRunTable[mid];
		if (pc < run->startAddress)
			high = mid - 1;
		else if (pc >= run->startAddress + run->length * 4)
			low = mid + 1;
		else
			return run;
	}
	while (low <= high);


	return NULL;
}

static struct LineRun *findRunByLocation(const char *filename, int line)
{
	int fileIndex;
	int runIndex;
	
	fileIndex = 0;
	while (fileIndex < stringTableSize)
	{
		const char *path = stringTable + fileIndex;
		if (strcmp(path, filename) == 0)
			break;
			
		fileIndex += strlen(path) + 1;
	}

	if (fileIndex == stringTableSize)
		return NULL;	// ERROR: couldn't find file
	
	for (runIndex = 0; runIndex < lineRunTableLength; runIndex++)
	{
		struct LineRun *run = &lineRunTable[runIndex];
		if (run->filenameIndex != fileIndex)
			continue;
	
		if (line >= run->startLine && line < run->startLine
			+ run->length)
		{
			return run;
		}
	}

	return NULL;
}

int getSourceLocationForAddress(unsigned int pc, const char **outFile, int *outLine)
{
	struct LineRun *run;
	
	run = findRunByAddress(pc);
	if (run == NULL)
		return 0;

	*outFile = stringTable + run->filenameIndex;
	*outLine = run->startLine + (pc - run->startAddress) / 4;

	return 1;
}

// The runs table is sorted by address. In most cases, this will also be
// ordered by file line, but not necessarily all.  As such, we'll do a slow
// sequential scan here.
unsigned int getAddressForSourceLocation(const char *filename, int line, int *outActualLine)
{
	struct LineRun *run;
	
	run = findRunByLocation(filename, line);
	if (run == NULL)
		return 0xffffffff;

	// XXX this should round to the next executable line if the line is between
	// runs

	if (outActualLine != NULL)
		*outActualLine = line;
		
	return run->startAddress + (line - run->startLine) * 4;
}

