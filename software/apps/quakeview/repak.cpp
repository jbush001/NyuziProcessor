// 
// Copyright 2015 Jeff Bush
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

//
// .PAK files are fairly large, and most of the files in it are not needed by 
// this test program.  This is inconvenient when trying to transfer them to 
// the FPGA test environment. This utility creates a new .PAK file with a
// subset of files of the original.  The list of files to keep can be specified
// in the kKeepFiles variable below.
//
// gcc -o repak repack.cpp
// repak <original pak file>.pak pak0.pak
//
// The original pak file should not be in this directory if you
// are writing a file with the same name.
//

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct pakheader_t
{
	char id[4];
	uint32_t dirOffset;
	uint32_t dirSize;
};

struct pakfile_t
{
	char name[56];
	uint32_t offset;
	uint32_t size;
};

const char *kKeepFiles[] = {
	"maps/e1m1.bsp",
	"gfx/palette.lmp"
};

int main(int argc, const char *argv[])
{
	if (argc != 3)
	{
		printf("USAGE: repak <old file> <new file>\n");
		return 1;
	}
	
	FILE *inputFile = fopen(argv[1], "rb");
	if (!inputFile)
	{
		perror("can't open file");
		return 1;
	}
	
	pakheader_t header;
	if (fread(&header, sizeof(header), 1, inputFile) != 1)
	{
		perror("error reading file");
		return 1;
	}
	
	if (::memcmp(header.id, "PACK", 4) != 0)
	{
		printf("bad file type\n");
		return 1;
	}

	int numOldDirEntries = header.dirSize / sizeof(pakfile_t);
	pakfile_t *oldDirectory = new pakfile_t[numOldDirEntries];
	fseek(inputFile, header.dirOffset, SEEK_SET);
	if (fread(oldDirectory, header.dirSize, 1, inputFile) != 1)
	{
		perror("error reading directory");
		return 1;
	}
	
	printf("old PAK file has %d directory entries\n", numOldDirEntries);

	// Count how many files we are keeping
	int numKeepEntries = 0;
	for (const char **c = kKeepFiles; *c; c++)
		numKeepEntries++;

	pakfile_t *newDirectory = new pakfile_t[numKeepEntries];

	// Write out the new file
	FILE *outputFile = fopen(argv[2], "wb");
	if (!outputFile)
	{
		perror("Couldn't write output file");
		return 1;
	}
	
	// Write header
	pakheader_t newHeader;
	memcpy(newHeader.id, "PACK", 4);
	newHeader.dirOffset = sizeof(pakheader_t);
	newHeader.dirSize = sizeof(pakfile_t) * numKeepEntries;
	if (fwrite(&newHeader, sizeof(pakheader_t), 1, outputFile) != 1)
	{
		perror("fwrite failed");
		return 1;
	}
	
	int newDataOffset = numKeepEntries * sizeof(pakfile_t) + sizeof(pakheader_t);
	for (int newDirIndex = 0; kKeepFiles[newDirIndex]; newDirIndex++)
	{
		strcpy(newDirectory[newDirIndex].name, kKeepFiles[newDirIndex]);
		newDirectory[newDirIndex].offset = newDataOffset;
		
		// Search the old directory to find this file
		bool foundOldEntry = false;
		for (int i = 0; i < numOldDirEntries; i++)
		{
			if (strcmp(oldDirectory[i].name, kKeepFiles[newDirIndex]) == 0)
			{
				printf("copying %s\n", oldDirectory[i].name);
				newDirectory[newDirIndex].size = oldDirectory[i].size;
				void *tmp = malloc(oldDirectory[i].size);

				if (fseek(inputFile, oldDirectory[i].offset, SEEK_SET))
				{
					perror("error seeking old file");
					return 1;
				}

				if (fread(tmp, oldDirectory[i].size, 1, inputFile) != 1)
				{
					perror("error reading old file");
					return 1;
				}
				
				if (fseek(outputFile, newDataOffset, SEEK_SET))
				{
					perror("error seeking new file");
					return 1;
				}

				if (fwrite(tmp, oldDirectory[i].size, 1, outputFile) != 1)
				{
					perror("error writing new file");
					return 1;
				}
				
				free(tmp);
				foundOldEntry = true;
				newDataOffset += oldDirectory[i].size;
				break;
			}
		}
		
		if (!foundOldEntry)
		{
			printf("Couldn't find %s in original file\n", kKeepFiles[newDirIndex]);
			return 1;
		}
	}
	
	// Go back and write the directory
	if (fseek(outputFile, sizeof(pakheader_t), SEEK_SET))
	{
		perror("error seeking in output file");
		return 1;
	}
	
	if (fwrite(newDirectory, sizeof(pakfile_t), numKeepEntries, outputFile) != numKeepEntries)
	{
		perror("failed to write directory");
		return 1;
	}
	
	fclose(inputFile);
	fclose(outputFile);
	
		
	return 0;
}
