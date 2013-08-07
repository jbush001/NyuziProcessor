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

//
// Convert a statically linked ELF executable into its in-memory representation
// and write it out in HEX format compatible with $readmemh
//

#include "elf.h"
#include <stdlib.h>
#include <stdio.h>

int main(int argc, const char *argv[])
{
	FILE *inputFile;
	FILE *outputFile;
	Elf32_Ehdr eheader;
	Elf32_Phdr *pheader;
	int totalSize;
	int segment;
	unsigned char *result;
	int i;
	
	if (argc != 3)
	{
		fprintf(stderr, "USAGE: <dest> <src>\n");
		return 1;
	}

	inputFile = fopen(argv[2], "rb");
	if (!inputFile)
	{
		perror("error opening input file");
		return 1;
	}

	if (fread(&eheader, sizeof(eheader), 1, inputFile) != 1)
	{
		perror("error reading header");
		return 1;
	}
	
	if (memcmp(eheader.e_ident, ELF_MAGIC, 4) != 0) 
	{
		fprintf(stderr, "not an elf file\n");
		return 1;
	}
	
	if (eheader.e_phoff == 0) 
	{
		fprintf(stderr, "file has no program header\n");
		return 1;
	}

	pheader = (Elf32_Phdr*) calloc(sizeof(Elf32_Phdr), eheader.e_phnum);
	fseek(inputFile, eheader.e_phoff, SEEK_SET);
	if (fread(pheader, sizeof(Elf32_Phdr), eheader.e_phnum, inputFile) != eheader.e_phnum)
	{
		perror("reading program header");
		return 1;
	}

	totalSize = pheader[eheader.e_phnum - 1].p_vaddr 
		+ pheader[eheader.e_phnum - 1].p_memsz; 
	result = calloc(totalSize, 1);
	if (!result)
	{
		fprintf(stderr, "not enough memory\n");
		return 1;
	}

	for (segment = 0; segment < eheader.e_phnum; segment++)
	{
		if (pheader[segment].p_type == PT_LOAD)
		{
			fseek(inputFile, pheader[segment].p_offset, SEEK_SET);
			if (fread(result + pheader[segment].p_vaddr, 1, pheader[segment].p_filesz,
				inputFile) != pheader[segment].p_filesz)
			{
				perror(fread);
				return 1;
			}
		}
	}

	// Convert the first word into a jump to the appropriate location
	*((unsigned int*) result) = 0xf6000000 | ((eheader.e_entry - 4) << 5);
		
	fclose(inputFile);
	
	outputFile = fopen(argv[1], "wb");
	if (!outputFile)
	{
		perror("error opening output file");
		return 1;
	}
	
	for (i = 0; i < totalSize; i++)
	{
		fprintf(outputFile, "%02x", result[i]);
		if ((i & 3) == 3)
			fprintf(outputFile, "\n");	
	}
	
	fclose(outputFile);
	
	return 0;
}
