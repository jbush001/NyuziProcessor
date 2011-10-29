#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "debug_info.h"

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
	int length;
	int filenameIndex;
	int startLine;
};

struct SourcePath
{
	int filenameIndex;
	struct SourcePath *next;
	char name[1];
};

static int lastLine = -1;
static int lastProgramCounter = 0;
static int runStartLine;
static int runStartProgramCounter;
static FILE *debugFile;
static int numLineRuns;
static struct SourcePath *pathListHead;
static struct SourcePath *pathListTail;
static int nextPathIndex;
static int currentPathIndex;

static int getPathIndex(const char *filename)
{
	struct SourcePath *path;
	
	for (path = pathListHead; path; path = path->next)
	{
		if (strcmp(path->name, filename) == 0)
			return path->filenameIndex;
	}

	path = (struct SourcePath*) malloc(sizeof(struct SourcePath) + strlen(filename));
	strcpy(path->name, filename);
	path->filenameIndex = nextPathIndex;
	nextPathIndex += strlen(filename) + 1;
	if (pathListHead == NULL)
		pathListHead = path;
	else
		pathListTail->next = path;
	
	pathListTail = path;
	path->next = NULL;
	
	return path->filenameIndex;
}

static void writeRun(void)
{
	if (lastLine != -1)
	{
		const struct LineRun run = {
			startAddress : runStartProgramCounter,
			length : lastLine - runStartLine + 1,
			filenameIndex : currentPathIndex,
			startLine : runStartLine
		};
		
		fwrite(&run, sizeof(run), 1, debugFile);
		numLineRuns++;
	}
}

int openDebugInfo(const char *filename)
{
	debugFile = fopen(filename, "w");
	fseek(debugFile, sizeof(struct DebugFileHeader), SEEK_SET); 

	return debugFile != NULL ? 0 : -1;
}

void closeDebugInfo()
{
	struct SourcePath *path;

	writeRun();

	const struct DebugFileHeader header = {
		magic : 0x12345678,
		numLineRuns : numLineRuns,
		stringTableSize : nextPathIndex
	};


	// Write the file path table
	for (path = pathListHead; path; path = path->next)
		fwrite(path->name, strlen(path->name) + 1, 1, debugFile);

	fseek(debugFile, 0, SEEK_SET);
	fwrite(&header, sizeof(header), 1, debugFile);
	
	fclose(debugFile);
}

void debugInfoSetSourceFile(const char *filename)
{
	int newPathIndex = getPathIndex(filename);
	if (newPathIndex != currentPathIndex)
	{
		writeRun();
		currentPathIndex = newPathIndex;
	}
}

void addLineMapping(int programCounter, int line)
{
	if ((line != lastLine + 1
		|| programCounter != lastProgramCounter + 4))
	{
		writeRun();
		runStartLine = line;
		runStartProgramCounter = programCounter;
	}

	lastProgramCounter = programCounter;
	lastLine = line;
}

