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
// This utility creates a simple read-only filesystem that is exposed by
// software/libs/libos/fs.c
//

#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define FS_NAME_LEN 32
#define BLOCK_SIZE 512
#define FS_MAGIC "spfs"
#define ROUND_UP(x, y) (((x + y - 1) / y) * y)

typedef struct DirectoryEntry DirectoryEntry;
typedef struct FsHeader FsHeader;

struct DirectoryEntry
{
	unsigned int startOffset;
	unsigned int length;
	char name[FS_NAME_LEN];
};

struct FsHeader
{
	char magic[4];
	unsigned int numDirectoryEntries;
	DirectoryEntry dir[1];
};

static void normalizeFileName(char outName[32], const char *fullPath);
	
int main(int argc, const char *argv[])
{
	unsigned int fileIndex;
	unsigned fileOffset;
	unsigned int numDirectoryEntries = (unsigned int) argc - 2;
	FsHeader *header;
	FILE *outputFp;
	size_t headerSize;

	if (argc < 2)
	{
		fprintf(stderr, "USAGE: %s <output file> <source file1> [<source file2>...]\n", argv[0]);
		return 1;
	}

	outputFp = fopen(argv[1], "wb");
	if (outputFp == NULL)
	{
		perror("error creating output file");
		return 1;
	}

	fileOffset = ROUND_UP((numDirectoryEntries - 1) * sizeof(DirectoryEntry) 
		+ sizeof(FsHeader), BLOCK_SIZE);
	printf("first file offset = %d\n", fileOffset);
	headerSize = sizeof(FsHeader) + sizeof(DirectoryEntry) * (numDirectoryEntries - 1);
	header = (FsHeader*) malloc(headerSize);
	
	// Build the directory
	for (fileIndex = 0; fileIndex < numDirectoryEntries; fileIndex++)
	{
		struct stat st;
		
		if (stat(argv[fileIndex + 2], &st) < 0)
		{
			fprintf(stderr, "error opening %s\n", argv[fileIndex + 2]);
			return 1;
		}
		
		header->dir[fileIndex].startOffset = fileOffset;
		header->dir[fileIndex].length = (unsigned int) st.st_size;
		normalizeFileName(header->dir[fileIndex].name, argv[fileIndex + 2]);
		printf("Adding %s %08x %08x\n", header->dir[fileIndex].name, header->dir[fileIndex].startOffset, 
			header->dir[fileIndex].length);
		fileOffset = ROUND_UP(fileOffset + (unsigned int) st.st_size, BLOCK_SIZE);
	}

	memcpy(header->magic, FS_MAGIC, 4);
	header->numDirectoryEntries = numDirectoryEntries;

	if (fwrite(header, headerSize, 1, outputFp) != 1)
	{
		perror("error writing header");
		return 1;
	}

	// Copy file contents
	for (fileIndex = 0; fileIndex < numDirectoryEntries; fileIndex++)
	{
		char tmp[0x4000];
		fseek(outputFp, header->dir[fileIndex].startOffset, SEEK_SET);
		FILE *sourceFp = fopen(argv[fileIndex + 2], "rb");
		unsigned int leftToCopy = header->dir[fileIndex].length;
		while (leftToCopy > 0)
		{
			unsigned int sliceLength = sizeof(tmp);
			if (leftToCopy < sliceLength)
				sliceLength = leftToCopy;

			if (fread(tmp, sliceLength, 1, sourceFp) != 1)
			{
				perror("error reading from source file");
				return 1;
			}
			
			if (fwrite(tmp, sliceLength, 1, outputFp) != 1)
			{
				perror("error writing to output file");
				return 1;
			}
			
			leftToCopy -= sliceLength;
		}

		fclose(sourceFp);
	}
	
	fclose(outputFp);
	
	return 0;
}

void normalizeFileName(char outName[32], const char *fullPath)
{
	const char *end = fullPath + strlen(fullPath) - 1;
	const char *begin = end;
	while (begin > fullPath && begin[-1] != '/')
		begin--;

	if (end - begin > FS_NAME_LEN - 1)
	{
		// Truncate
		begin = end - (FS_NAME_LEN -1);
	}
	
	strcpy(outName, begin);
}
