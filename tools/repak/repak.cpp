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

// .PAK is a proprietary file format for storing Quake level data.
// The .PAK file is big, and the quakeview test program only needs a few
// files from it. This is inconvenient when transfering it over the serial
// port in the FPGA test environment. This utility creates a new .PAK
// file with a subset of files from the original.

#include <getopt.h>
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

void usage()
{
    printf("repak <pak file> [<file to copy>] [<file to copy>] ...\n");
    printf("  -o <output file> file to write (defaults to pak0.pak)\n");
    printf("  -l               list all files in archive and exit\n");
}

int main(int argc, char * const argv[])
{
    int c;
    const char *outputFilename = "pak0.pak";
    int listFiles = 0;

    while ((c = getopt(argc, argv, "o:l?")) != -1)
    {
        switch (c)
        {
            case 'o':
                outputFilename = optarg;
                break;

            case 'l':
                listFiles = 1;
                break;

            case '?':
                usage();
                return 0;
        }
    }

    if (argc < optind + 2 && listFiles == 0)
    {
        fprintf(stderr, "Not enough arguments\n");
        usage();
        return 1;
    }

    FILE *inputFile = fopen(argv[optind], "rb");
    if (inputFile == NULL)
    {
        perror("can't open file");
        return 1;
    }

    pakheader_t header;
    if (fread(&header, sizeof(header), 1, inputFile) != 1)
    {
        perror("error reading file");
        fclose(inputFile);
        return 1;
    }

    if (::memcmp(header.id, "PACK", 4) != 0)
    {
        printf("bad file type\n");
        fclose(inputFile);
        return 1;
    }

    int numOldDirEntries = header.dirSize / sizeof(pakfile_t);
    pakfile_t *oldDirectory = new pakfile_t[numOldDirEntries];
    fseek(inputFile, header.dirOffset, SEEK_SET);
    if (fread(oldDirectory, header.dirSize, 1, inputFile) != 1)
    {
        delete [] oldDirectory;
        fclose(inputFile);
        perror("error reading directory");
        return 1;
    }

    if (listFiles)
    {
        printf("%d directory entries\n", numOldDirEntries);
        for (int i = 0; i < numOldDirEntries; i++)
            printf("  %s\n", oldDirectory[i].name);

        fclose(inputFile);
        return 0;
    }

    uint32_t numKeepEntries = uint32_t(argc - optind - 1);
    pakfile_t *newDirectory = new pakfile_t[numKeepEntries]();
    FILE *outputFile = fopen(outputFilename, "wb");
    if (outputFile == NULL)
    {
        perror("Couldn't write output file");
        fclose(inputFile);
        delete [] oldDirectory;
        return 1;
    }

    // Write new header
    pakheader_t newHeader;
    memcpy(newHeader.id, "PACK", 4);
    newHeader.dirOffset = sizeof(pakheader_t);
    newHeader.dirSize = sizeof(pakfile_t) * numKeepEntries;
    if (fwrite(&newHeader, sizeof(pakheader_t), 1, outputFile) != 1)
    {
        perror("fwrite failed");
        fclose(inputFile);
        fclose(outputFile);
        delete [] oldDirectory;
        return 1;
    }

    uint32_t newDataOffset = numKeepEntries * sizeof(pakfile_t)
        + sizeof(pakheader_t);
    for (uint32_t newDirIndex = 0; newDirIndex < numKeepEntries;
        newDirIndex++)
    {
        const char *filename = argv[int(newDirIndex) + optind + 1];
        strcpy(newDirectory[newDirIndex].name, filename);
        newDirectory[newDirIndex].offset = newDataOffset;

        // Search the old directory to find this file
        bool foundOldEntry = false;
        for (int i = 0; i < numOldDirEntries; i++)
        {
            if (strcmp(oldDirectory[i].name, filename) == 0)
            {
                // Copy file contents from old to new file
                newDirectory[newDirIndex].size = oldDirectory[i].size;
                void *tmp = malloc(oldDirectory[i].size);

                if (fseek(inputFile, oldDirectory[i].offset, SEEK_SET))
                {
                    perror("error seeking old file");
                    fclose(inputFile);
                    fclose(outputFile);
                    delete [] oldDirectory;
                    return 1;
                }

                if (fread(tmp, oldDirectory[i].size, 1, inputFile) != 1)
                {
                    perror("error reading old file");
                    fclose(inputFile);
                    fclose(outputFile);
                    delete [] oldDirectory;
                    return 1;
                }

                if (fseek(outputFile, newDataOffset, SEEK_SET))
                {
                    perror("error seeking new file");
                    fclose(inputFile);
                    fclose(outputFile);
                    delete [] oldDirectory;
                    return 1;
                }

                if (fwrite(tmp, oldDirectory[i].size, 1, outputFile) != 1)
                {
                    perror("error writing new file");
                    fclose(inputFile);
                    fclose(outputFile);
                    delete [] oldDirectory;
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
            printf("Couldn't find %s in original file\n", filename);
            fclose(inputFile);
            fclose(outputFile);
            delete [] oldDirectory;
            return 1;
        }
    }

    // Write directory to new file
    if (fseek(outputFile, sizeof(pakheader_t), SEEK_SET))
    {
        perror("error seeking in output file");
        fclose(inputFile);
        fclose(outputFile);
        delete [] oldDirectory;
        return 1;
    }

    if (fwrite(newDirectory, sizeof(pakfile_t), numKeepEntries, outputFile)
        != numKeepEntries)
    {
        perror("failed to write directory");
        fclose(inputFile);
        fclose(outputFile);
        delete [] oldDirectory;
        return 1;
    }

    fclose(inputFile);
    fclose(outputFile);
    delete [] oldDirectory;

    return 0;
}
